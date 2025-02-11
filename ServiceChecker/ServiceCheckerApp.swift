//
//  ServiceCheckerApp.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//

import SwiftUI
import AppKit

/// Main application entry point
@main
struct ServiceCheckerApp: App {
    @StateObject private var statusBar = StatusBarController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
    }
}
