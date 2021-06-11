//
//  LocationManagerErrors.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 25.01.21.
//

import Foundation
import CoreLocation

/// These errors don't stop the LocationManager from working. It tries to perform its functions when the error is eliminated.
enum LocationTrackingError: LocalizedError {
    case denied
    case restricted
    case notDetermined
    case reducedAccuracy
    case locationUnknown
    case other(Error)
}

extension LocationTrackingError {
    
    var localizedDescription: String {
        switch self {
        case .denied:
            return "Availability of GPS was denied"
        case .restricted:
            return "Availability of GPS was restricted"
        case .notDetermined:
            return "Have no permission to track GPS coordinates"
        case .reducedAccuracy:
            return "Permissions are available for reduced accuracy only"
        case .locationUnknown:
            return "Poor GPS signal. The location is not detected"
        case .other(let error):
            return error.localizedDescription
        }
    }
    
    var errorDescription: String? {
        return localizedDescription
    }
}

enum RegionError: LocalizedError {
    case notAvailable(CLCircularRegion)
    case other(Error)
}
