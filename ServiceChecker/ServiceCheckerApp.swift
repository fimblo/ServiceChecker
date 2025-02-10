//
//  ServiceCheckerApp.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//

import SwiftUI
import AppKit

@main
struct ServiceCheckerApp: App {
    let statusBar = StatusBarController()

    var body: some Scene {
        WindowGroup {
            ContentView()
              .onAppear { // Set activation policy here
                    NSApp.setActivationPolicy(.accessory)
                    // If your app terminates immediately after this, uncomment the next line:
                    //DispatchQueue.main.asyncAfter(deadline:.now() + 0.1) { RunLoop.main.run() }
                }
        }
    }
}
