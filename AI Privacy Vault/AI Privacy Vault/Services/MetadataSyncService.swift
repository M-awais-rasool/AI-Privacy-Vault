import Foundation
import Network

class MetadataSyncService {
    static let shared = MetadataSyncService()
    
    private var serverURL: URL?
    private var authToken: String?
    private var deviceID: String = {
        if let deviceUUID = UserDefaults.standard.string(forKey: "device_uuid") {
            return deviceUUID
        } else {
            let newUUID = UUID().uuidString
            UserDefaults.standard.set(newUUID, forKey: "device_uuid")
            return newUUID
        }
    }()
    
    private let serviceBrowser = NWBrowser(for: .bonjour(type: "_aiprivacyvault._tcp", domain: "local"), using: .tcp)
    private var discoveredServers: [NWBrowser.Result] = []
    private var isDiscovering = false
    
    private init() {
    }
    
    
    func connectToLocalServer(completion: @escaping (Bool) -> Void) {
        let possiblePorts = [8080, 3000, 5000]
        var portsToTry = possiblePorts
        
        func tryNextPort() {
            guard !portsToTry.isEmpty else {
                print("Failed to connect to any local port")
                completion(false)
                return
            }
            
            let port = portsToTry.removeFirst()
            let url = URL(string: "http://localhost:\(port)")
            self.serverURL = url
            print("Attempting direct connection to \(url?.absoluteString ?? "unknown")")
            
            var request = URLRequest(url: url!.appendingPathComponent("api/status"))
            request.httpMethod = "GET"
            request.timeoutInterval = 3
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, 
                   httpResponse.statusCode == 200 {
                    print("Successfully connected to local server on port \(port)")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    print("Failed to connect on port \(port), trying next...")
                    tryNextPort()
                }
            }.resume()
        }
        
        tryNextPort()
    }
    
    func connectToServer(_ server: ServerInfo, completion: @escaping (Bool) -> Void) {
        connectToLocalServer(completion: completion)
    }
    
    
    func checkServerStatus(completion: @escaping (Bool) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/status") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Server status error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200,
                  let data = data else {
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status == "online" {
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }.resume()
    }
    
    
    func register(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/auth/register") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        let credentials = AuthRequest(
            username: username,
            password: password,
            deviceID: deviceID
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(credentials)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(SyncError.invalidResponse))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(SyncError.noData))
                    return
                }
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        let authResponse = try decoder.decode(AuthResponse.self, from: data)
                        self.authToken = authResponse.token
                        completion(.success(authResponse))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    do {
                        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        completion(.failure(SyncError.serverError(errorResponse.error)))
                    } catch {
                        completion(.failure(SyncError.decodingError))
                    }
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func login(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/auth/login") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        let credentials = AuthRequest(
            username: username,
            password: password,
            deviceID: deviceID
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(credentials)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(SyncError.invalidResponse))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(SyncError.noData))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        let authResponse = try decoder.decode(AuthResponse.self, from: data)
                        self.authToken = authResponse.token
                        completion(.success(authResponse))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    do {
                        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        completion(.failure(SyncError.serverError(errorResponse.error)))
                    } catch {
                        completion(.failure(SyncError.decodingError))
                    }
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Metadata API
    
    func getAllMetadata(completion: @escaping (Result<[FileMetadata], Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/metadata") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SyncError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let metadata = try decoder.decode([FileMetadata].self, from: data)
                completion(.success(metadata))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getMetadata(id: String, completion: @escaping (Result<FileMetadata, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/metadata/\(id)") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SyncError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let metadata = try decoder.decode(FileMetadata.self, from: data)
                completion(.success(metadata))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func addMetadata(_ metadata: FileMetadata, completion: @escaping (Result<FileMetadata, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/metadata") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(metadata)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(SyncError.noData))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let updatedMetadata = try decoder.decode(FileMetadata.self, from: data)
                    completion(.success(updatedMetadata))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func updateMetadata(id: String, metadata: FileMetadata, completion: @escaping (Result<FileMetadata, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/metadata/\(id)") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(metadata)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(SyncError.noData))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let updatedMetadata = try decoder.decode(FileMetadata.self, from: data)
                    completion(.success(updatedMetadata))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func deleteMetadata(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/metadata/\(id)") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(SyncError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(SyncError.serverError("Failed to delete metadata")))
            }
        }.resume()
    }
    
    // MARK: - Metadata Sync
    
    func syncMetadata(files: [VaultFileMetadata], syncToken: String = "", completion: @escaping (Result<SyncResponse, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/sync") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        let syncRequest = SyncRequest(
            deviceID: deviceID,
            items: files.map { fileMetadata in
                FileMetadata(
                    id: fileMetadata.id.uuidString,
                    encryptedData: fileMetadata.encryptedMetadata,
                    userID: 0, 
                    version: fileMetadata.version,
                    lastModifiedAt: fileMetadata.lastModified,
                    isDeleted: fileMetadata.isDeleted
                )
            },
            syncToken: syncToken
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let requestData = try encoder.encode(syncRequest)
            request.httpBody = requestData
            
            print("Sending sync request to \(url)")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("Server response status: \(statusCode)")
                
                if let error = error {
                    print("Network error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    completion(.failure(SyncError.noData))
                    return
                }
                
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Server response raw: \(responseStr)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let syncResponse = try decoder.decode(SyncResponse.self, from: data)
                    print("Successfully decoded response with \(syncResponse.updatedItems.count) updated items")
                    completion(.success(syncResponse))
                    return
                } catch let decodingError {
                    print("Standard decoding failed: \(decodingError)")
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("Manual parsing - JSON keys: \(json.keys)")
                            
                            if let errorMessage = json["error"] as? String {
                                completion(.failure(SyncError.serverError(errorMessage)))
                                return
                            }
                            
                            let response = SyncResponse(
                                updatedItems: [], 
                                deletedIDs: json["deleted_ids"] as? [String] ?? [],
                                syncToken: json["sync_token"] as? String ?? "",
                                timestamp: Date() 
                            )
                            
                            print("Created fallback response")
                            completion(.success(response))
                            return
                        }
                    } catch {
                        print("Manual JSON parsing failed: \(error)")
                    }
                    
                    completion(.failure(SyncError.decodingError))
                }
            }.resume()
        } catch {
            print("Failed to prepare request: \(error)")
            completion(.failure(error))
        }
    }
    
    func getSyncStatus(completion: @escaping (Result<SyncStatusResponse, Error>) -> Void) {
        guard let url = serverURL?.appendingPathComponent("api/sync/status") else {
            completion(.failure(SyncError.serverNotAvailable))
            return
        }
        
        guard let authToken = authToken else {
            completion(.failure(SyncError.notAuthenticated))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SyncError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let syncStatus = try decoder.decode(SyncStatusResponse.self, from: data)
                completion(.success(syncStatus))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}


struct ServerInfo: Identifiable, Hashable {
    let id: String
    let name: String
    
    init(name: String, id: String) {
        self.name = name
        self.id = id
    }
    
    static func == (lhs: ServerInfo, rhs: ServerInfo) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct VaultFileMetadata {
    let id: UUID
    let encryptedMetadata: String
    let version: Int
    let lastModified: Date
    let isDeleted: Bool
}


struct AuthRequest: Codable {
    let username: String
    let password: String
    let deviceID: String
    
    enum CodingKeys: String, CodingKey {
        case username
        case password
        case deviceID = "device_id"
    }
}

struct AuthResponse: Codable {
    let token: String
    let expiresAt: Int64
    let userID: Int64
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case userID = "user_id"
    }
}

struct FileMetadata: Codable {
    let id: String
    let encryptedData: String
    let userID: Int64
    let version: Int
    let lastModifiedAt: Date
    let isDeleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case encryptedData = "encrypted_data"
        case userID = "user_id"
        case version
        case lastModifiedAt = "last_modified_at"
        case isDeleted = "is_deleted"
    }
}

struct SyncRequest: Codable {
    let deviceID: String
    let items: [FileMetadata]
    let syncToken: String
    
    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case items
        case syncToken = "sync_token"
    }
}

// Update SyncResponse to be more flexible
struct SyncResponse: Codable {
    let updatedItems: [FileMetadata]
    let deletedIDs: [String]
    let syncToken: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case updatedItems = "updated_items"
        case deletedIDs = "deleted_ids"
        case syncToken = "sync_token"
        case timestamp
    }
    
    init(updatedItems: [FileMetadata], deletedIDs: [String], syncToken: String, timestamp: Date) {
        self.updatedItems = updatedItems
        self.deletedIDs = deletedIDs
        self.syncToken = syncToken
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            updatedItems = try container.decode([FileMetadata].self, forKey: .updatedItems)
        } catch {
            print("Error decoding updatedItems: \(error)")
            updatedItems = []
        }
        
        do {
            deletedIDs = try container.decode([String].self, forKey: .deletedIDs)
        } catch {
            print("Error decoding deletedIDs: \(error)")
            deletedIDs = []
        }
        
        do {
            syncToken = try container.decode(String.self, forKey: .syncToken)
        } catch {
            print("Error decoding syncToken: \(error)")
            syncToken = ""
        }
        
        do {
            timestamp = try container.decode(Date.self, forKey: .timestamp)
        } catch {
            print("Error decoding timestamp as Date: \(error)")
            if let timestampString = try? container.decode(String.self, forKey: .timestamp),
               let date = ISO8601DateFormatter().date(from: timestampString) {
                timestamp = date
            } else {
                print("Using current date as fallback")
                timestamp = Date()
            }
        }
    }
}

struct SyncStatusResponse: Codable {
    let lastSyncAt: Date
    let deviceID: String
    let itemCount: Int
    let syncToken: String
    
    enum CodingKeys: String, CodingKey {
        case lastSyncAt = "last_sync_at"
        case deviceID = "device_id"
        case itemCount = "item_count"
        case syncToken = "sync_token"
    }
}

struct ErrorResponse: Codable {
    let error: String
}


enum SyncError: Error, LocalizedError {
    case serverNotAvailable
    case notAuthenticated
    case noData
    case invalidResponse
    case decodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .serverNotAvailable:
            return "Server not available"
        case .notAuthenticated:
            return "Not authenticated"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError:
            return "Error decoding server response"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
