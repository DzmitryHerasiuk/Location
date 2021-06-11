//
//  LocationView.swift
//  Mockup
//
//  Created by User on 14.01.21.
//

import SwiftUI

struct LocationView: View {
    @ObservedObject var viewModel: LocationViewModel
    
    var body: some View {
        VStack(
            alignment: .center,
            spacing: 10
        ) {
            Spacer()

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("locations count: ")
                    Text("\(viewModel.locationCount)")
                }
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("last updating time: ")
                    Text(viewModel.lastUpdatingTime)
                }
                
                Spacer()

                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("location: ")
                    Text(viewModel.location)
                }
                
                Spacer()
                
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("latitude: ")
                    Text(viewModel.latitude)
                }
                
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("longitude: ")
                    Text(viewModel.longitude)
                }
                
                Spacer()
                
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Text("Manager status: ")
                    Text(viewModel.workStatus)
                }
                
                Text("error: " + "\(viewModel.error)" + (viewModel.error?.localizedDescription ?? ""))
            }

            Spacer()

            Button("Start location") {
                viewModel.startLocating()
            }

            Button("Stop location") {
                viewModel.stopLocating()
            }
            
            Spacer()
        }
    }
}

struct LocationView_Previews: PreviewProvider, HasMockNavigationStack {
    static var previews: some View {
        LocationView(viewModel: LocationViewModel(navigationStack: mockNavigationStack))
    }
}

// TODO: move
protocol HasMockNavigationStack { }
extension HasMockNavigationStack {
    
    static var mockNavigationStack: NavigationStack {
        return .init(easing: .default)
    }
}
