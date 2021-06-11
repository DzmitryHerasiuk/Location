//
//  LocationManager.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 28.01.21.
//

import Combine
import CoreLocation

protocol CanGetRegionCrossingInformation {
    func getRegionPublisher() -> AnyPublisher<RegionCrossingResult, Never>
    func getStateIfPossible(for region: CLCircularRegion, callback: @escaping InputAction<CLRegionState>)
    func startMonitoringRegion(_ region: CLCircularRegion)
    func stopMonitoringRegion(_ region: CLCircularRegion)
}

protocol CanGetLocations {
    // how to get changing state and changing accuracy???
    func getLocationPublisher() -> AnyPublisher<LocationResult, Never>
    func startLocationTracking(configurator: LocationTrackingConfigurator)
    func stopLocationTracking()
}

enum LocationTrackingState {
    case stopped
    case waitingAuthorization
    case running
}

class LocationManager {
    private let authService: LocationAuthService = LocationAuthService()
    private lazy var trackingService = LocationTrackingService(authService: authService)
    private lazy var regionService = LocationRegionService(authService: authService)
}

extension LocationManager: CanGetLocations {
        
    func getLocationPublisher() -> AnyPublisher<LocationResult, Never> {
        trackingService.getLocationPublisher()
    }
    
    func startLocationTracking(configurator: LocationTrackingConfigurator = .default) {
        trackingService.configure(configurator)
        trackingService.startLocationTracking()
    }
    
    func stopLocationTracking() {
        trackingService.stopLocationTracking()
    }
}

extension LocationManager: CanGetRegionCrossingInformation {
    
    func getRegionPublisher() -> AnyPublisher<RegionCrossingResult, Never> {
        return regionService.getRegionPublisher()
    }
    
    /// You need to activate the background mode(target->capabilities->location updates) to use the regions functionality.
    func startMonitoringRegion(_ region: CLCircularRegion) {
        regionService.startMonitoringRegion(region)
    }
    
    func stopMonitoringRegion(_ region: CLCircularRegion) {
        regionService.stopMonitoringRegion(region)
    }
    
    /// If the state of the region will be unknown, the callback will not be called.
    func getStateIfPossible(for region: CLCircularRegion, callback: @escaping InputAction<CLRegionState>) {
        regionService.getStateIfPossible(for: region, callback: callback)
    }
}
