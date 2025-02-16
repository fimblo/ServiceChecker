import Foundation

/// Represents the status of a single service being monitored
struct ServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    var status: Bool
    var lastError: String = ""  // Added to store error messages
    var mode: String = "enabled"
}

/// Represents a service configuration that can be saved to disk
struct ServiceConfig: Codable {
    let name: String
    let url: String
} 