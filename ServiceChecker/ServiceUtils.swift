import Foundation

// Add this new struct at the top level
struct AppConfig {
    /// The default update interval in seconds
    static let DEFAULT_UPDATE_INTERVAL: TimeInterval = 5.0
    /// The default network timeout in seconds
    static let NETWORK_TIMEOUT_SECONDS: TimeInterval = 5

    var services: [ServiceConfig]
    var updateIntervalSeconds: TimeInterval
    
    static var shared: AppConfig?
}

// New JSON structure
struct ConfigFile: Codable {
    var services: [ServiceConfig]
    var updateIntervalSeconds: TimeInterval
    
    init(services: [ServiceConfig], updateIntervalSeconds: TimeInterval) {
        self.services = services
        self.updateIntervalSeconds = updateIntervalSeconds
    }
    
    enum CodingKeys: String, CodingKey {
        case services
        case updateIntervalSeconds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode([ServiceConfig].self, forKey: .services)
        updateIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .updateIntervalSeconds) ?? AppConfig.DEFAULT_UPDATE_INTERVAL
    }
}

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
        config.timeoutIntervalForRequest = AppConfig.NETWORK_TIMEOUT_SECONDS
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
    
    /// Loads service configurations from file into global config
    static func loadConfiguration() {
        guard let configPath = getConfigPath() else {
            print("Could not determine config path")
            AppConfig.shared = AppConfig(services: getDefaultServices().map { 
                ServiceConfig(name: $0.name, url: $0.url)
            }, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
            return
        }
        
        do {
            let configDir = configPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: configDir,
                                                 withIntermediateDirectories: true)
            
            // Create/overwrite README.txt
            let readmePath = configDir.appendingPathComponent("README.txt")
            let readmeContent = """
            This is the ServiceChecker configuration directory.
            
            The config.json file contains the configuration for ServiceChecker.
            The 'services' section contains the list of services to monitor.
            Each service should have a name and a health check URL.

            The format is:
            {
                "services": [
                    {
                        "name": "Service Name",
                        "url": "http://localhost:8080/path/to/health/check"
                    }
                ],
                "updateIntervalSeconds": 5
            }

            The service is considered up if the health check URL returns a 200
            status code.

            The updateIntervalSeconds specifies how often (in seconds) to check the
            services.

            Important Note:
            This app is intended to be used for your own services. It isn't
            considered polite to use it on other people's systems without permission.

            """
            // I'll tell you a story about this if you're interested. :) /fimblo


            try readmeContent.write(to: readmePath, atomically: true, encoding: .utf8)
            
            // Create default config if file doesn't exist
            if !FileManager.default.fileExists(atPath: configPath.path) {
                print("Config file doesn't exist, creating with defaults")
                let defaultServices = getDefaultServices()
                let configs = defaultServices.map { ServiceConfig(name: $0.name, url: $0.url) }
                let configFile = ConfigFile(services: configs, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                let data = try encoder.encode(configFile)
                try data.write(to: configPath)
                print("Created config file at: \(configPath.path)")
                AppConfig.shared = AppConfig(services: configs, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
                return
            }
            
            print("Reading existing config file")
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            let configFile = try decoder.decode(ConfigFile.self, from: data)
            AppConfig.shared = AppConfig(services: configFile.services, 
                                       updateIntervalSeconds: configFile.updateIntervalSeconds)
            
        } catch {
            print("Error loading configuration: \(error)")
            AppConfig.shared = AppConfig(services: getDefaultServices().map { 
                ServiceConfig(name: $0.name, url: $0.url)
            }, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
        }
    }

    
    private static func getConfigPath() -> URL? {
        guard let configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return configDir.appendingPathComponent("ServiceChecker/config.json")
    }
    
    private static func getDefaultServices() -> [ServiceStatus] {
        return [
            ServiceStatus(name: "Local Server", url: "http://localhost:8080", status: false)
        ]
    }

    /// Saves the current configuration back to file
    static func saveConfiguration() {
        guard let configPath = getConfigPath(),
              let config = AppConfig.shared else {
            print("Could not save configuration: missing path or config")
            return
        }
        
        do {
            let configFile = ConfigFile(services: config.services, 
                                      updateIntervalSeconds: config.updateIntervalSeconds)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(configFile)
            try data.write(to: configPath)
            print("Saved configuration to: \(configPath.path)")
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}
