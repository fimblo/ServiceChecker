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
    var mode: String
    
    // Add custom init with default value
    init(name: String, url: String, mode: String = "enabled") {
        self.name = name
        self.url = url
        self.mode = mode
    }
    
    // Add custom decoding init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        // Try to decode mode, default to "enabled" if not present
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "enabled"
    }
} 