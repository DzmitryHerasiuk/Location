//
//  Notification.swift
//  Mockup
//
//  Created by Dzmitry Herasiuk on 22.01.21.
//

import Foundation
import UserNotifications

class NotificationService {
    
    private let userNotificationCenter = UNUserNotificationCenter.current()
    private var isAllow = false
    init() {
        requestNotificationAuthorization()
    }
    
    func requestNotificationAuthorization() {
        let authOptions = UNAuthorizationOptions.init(arrayLiteral: .alert, .badge, .sound)
        userNotificationCenter.requestAuthorization(options: authOptions) { [weak self] (success, error) in
            if let error = error {
                self?.isAllow = false
                print("Error: ", error)
                return
            }
            self?.isAllow = true
        }
    }
    
    func sendNotification(title: String, subtitle: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "testNotification", content: content, trigger: trigger)
        userNotificationCenter.add(request) { error in
            if let error = error {
                print("Error: ", error)
            }
        }
    }
}
