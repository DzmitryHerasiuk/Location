//
//  LocationAuthService.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 27.01.21.
//

import CoreLocation

protocol LocationAuthObserverProtocol: AnyObject, CanLocationFlowLog {
    func didChangeAuthorizationStatus(_ status: LocationAuthorizationResult)
    func didChangeAuthorizationAccuracy(_ authorizationAccuracy:  AuthorizationAccuracy)
}

final class LocationAuthService: NSObject, CanLocationFlowLog {
    private let manager = CLLocationManager()
    private var observers = [ObjectIdentifier: LocationAuthObserver]()
    
    private (set) var authStatus: CLAuthorizationStatus
    private (set) var authAccuracy: AuthorizationAccuracy
    override init() {
        self.authStatus = manager.authStatusIndependentOfiOSVersion
        self.authAccuracy = manager.authAccuracyIndependentOfiOSVersion
        super.init()
        self.manager.delegate = self
    }
}

extension LocationAuthService {
    
    func addAuthParameters(_ observer: LocationAuthObserverProtocol,
                           authStatus: SuccessLocationAuthStatus,
                           accuracy: AuthorizationAccuracy) {
        let authObserver = LocationAuthObserver(observer: observer,
                                                authStatus: authStatus,
                                                accuracy: accuracy)
        observers[authObserver.id] = authObserver
        authObserver.weakObserver.didChangeAuthorizationStatus(self.authStatus.toAuthResult())
        authObserver.weakObserver.didChangeAuthorizationAccuracy(authAccuracy)
    }
    
    func removeAuthParameters(for object: LocationAuthObserverProtocol) {
        observers.removeValue(forKey: object.id)
    }
    
    func authorize() {
        authorizeIfNeeded()
    }
    
    func authorizeFullAuthAccuracy() {
        authorizeFullAuthAccuracyIfNeeded()
    }
}

private extension LocationAuthService {
        
    func authorizeIfNeeded() {
        guard
            let requiredAuthStatus = getRequiredAuthStatus(),
            !isUsingAuthStatus(requiredAuthStatus)
        else {
            return
        }
        switch requiredAuthStatus {
        case .always:
            log("ask requestAlwaysAuthorization")
            manager.requestAlwaysAuthorization()
        case .whenInUse:
            log("ask requestWhenInUseAuthorization")
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func getRequiredAuthStatus() -> SuccessLocationAuthStatus? {
        let authStatuses = observers.values.map { $0.authParameter.authStatus }
        if authStatuses.isEmpty {
            return nil
        }
        if authStatuses.contains(.always) {
            return .always
        }
        if authStatuses.contains(.whenInUse) {
            return .whenInUse
        }
        preconditionFailure()
    }
    
    func isUsingAuthStatus(_ status: SuccessLocationAuthStatus) -> Bool {
        switch (authStatus, status) {
        case (.authorizedAlways, .always),
             (.authorizedWhenInUse, .whenInUse):
            return true
        default:
            return false
        }
    }
    
    func getRequiredAccuracy() -> AuthorizationAccuracy? {
        let authAccuracy = observers.values.map { $0.authParameter.authAccuracy }
        if authAccuracy.isEmpty {
            return nil
        }
        if authAccuracy.contains(.fullAccuracy) {
            return .fullAccuracy
        }
        if authAccuracy.contains(.reducedAccuracy) {
            return .reducedAccuracy
        }
        preconditionFailure()
    }
    
    func authorizeFullAuthAccuracyIfNeeded() {
        guard
            #available(iOS 14.0, *),
            let requiredAuthAccuracy = getRequiredAccuracy(),
            authAccuracy != requiredAuthAccuracy,
            authAccuracy != .fullAccuracy
        else {
            return
        }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "AccuracyPListKeyDescription")
    }
}

extension LocationAuthService: CLLocationManagerDelegate {
    
    // depricated since iOS 14.0
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        log("Authorization status changed: \(status.rawValue) - \(String.init(describing: status))")
        didChangeAuthizationParameter()
    }
    
    // available since iOS 14.0
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        didChangeAuthizationParameter()
    }
    
    private func didChangeAuthizationParameter() {
        let changedAuthAccuracy = manager.authAccuracyIndependentOfiOSVersion
        if authAccuracy != changedAuthAccuracy {
            authAccuracy = changedAuthAccuracy
            log("Authorization accuracy changed: \(authAccuracy) - \(String.init(describing: authAccuracy))")
            notifyObserversOfAuthAccuracyChanges()
            return
        }
        let changedAuthStatus = manager.authStatusIndependentOfiOSVersion
        if authStatus != changedAuthStatus {
            authStatus = changedAuthStatus
            log("Authorization status changed: \(authStatus.rawValue) - \(String.init(describing: authStatus))")
            notifyObserversOfAuthStatusChanges()
            return
        }
//        preconditionFailure()
        return
    }
            
    private func notifyObserversOfAuthStatusChanges() {
        let authResult = authStatus.toAuthResult()
        self.observers.forEach { $0.value.weakObserver.didChangeAuthorizationStatus(authResult)}
    }
    
    private func notifyObserversOfAuthAccuracyChanges() {
        self.observers.forEach { $0.value.weakObserver.didChangeAuthorizationAccuracy(authAccuracy)}
    }
}

// MARK: - Helpers

private extension CLLocationManager {
    
    var authStatusIndependentOfiOSVersion: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return self.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }
    
    var authAccuracyIndependentOfiOSVersion: AuthorizationAccuracy {
        if #available(iOS 14.0, *) {
            return .init(authAccuracy: self.accuracyAuthorization)
        }
        return .fullAccuracy
    }
}

enum SuccessLocationAuthStatus {
    case whenInUse
    case always
}

enum LocationAuthorizationResult {
    case success(SuccessLocationAuthStatus)
    case failure
}

private extension CLAuthorizationStatus {
    
    func toAuthResult() -> LocationAuthorizationResult {
        switch self {
        case .authorizedWhenInUse:
            return .success(.whenInUse)
        case .authorizedAlways:
            return .success(.always)
        case .notDetermined:
            return .failure
        case .denied, .restricted:
            return .failure
        @unknown default:
            assertionFailure("Exist unprocessed case")
            return.failure
        }
    }
}

struct WeakObject<T: AnyObject> {
    private unowned var _object: T
    var object: T {
        return _object
    }
    init(_ object: T) {
        self._object = object
    }
}

private extension LocationAuthObserverProtocol {
    
    var id: ObjectIdentifier {
        return ObjectIdentifier(self)
    }
}

private struct LocationAuthObserver {
    let id: ObjectIdentifier
    let authParameter: AuthParameter
    private let weakObject: WeakObject<AnyObject>
    
    var weakObserver: LocationAuthObserverProtocol {
        guard let observer = weakObject.object as? LocationAuthObserverProtocol else { fatalError() }
        return observer
    }
}

private extension LocationAuthObserver {
    
    init(observer: LocationAuthObserverProtocol,
         authStatus: SuccessLocationAuthStatus,
         accuracy: AuthorizationAccuracy) {
        let authParameter = AuthParameter(authStatus: authStatus, authAccuracy: accuracy)
        self.init(id: observer.id,
                  authParameter: authParameter,
                  weakObject: WeakObject(observer))
    }
}

private struct AuthParameter {
    let authStatus: SuccessLocationAuthStatus
    let authAccuracy: AuthorizationAccuracy
}

enum AuthorizationAccuracy {
    case fullAccuracy
    case reducedAccuracy
}

private extension AuthorizationAccuracy {
    
    init(authAccuracy: CLAccuracyAuthorization) {
        switch authAccuracy {
        case .fullAccuracy:
            self = .fullAccuracy
        case .reducedAccuracy:
            self = .reducedAccuracy
        @unknown default:
            preconditionFailure()
            self = .fullAccuracy
        }
    }
}
