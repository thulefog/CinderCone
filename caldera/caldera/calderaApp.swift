//
//  calderaApp.swift
//  caldera
//
//  Created by John Matthew Weston on 6/9/25.
//

import SwiftUI

@main
struct calderaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if targetEnvironment(macCatalyst)
        .windowStyle(DefaultWindowStyle())
        #endif
    }
}
