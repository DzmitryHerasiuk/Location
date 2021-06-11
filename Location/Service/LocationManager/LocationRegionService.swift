//
//  LocationRegionService.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 28.01.21.
//

import Foundation
import Combine
import CoreLocation

class LocationRegionService: NSObject, CanLocationFlowLog {
    private let manager = CLLocationManager()
    private var regionStateCallback: InputAction<CLRegionState>?
    private let regionPublisher = PassthroughSubject<RegionCrossingResult, Never>()
    private let authService: LocationAuthService
    init(authService: LocationAuthService) {
        self.authService = authService
        super.init()
        manager.delegate = self
    }
}

extension LocationRegionService {
    
    func getRegionPublisher() -> AnyPublisher<RegionCrossingResult, Never> {
        return regionPublisher.eraseToAnyPublisher()
    }
    
    /// You need to activate the background mode(target->capabilities->location updates) to use the regions functionality.
    func startMonitoringRegion(_ region: CLCircularRegion) {
        guard CLLocationManager.isMonitoringAvailable(for: type(of: region)) else {
            assertionFailure()
            sendRegionResult(.failure(.notAvailable(region)))
            return
        }
        manager.startMonitoring(for: region) // TODO:
    }
    
    func stopMonitoringRegion(_ region: CLCircularRegion) {
        manager.stopMonitoring(for: region)
    }
    
    func stopAllRegions() {
        manager.monitoredRegions.forEach { region in
            manager.stopMonitoring(for: region)
        }
    }
    
    /// If the state of the region will be unknown, the callback will not be called.
    func getStateIfPossible(for region: CLCircularRegion, callback: @escaping InputAction<CLRegionState>) {
        regionStateCallback = callback
        manager.requestState(for: region)
    }
}

private extension LocationRegionService {
    
    func prepareRegionInformation(_ region: CLRegion) -> (region: CLCircularRegion, location: CLLocation?)? {
        guard let circularRegion = region as? CLCircularRegion else {
            return nil
        }
        let location = manager.location
        return (circularRegion, location: location)
    }
    
    func sendRegionResult(_ result: RegionCrossingResult) {
        regionPublisher.send(result)
    }
}

extension LocationRegionService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let information = prepareRegionInformation(region) {
            sendRegionResult(.success(.didExit(information.region, lastLocation: information.location)))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let information = prepareRegionInformation(region) {
            sendRegionResult(.success(.didEnter(information.region, lastLocation: information.location)))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if let callback = regionStateCallback {
            callback(state)
            regionStateCallback = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        sendRegionResult(.failure(.other(error)))
    }
}

enum RegionCrossingResult {
    case success(RegionCrossing)
    case failure(RegionError)
}

enum RegionCrossing {
    case didEnter(_ region: CLCircularRegion, lastLocation: CLLocation?)
    case didExit(_ region: CLCircularRegion, lastLocation: CLLocation?)
}
