import Foundation
import SwiftUI
import Combine

class VaultViewModel: ObservableObject {
    @Published var isVaultLocked = true
    @Published var isVaultSetup = false
    @Published var vaultFiles: [VaultFile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var auditLogs: [AuditEvent] = []
    @Published var syncStatus: String?
    @Published var isSyncing = false
    
    private let encryptionService = EncryptionService.shared
    private let auditLogger = AuditLogger.shared
    
    init() {
        checkVaultStatus()
    }
    
    private func checkVaultStatus() {
        isVaultSetup = encryptionService.isVaultSetup
        isVaultLocked = true
    }
    
    func setupVault(password: String) {
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty"
            return
        }
        
        let success = encryptionService.setupVault(withPassword: password)
        if success {
            isVaultLocked = false
            isVaultSetup = true
            auditLogger.logEvent(type: .vaultUnlocked, details: "Vault created and unlocked with password")
            loadVaultContents()
        } else {
            errorMessage = "Failed to set up vault"
        }
    }
    
    func unlockVault(password: String) {
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty"
            return
        }
        
        let success = encryptionService.unlockWithPassword(password: password)
        if success {
            isVaultLocked = false
            auditLogger.logEvent(type: .vaultUnlocked, details: "Vault unlocked with password")
            loadVaultContents()
        } else {
            errorMessage = "Incorrect password"
        }
    }
    
    func unlockVaultWithBiometrics() async {
        isLoading = true
        
        let success = await encryptionService.unlockWithBiometrics()
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                self.isVaultLocked = false
                self.auditLogger.logEvent(type: .vaultUnlocked, details: "Vault unlocked with biometrics")
                self.loadVaultContents()
            } else {
                self.errorMessage = "Biometric authentication failed"
            }
        }
    }
    
    func lockVault() {
        encryptionService.lockVault()
        isVaultLocked = true
        vaultFiles = []
        auditLogger.logEvent(type: .vaultLocked, details: "Vault locked")
    }
    
    func addFileToVault(url: URL) {
        guard !isVaultLocked else {
            errorMessage = "Vault is locked"
            return
        }
        
        isLoading = true
        
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Permission denied: Cannot access the selected file"
            isLoading = false
            return
        }
        
        do {
            let fileData = try Data(contentsOf: url)
            
            url.stopAccessingSecurityScopedResource()
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            
            try fileData.write(to: tempURL)
            
            _ = try encryptionService.encryptFile(at: tempURL)
            
            try? FileManager.default.removeItem(at: tempURL)
            
            loadVaultContents()
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = "Failed to add file: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadVaultContents() {
        guard !isVaultLocked else { return }
        
        isLoading = true
        
        do {
            vaultFiles = try encryptionService.getVaultContents()
        } catch {
            errorMessage = "Failed to load vault contents: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func accessFile(_ vaultFile: VaultFile) -> Data? {
        guard !isVaultLocked else {
            errorMessage = "Vault is locked"
            return nil
        }
        
        do {
            let (decryptedData, _) = try encryptionService.decryptFile(encryptedFileURL: vaultFile.encryptedURL)
            auditLogger.logEvent(type: .fileAccessed, fileURL: URL(string: vaultFile.originalName), details: "File accessed from vault")
            return decryptedData
        } catch {
            errorMessage = "Failed to decrypt file: \(error.localizedDescription)"
            return nil
        }
    }
    
    func deleteFile(_ vaultFile: VaultFile) {
        guard !isVaultLocked else {
            errorMessage = "Vault is locked"
            return
        }
        
        do {
            try FileManager.default.removeItem(at: vaultFile.encryptedURL)
            let metadataURL = URL(string: vaultFile.encryptedURL.absoluteString + ".meta")!
            try FileManager.default.removeItem(at: metadataURL)
            
            auditLogger.logEvent(type: .fileDeleted, fileURL: URL(string: vaultFile.originalName), details: "File deleted from vault")
            
            loadVaultContents()
        } catch {
            errorMessage = "Failed to delete file: \(error.localizedDescription)"
        }
    }
    
    func loadAuditLogs() {
        auditLogs = auditLogger.getAuditLogs()
    }
    
    func syncWithServer() {
        guard !isVaultLocked else {
            errorMessage = "Vault is locked"
            return
        }
        
        isSyncing = true
        syncStatus = "Preparing files for sync..."
        
        let syncViewModel = SyncViewModel()
        
        syncStatus = "Connecting to server..."
        
        syncViewModel.connectToLocalServer()
        
        let connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            if syncViewModel.isConnected {
                timer.invalidate()
                self.syncStatus = "Authenticating..."
                
                syncViewModel.login(username: "demo", password: "password") { success, message in
                    if success {
                        self.syncStatus = "Syncing files..."
                        
                        syncViewModel.syncVaultFiles(
                            vaultFiles: self.vaultFiles, 
                            encryptionService: self.encryptionService
                        )
                        
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
                            if syncViewModel.syncProgress == 1.0 {
                                t.invalidate()
                                self.syncStatus = "Sync completed"
                                self.loadVaultContents() 
                                self.isSyncing = false
                            } else if syncViewModel.errorMessage != nil {
                                t.invalidate()
                                self.errorMessage = syncViewModel.errorMessage
                                self.syncStatus = "Sync failed"
                                self.isSyncing = false
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                            if progressTimer.isValid {
                                progressTimer.invalidate()
                                self.errorMessage = "Sync operation timed out"
                                self.syncStatus = "Sync failed"
                                self.isSyncing = false
                            }
                        }
                    } else {
                        self.isSyncing = false
                        self.errorMessage = "Authentication failed: \(message)"
                        self.syncStatus = "Sync failed"
                    }
                }
            } else if syncViewModel.errorMessage != nil || syncViewModel.isLoading == false {
                timer.invalidate()
                self.isSyncing = false
                self.errorMessage = syncViewModel.errorMessage ?? "Could not connect to server"
                self.syncStatus = "Sync failed"
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if connectionCheckTimer.isValid {
                connectionCheckTimer.invalidate()
                self.isSyncing = false
                self.errorMessage = "Connection timed out"
                self.syncStatus = "Sync failed"
            }
        }
    }
}
