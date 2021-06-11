//
//  LocationTrackingService.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 27.01.21.
//

import CoreLocation
import Combine
import Foundation
import UIKit

final class LocationTrackingService: NSObject, CanLocationFlowLog {
    private let locationPublisher = PassthroughSubject<LocationResult, Never>()
    private let manager = CLLocationManager()
    private var serviceState: TrackingState = .stopped
    private let appStateMonitor = AppStateMonitor()
    private var disposables = Set<AnyCancellable>()
    private var trackingConfigurator: LocationTrackingConfigurator
    
    private let authService: LocationAuthService
    
    init(authService: LocationAuthService) {
        self.trackingConfigurator = .default
        self.authService = authService
        super.init()
        
        manager.delegate = self
        configureLocationServiceDependingOnAppState()
    }
}

// MARK: - Public

extension LocationTrackingService {
    
    func getLocationPublisher() -> AnyPublisher<LocationResult, Never> {
        return locationPublisher.eraseToAnyPublisher()
    }
    
    /// If you don't call this method, the manager will use the default location tracking configuration
    func configure(_ configurator: LocationTrackingConfigurator = .default) {
        trackingConfigurator = configurator
    }
    
    func startLocationTracking() {
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        log("WhenInUse request")
        manager.requestWhenInUseAuthorization()
        startMonitoringAppState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.log("ALWAYES request")
            self.manager.requestAlwaysAuthorization()
        }
//        if serviceState == .stopped {
//            serviceState = .waitingAuthorization
//            startMonitoringAppState()
//            subscribeForAuthorization()
//        }
    }
    
    func stopLocationTracking() {
        switch serviceState {
        case .waitingAuthorization, .running:
            serviceState = .stopped
            stopMonitoringAppState()
            unsubscribeFromAuthorization()
            stopTracking()
        case .stopped:
            break
        }
    }
}

// MARK: - Monitoring AppState

private extension LocationTrackingService {
    
    func subscribeForAuthorization() {
        let authStatus = trackingConfigurator.requiredAuthStatus
        let authAccuracy = trackingConfigurator.requiredAuthAccuracy
        authService.addAuthParameters(self, authStatus: authStatus, accuracy: authAccuracy)
        authService.authorize()
    }
    
    func unsubscribeFromAuthorization() {
        authService.removeAuthParameters(for: self)
    }
    
    func startMonitoringAppState() {
        appStateMonitor.publisher.sink { [weak self] appState in
//            self?.appStateDidChange(appState)
            self?.appStateDidChangeTest(appState)
        }
        .store(in: &disposables)
    }
    
    func stopMonitoringAppState() {
        disposables.removeAll()
    }
    
    func appStateDidChangeTest(_ appState: AppStateMonitor.AppState) {
        log("App State changed: \(appState)")
        switch appState {
        case .appWillEnterForeground:
            break
        case .appWillResignActive:
//        case .appDidEnterBackground:
            break
            log("ALWAYES request")
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }
    
    func appStateDidChange(_ appState: AppStateMonitor.AppState) {
        guard self.serviceState == .running else {
            return
        }
        switch appState {
        case .appWillEnterForeground:
            self.configureLocationServiceDependingOnAppState(.foreground)
            self.stopTracking(.background)
            self.startTracking(.foreground)
        case .appDidEnterBackground:
            self.configureLocationServiceDependingOnAppState(.background)
            self.stopTracking(.foreground)
            self.startTracking(.background)
        default:
            break
        }
    }
}

// MARK: - Location monitoring control

private extension LocationTrackingService {
    
    func startTracking(_ appState: App_.State = App_.state) {
        configureLocationServiceDependingOnAppState(appState)
        switch appState {
        case .foreground:
            log("Start SIGNIFICANT monitoring")
            manager.startMonitoringSignificantLocationChanges()

//            log("Start NORMAL monitoring")
//            manager.startUpdatingLocation()
        case .background:
            log("Start SIGNIFICANT monitoring")
            manager.startMonitoringSignificantLocationChanges()
//            currentAuthorizationType == .always
//                ? manager.startMonitoringSignificantLocationChanges()
//                : manager.startUpdatingLocation()
        }
    }
    
    func stopTracking(_ appState: App_.State = App_.state) {
        switch appState {
        case .foreground:
            manager.stopUpdatingLocation()
        case .background:
            manager.stopUpdatingLocation()
            manager.stopMonitoringSignificantLocationChanges()
        }
    }
}

// MARK: - Configure

private extension LocationTrackingService {
    
    func configureLocationServiceDependingOnAppState(_ appState: App_.State = App_.state) {
        switch appState {
        case .foreground:
            configureLocationForegroundMode()
        case .background:
            configureLocationBackgroundMode()
        }
    }
    
    func configureLocationForegroundMode() {
        manager.allowsBackgroundLocationUpdates = false
        guard let configuration = trackingConfigurator.foregroundOption.configuration else {
            return
        }
        configure(using: configuration)
    }
    
    func configureLocationBackgroundMode() {
        let options = trackingConfigurator.backgroundOption
        switch options {
        case .significant, .significantOrDefault:
            guard manager.hasLocationBackgroundCapabilities else {
                fatalError()
            }
            manager.allowsBackgroundLocationUpdates = true
        default:
            manager.allowsBackgroundLocationUpdates = false
        }
        if let configuration = options.configuration {
            configure(using: configuration)
        }
    }
    
    func configure(using configuration: LocationTrackingConfigurator.TrackingConfiguration) {
        manager.desiredAccuracy = configuration.accuracy.transformToCLLocationAccuracy()
        manager.distanceFilter = configuration.distanceFilter.transformToCLLocationDistance()
        let pauseSettings = configuration.pause.transformToPauseSettings()
        manager.pausesLocationUpdatesAutomatically = pauseSettings.hasPause
        manager.activityType = pauseSettings.activityType ?? .other
    }
    
    func sendLocation(_ result: LocationResult) {
        if case .failure(let error) = result {
            log("send error - \(error)")
        }
        locationPublisher.send(result)
    }
}

// MARK: - Significant
// location changes ~500m

private extension LocationTrackingService {
        
    /// Need "Always" permissions for "not in use" app state; works with reduced accuracy
    func startMonitoringSignificantLocationChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            return
        }
        log(#function)
        manager.startMonitoringSignificantLocationChanges()
    }
    
    func stopMonitoringSignificantLocationChanges() {
        log(#function)
        manager.stopMonitoringSignificantLocationChanges()
    }
}

// MARK: - LocationAuthObserver

extension LocationTrackingService: LocationAuthObserverProtocol {
        
    func didChangeAuthorizationStatus(_ status: LocationAuthorizationResult) {
        switch status {
        case .success:
            if serviceState == .waitingAuthorization {
                serviceState = .running
                startTracking()
            }
        case .failure:
            if serviceState == .running {
                serviceState = .waitingAuthorization
                stopTracking()
            }
            if let error = authService.authStatus.toLocationTrackingError() {
                sendLocation(.failure(error))
            }
        }
    }
    
    func didChangeAuthorizationAccuracy(_ authorizationAccuracy: AuthorizationAccuracy) {
        guard
            serviceState == .running,
            trackingConfigurator.requiredAuthAccuracy != authorizationAccuracy,
            authorizationAccuracy == .reducedAccuracy
        else {
            return
        }
        sendLocation(.failure(.reducedAccuracy))
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard #available(iOS 14.0, *) else {
            return
        }
        log("changed authorization status: \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
//            log("Start SIGNIFICANT monitoring")
//            manager.startMonitoringSignificantLocationChanges()
            log("Start NORMAL monitoring")
            manager.startUpdatingLocation()

        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else { return }
        log("Location updated: \(lastLocation.timestamp)")
        sendLocation(.success(lastLocation))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("error: \(error)")
        guard
            serviceState == .running,
            let clError = error as? CLError
        else {
            return
        }
        switch clError.code {
        case .denied:
            break // this case is handled in the "didChangeAuthorization" method
        case .locationUnknown:
            sendLocation(.failure(.locationUnknown))
        default:
            sendLocation(.failure(.other(error)))
        }
    }
}

// MARK: - Helpers

enum LocationResult {
    case success(CLLocation)
    case failure(LocationTrackingError)
}

private extension LocationTrackingService {
    
    enum TrackingState {
        case stopped
        case waitingAuthorization
        case running
    }
}

private extension LocationAccuracy {
    
    func transformToCLLocationAccuracy() -> CLLocationAccuracy {
        switch self {
        case .bestForNavigation:
            return kCLLocationAccuracyBestForNavigation
        case .best:
            return kCLLocationAccuracyBest
        case .tenMeters:
            return kCLLocationAccuracyNearestTenMeters
        case .hundredMeters:
            return kCLLocationAccuracyHundredMeters
        case .kilometer:
            return kCLLocationAccuracyKilometer
        case .threeKilometers:
            return kCLLocationAccuracyThreeKilometers
        case .tenKilometers:
            return 10*1000 // meter
            
        }
    }
    
    func isLessThanThreeKilometer() -> Bool {
        switch self {
        case .bestForNavigation, .best, .hundredMeters, .tenMeters, .kilometer:
            return true
        case .threeKilometers, .tenKilometers:
            return false
        }
    }
}

private extension DistanceFilter {
    
    func transformToCLLocationDistance() -> CLLocationDistance {
        switch self {
        case .on(let distance):
            return distance
        case .off:
            return kCLDistanceFilterNone
        }
    }
}

private extension LocationTrackingConfigurator.PauseMode {
    
    func transformToPauseSettings() -> (hasPause: Bool, activityType: CLActivityType?) {
        switch self {
        case .off:
            return (false, nil)
        case .on(let activityType):
            return (true, activityType)
            
        }
    }
}

private extension CLLocationManager {

    var hasLocationBackgroundCapabilities: Bool {
        let capabilities = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return capabilities?.contains("location") ?? false
    }
}

enum App_ {
    enum State {
        case foreground
        case background
    }
    static var state: State {
        switch UIApplication.shared.applicationState {
        case .active, .inactive:
            return .foreground
        case .background:
            return .background
        @unknown default:
            assertionFailure()
            return .foreground
        }
    }
}

private extension LocationTrackingConfigurator {
 
    var requiredAuthStatus: SuccessLocationAuthStatus {
        switch backgroundOption {
        case .no, .default, .custom:
            return .whenInUse
        case .significant, .significantOrDefault:
            return .always
        }
    }
    
    var requiredAuthAccuracy: AuthorizationAccuracy {
        let accuracy = foregroundOption.configuration?.accuracy
        switch accuracy {
        case .none:
            return .reducedAccuracy
        default:
            return .fullAccuracy
        }
    }
}

private extension CLAuthorizationStatus {
    
    func toLocationTrackingError() -> LocationTrackingError? {
        switch self {
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        default:
            return nil
        }
    }
}
