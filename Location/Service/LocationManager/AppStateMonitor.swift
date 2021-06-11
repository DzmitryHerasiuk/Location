//
//  AppStateMonitor.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 22.01.21.
//

import Foundation
import UIKit
import Combine

class AppStateMonitor: CanLog {
    enum AppState {
        case didFinishLaunching
        case appDidBecomeActive
        case appWillResignActive
        case appDidEnterBackground
        case appWillTerminate
        case appWillEnterForeground
    }
    private let notificationService = NotificationService()
    private let flow = "[-=APPLIFECYCLE]"
    
    private let _publisher = PassthroughSubject<AppState, Never>()
    var publisher: AnyPublisher<AppState, Never> {
        return _publisher.eraseToAnyPublisher()
    }
    
    var appState: App_.State {
        return App_.state
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidFinishLaunchingNotification(_:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActiveNotification(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActiveNotification(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackgroundNotification(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminateNotification(_:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForegroundNotification(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func appDidFinishLaunchingNotification(_ notification: Notification) {
        log(#function)
        log(notification.description)
        log(notification.userInfo?.description ?? "")
        sendNotification(title: "AppStates", subtitle: "appDidFinishLaunching")
    }
    
    
    @objc func appDidBecomeActiveNotification(_ notification: Notification) {
        _publisher.send(.appDidBecomeActive)
        log(#function)
    }
    
    @objc func appWillResignActiveNotification(_ notification: Notification) {
        _publisher.send(.appWillResignActive)
        log(#function)
    }
    
    @objc func appDidEnterBackgroundNotification(_ notification: Notification) {
        _publisher.send(.appDidEnterBackground)
        log(#function)
        sendNotification(title: "AppStates", subtitle: "DidEnterBackground")
    }
    
    @objc func appWillTerminateNotification(_ notification: Notification) {
        _publisher.send(.appWillTerminate)
        log(#function)
        sendNotification(title: "AppStates", subtitle: "appWillTerminate")
    }
    
    @objc func appWillEnterForegroundNotification(_ notification: Notification) {
        _publisher.send(.appWillEnterForeground)
        log(#function)
        sendNotification(title: "AppStates", subtitle: "appWillEnterForeground")
    }
}

private extension AppStateMonitor {
    
    func sendNotification(title: String, subtitle: String) {
//        notificationService.sendNotification(title: title, subtitle: subtitle)
    }
}
