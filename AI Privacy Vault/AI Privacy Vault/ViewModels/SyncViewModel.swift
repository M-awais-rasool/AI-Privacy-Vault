import Foundation
import Combine

class SyncViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncProgress: Double = 0
    @Published var lastSyncTime: Date?
    @Published var itemCount: Int = 0
    
    @Published var discoveredServers: [ServerInfo] = []
    @Published var selectedServer: ServerInfo?
    
    private let syncService = MetadataSyncService.shared
    var cancellables = Set<AnyCancellable>()
    
    init() {
    }
    
    func connectToLocalServer() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let localServer = ServerInfo(name: "Local Server", id: "local-server")
        selectedServer = localServer
        
        syncService.connectToLocalServer { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if success {
                    self.isConnected = true
                    self.checkServerStatus()
                } else {
                    self.errorMessage = "Failed to connect to local server"
                    self.isConnected = false
                }
            }
        }
    }
    
    func connectToServer(_ server: ServerInfo) {
        connectToLocalServer()
    }
    
    func checkServerStatus() {
        guard isConnected, !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        syncService.checkServerStatus { [weak self] isOnline in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if !isOnline {
                    self.errorMessage = "Server is offline"
                    self.isConnected = false
                }
            }
        }
    }
    
    func register(username: String, password: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        guard isConnected, !isLoading else {
            completion(false, "Not connected to server")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        syncService.register(username: username, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.isAuthenticated = true
                    print("Registered user ID: \(response.userID)")
                    self.getSyncStatus()
                    completion(true, "Registration successful")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    func login(username: String, password: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        guard isConnected, !isLoading else {
            completion(false, "Not connected to server")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        syncService.login(username: username, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.isAuthenticated = true
                    print("Logged in user ID: \(response.userID)")
                    self.getSyncStatus()
                    completion(true, "Login successful")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    func getSyncStatus() {
        guard isAuthenticated, !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        syncService.getSyncStatus { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let status):
                    self.lastSyncTime = status.lastSyncAt
                    self.itemCount = status.itemCount
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func prepareMetadataForSync(vaultFiles: [VaultFile], encryptionService: EncryptionService) -> [VaultFileMetadata] {
        return vaultFiles.map { file in
            let fileInfo = [
                "filename": file.originalName,
                "size": String(file.size), 
                "date_added": String(file.dateAdded.timeIntervalSince1970) 
            ]
            
            let jsonData = try? JSONSerialization.data(withJSONObject: fileInfo)
            let encryptedData = jsonData?.base64EncodedString() ?? ""
            
            return VaultFileMetadata(
                id: file.id,
                encryptedMetadata: encryptedData,
                version: 1,
                lastModified: file.dateAdded,
                isDeleted: false
            )
        }
    }
    
    func syncVaultFiles(vaultFiles: [VaultFile], encryptionService: EncryptionService) {
        guard isAuthenticated, !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        syncProgress = 0.1
        
        if vaultFiles.isEmpty {
            print("No files to sync")
            syncProgress = 1.0
            isLoading = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.syncProgress = 0
            }
            return
        }
        
        let metadataToSync = prepareMetadataForSync(vaultFiles: vaultFiles, encryptionService: encryptionService)
        print("Preparing to sync \(metadataToSync.count) files")
        
        if let firstFile = metadataToSync.first {
            print("First file ID: \(firstFile.id)")
            print("First file metadata length: \(firstFile.encryptedMetadata.count) chars")
        }
        
        syncProgress = 0.3
        
        let syncToken = UserDefaults.standard.string(forKey: "last_sync_token") ?? ""
        
        syncService.syncMetadata(files: metadataToSync, syncToken: syncToken) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.syncProgress = 0.7
                
                switch result {
                case .success(let response):
                    print("Sync successful!")
                    print("- Updated items: \(response.updatedItems.count)")
                    print("- Deleted IDs: \(response.deletedIDs.count)")
                    print("- Sync token: \(response.syncToken)")
                    print("- Timestamp: \(response.timestamp)")
                    
                    self.lastSyncTime = response.timestamp
                    self.syncProgress = 1.0
                    self.itemCount = response.updatedItems.count
                    
                    UserDefaults.standard.set(response.syncToken, forKey: "last_sync_token")
                    
                case .failure(let error):
                    print("Sync error: \(error)")
                    
                    if let syncError = error as? SyncError, case .decodingError = syncError {
                        self.errorMessage = "Server response format is incorrect. Check server version compatibility."
                    } else {
                        self.errorMessage = "Sync failed: \(error.localizedDescription)"
                    }
                }
                
                self.isLoading = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.syncProgress = 0
                }
            }
        }
    }
}
