import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(systemSymbolName: "server.rack", accessibilityDescription: "ServiceChecker")!)
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("ServiceChecker")
                .font(.title)
            
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("A simple service monitoring tool for macOS")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Link("GitHub Repository", destination: URL(string: "https://github.com/fimblo/ServiceChecker")!)
                .padding(.top, 5)
            
            Text("Created by Mattias Jansson")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
            
            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .padding(.top)
        }
        .frame(width: 300, height: 300)
        .padding()
    }
}

class AboutWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "About ServiceChecker"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
    }
} 