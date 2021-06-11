//
//  LocationViewModel.swift
//  Mockup
//
//  Created by User on 14.01.21.
//

import Foundation
import CoreLocation
import Combine

class LocationViewModel: ObservableObject {
    private let navigationStack: NavigationStack
    private var cancellable: AnyCancellable?
    private lazy var locationManager: CanGetLocations = {
        let manager = LocationManager()
        cancellable = manager.getLocationPublisher().sink(receiveValue: processLocation)
        return manager
    }()
    
    @Published var locationCount: Int = 0
    @Published var lastUpdatingTime: String = ""
    @Published var workStatus: String = ""
    @Published var location: String = ""
    @Published var latitude: String = ""
    @Published var longitude: String = ""
    @Published var error: Error?
    
    init(navigationStack: NavigationStack) {
        self.navigationStack = navigationStack
    }
        
    func startLocating() {
        locationManager.startLocationTracking(configurator: .default)
        
        workStatus = LocationManagerActiveStatus.on.rawValue
    }
    
    func stopLocating() {
        locationManager.stopLocationTracking()
        cleanInfo()
        workStatus = LocationManagerActiveStatus.off.rawValue
    }
}

private extension LocationViewModel {
        
    func processLocation(_ result: LocationResult) {
        switch result {
        case .success(let location):
            locationCount += 1
            lastUpdatingTime = location.timestamp.description
            self.location = location.description
            latitude = location.coordinate.latitude.description
            longitude = location.coordinate.longitude.description
        case .failure(let error):
            self.error = error
        }
    }
    
    func cleanInfo() {
        locationCount.reset()
        lastUpdatingTime.reset()
        latitude.reset()
        longitude.reset()
        error = nil
    }
}

enum LocationManagerActiveStatus: String {
    case on = "On"
    case off = "Off"
}

private extension Int {
    
    mutating func reset() {
        self = 0
    }
}

private extension String {
    
    mutating func reset() {
        self = ""
    }
}
