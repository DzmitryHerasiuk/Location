//
//  Logger.swift
//  Mockup
//
//  Created by User on 13.01.21.
//

import Foundation

protocol CanLog {
    func log(_ message: String)
}

extension CanLog {
    
    func log(_ message: String) {
        Logger.default.log(message, from: self)
    }
}

protocol CanLocationFlowLog: CanLog { }

extension CanLocationFlowLog {
    
    func log(_ message: String) {
        Logger.locationFlow.log(message, from: self)
    }
}

private enum Logger {
    case locationFlow
    case appState
    case `default`
    
    private var currentTime: Date { Date() }
    
    func log<T>(_ message: String, from objectType: T) {
        switch self {
        case .locationFlow:
            guard Constant.isLogEnabled && LocationConstant.isLogEnabled else { return }
            print("\(currentTime): [-=LOCATION] - \(type(of: objectType)) - \(message)")
        case .appState:
            guard Constant.isLogEnabled && Constant.AppState.isLogEnabled else { return }
            print("\(currentTime): [-=APPSTATE] - \(type(of: objectType)) - \(message)")
        case .default:
            guard Constant.isLogEnabled && Constant.isDefaultLogEnabled else { return }
            print("\(currentTime): [-=DEFAULT] - \(type(of: objectType)) - \(message)")
        }
    }
}
