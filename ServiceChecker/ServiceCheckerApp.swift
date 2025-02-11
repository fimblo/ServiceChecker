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
    @StateObject private var statusBarController = StatusBarController()
    
    init() {
        // Set activation policy before any UI is created
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        Settings {
            ContentView()
        }
    }
}
