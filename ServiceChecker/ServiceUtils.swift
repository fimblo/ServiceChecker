import Foundation

class ServiceUtils {
    /// Checks if a service endpoint is healthy
    /// - Parameter url: The health check URL
    /// - Returns: Tuple of (output string, status code) where 0 means success
    static func checkHealth(_ url: String) -> (String, Int) {
        // Convert localhost to 127.0.0.1 to force IPv4
        // Avoiding ipv6 for non-local connections is out of scope for now - there
        // will be errors in the console if the service is not reachable over ipv6.
        let ipv4Url = url.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        
        guard let serviceURL = URL(string: ipv4Url) else {
            return ("Invalid URL: \(url)", 1)
        }
        
        var result = (output: "", status: 1)
        let semaphore = DispatchSemaphore(value: 0)
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5 // seconds
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: serviceURL) { _, response, error in
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
        
        do {
            let configDir = configPath.deletingLastPathComponent()
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: configDir,
                                                 withIntermediateDirectories: true)
            
            // Create/overwrite README.txt
            let readmePath = configDir.appendingPathComponent("README.txt")
            let readmeContent = """
            This is the ServiceChecker configuration directory.
            
            The services.json file contains the list of services to monitor.
            Each service should have a name and a health check URL.

            The format is:
            [
                {
                    "name": "Service Name",
                    "url": 'http://localhost:8080/path/to/health/check'
                }
            ]

            The service is considered up if the health check URL returns a 200
            status code.

            """
            try readmeContent.write(to: readmePath, atomically: true, encoding: .utf8)
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
