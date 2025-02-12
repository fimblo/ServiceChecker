import Foundation

class ServiceUtils {
    /// Checks if a service endpoint is healthy
    /// - Parameter url: The health check URL
    /// - Returns: Tuple of (output string, status code) where 0 means success
    static func checkHealth(_ url: String) -> (String, Int) {
        guard let serviceURL = URL(string: url) else {
            return ("Invalid URL", 1)
        }
        
        var result = (output: "", status: 1)
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: serviceURL) { _, response, error in
            defer { semaphore.signal() }
            
            if error != nil {
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                result = ("", 0)
            }
        }
        
        task.resume()
        semaphore.wait()
        
        return result
    }
    
    /// Loads service configurations from file
    static func loadServicesFromFile() -> [ServiceStatus] {
        guard let configPath = getConfigPath() else {
            print("Could not determine config path")
            return getDefaultServices()
        }
        
        print("Config path: \(configPath.path)")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
            print("Created/verified directory at: \(configPath.deletingLastPathComponent().path)")
            
            // If file doesn't exist, create it with default services
            if !FileManager.default.fileExists(atPath: configPath.path) {
                print("Config file doesn't exist, creating with defaults")
                let defaultServices = getDefaultServices()
                let configs = defaultServices.map { ServiceConfig(name: $0.name, url: $0.url) }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                let data = try encoder.encode(configs)
                try data.write(to: configPath)
                print("Created config file at: \(configPath.path)")
                return defaultServices
            }
            
            print("Reading existing config file")
            // Read and parse existing file
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            let configs = try decoder.decode([ServiceConfig].self, from: data)
            
            return configs.map { config in
                ServiceStatus(name: config.name, url: config.url, status: false)
            }
        } catch {
            print("Error loading services: \(error)")
            return getDefaultServices()
        }
    }
    
    private static func getConfigPath() -> URL? {
        guard let configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return configDir.appendingPathComponent("ServiceChecker/services.json")
    }
    
    private static func getDefaultServices() -> [ServiceStatus] {
        return [
            ServiceStatus(name: "Local Server", url: "http://localhost:8080", status: false)
        ]
    }
}
