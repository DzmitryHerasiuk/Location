//
//  LocationTrackingConfigurator.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 25.01.21.
//

import CoreLocation

struct LocationTrackingConfigurator {
    enum PauseMode {
        case on(CLActivityType) // TODO: add own type instead CLActivityType
        case off
    }
    enum ForegroundOption {
        case `default`
        case custom(TrackingConfiguration)
        case significant
    }
    enum BackgroundOption {
        case no
        /// App will use custom mode with low accuracy
        case `default`
        /// App continues to run in the background mode (app stays active.)
        case custom(TrackingConfiguration)
        /// App try to use significant changis(depends of user permissions), if no, the app will use custom mode(active) with low accuracy
        case significantOrDefault
        /// App can go into suspended mode; try to use significant changes
        case significant
    }
    struct TrackingConfiguration {
        let accuracy: LocationAccuracy
        let distanceFilter: DistanceFilter
        let pause: PauseMode
        
        fileprivate static let defaultForeground = TrackingConfiguration(accuracy: .best,
                                                                         distanceFilter: .off,
                                                                         pause: .off)
        fileprivate static let defaultBackground = TrackingConfiguration(accuracy: .threeKilometers,
                                                                         distanceFilter: .off,
                                                                         pause: .off)
    }
    
    let foregroundOption: ForegroundOption
    /// Need to activate background mode in the Xcode Capabilities
    let backgroundOption: BackgroundOption
    
    static let `default` = Self(foregroundOption: .default, backgroundOption: .significantOrDefault)
}

enum LocationAccuracy {
    case bestForNavigation
    case best
    case tenMeters
    case hundredMeters
    case kilometer
    case threeKilometers
    case tenKilometers
}

enum DistanceFilter {
    /// distance in meters
    case on(_ minDistance: Double)
    case off
}

extension LocationTrackingConfigurator.ForegroundOption {
    
    var configuration: LocationTrackingConfigurator.TrackingConfiguration? {
        switch self {
        case .default:
            return  .defaultForeground
        case .custom(let configuration):
            return configuration
        case .significant:
            return nil
        }
    }
}

extension LocationTrackingConfigurator.BackgroundOption {
    
    var configuration: LocationTrackingConfigurator.TrackingConfiguration? {
        switch self {
        case .no, .significant:
            return nil
        case .default, .significantOrDefault:
            return  .defaultBackground
        case .custom(let configuration):
            return configuration
        }
    }
}
