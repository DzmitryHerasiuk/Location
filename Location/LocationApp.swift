//
//  LocationApp.swift
//  Location
//
//  Created by Dzmitry Herasiuk on 11.06.21.
//

import SwiftUI

@main
struct LocationApp: App {
    let navigationStack = NavigationStack(easing: .default)

    var body: some Scene {
        WindowGroup {
            LocationView(viewModel: .init(navigationStack: navigationStack))
        }
    }
}
