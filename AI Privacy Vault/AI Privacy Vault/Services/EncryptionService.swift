import Foundation
import CryptoKit
import Security
import LocalAuthentication

class EncryptionService {
    static let shared = EncryptionService()
    
    private let saltKey = "AI_Privacy_Vault_Salt"
    private let keyName = "AI_Privacy_Vault_Master_Key"
    
    private var masterKey: SymmetricKey?
    
    private var secureContainerURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("SecureVault", isDirectory: true)
    }
    
    private init() {
        createSecureContainerIfNeeded()
    }
    
    private func createSecureContainerIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: secureContainerURL.path) {
            do {
                try fileManager.createDirectory(at: secureContainerURL, withIntermediateDirectories: true)
                
                var urlResourceValues = URLResourceValues()
                urlResourceValues.isExcludedFromBackup = true
                
                var secureURL = secureContainerURL
                try secureURL.setResourceValues(urlResourceValues)
                
                print("Secure container created at: \(secureContainerURL.path)")
            } catch {
                print("Error creating secure container: \(error)")
            }
        }
    }
    
    
    func setupVault(withPassword password: String) -> Bool {
        do {
            let key = deriveKeyFromPassword(password: password)
            masterKey = key
            
            try saveKeyToKeychain(key: key.withUnsafeBytes { Data($0) })
            
            return true
        } catch {
            print("Error setting up vault: \(error)")
            return false
        }
    }
    
    func unlockWithPassword(password: String) -> Bool {
        do {
            let key = deriveKeyFromPassword(password: password)
            masterKey = key
            
            let storedKey = try retrieveKeyFromKeychain()
            return key.withUnsafeBytes { keyBytes in
                storedKey.withUnsafeBytes { storedBytes in
                    keyBytes.elementsEqual(storedBytes)
                }
            }
        } catch {
            print("Error unlocking vault: \(error)")
            return false
        }
    }
    
    func unlockWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Biometrics not available: \(String(describing: error))")
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock AI Privacy Vault")
            
            if success {
                let storedKey = try retrieveKeyFromKeychain()
                masterKey = SymmetricKey(data: storedKey)
                return true
            } else {
                return false
            }
        } catch {
            print("Biometric authentication failed: \(error)")
            return false
        }
    }
    
    
    private func deriveKeyFromPassword(password: String) -> SymmetricKey {
        let salt = saltKey.data(using: .utf8)!
        
        var keyData = password.data(using: .utf8)!
        
        for _ in 0..<100_000 {
            var hasher = SHA256()
            hasher.update(data: keyData)
            hasher.update(data: salt)
            keyData = Data(hasher.finalize())
        }
        
        return SymmetricKey(data: keyData.prefix(32))
    }
    
    private func saveKeyToKeychain(key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyName,
            kSecValueData as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }
    
    private func retrieveKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
        
        guard let data = dataTypeRef as? Data else {
            throw NSError(domain: "EncryptionServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Retrieved data is not of correct type"])
        }
        
        return data
    }
    
    var isVaultSetup: Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyName,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    
    func encryptFile(at url: URL) throws -> URL {
        guard let masterKey = self.masterKey else {
            throw NSError(domain: "EncryptionServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vault is locked. Unlock first."])
        }
        
        let fileData = try Data(contentsOf: url)
        
        let nonce = AES.GCM.Nonce()
        
        let sealedBox = try AES.GCM.seal(fileData, using: masterKey, nonce: nonce)
        let encryptedData = sealedBox.combined!
        
        let encryptedFileName = UUID().uuidString + ".encrypted"
        let encryptedFileURL = secureContainerURL.appendingPathComponent(encryptedFileName)
        
        try encryptedData.write(to: encryptedFileURL)
        
        let metadata = [
            "originalFileName": url.lastPathComponent,
            "dateEncrypted": Date().timeIntervalSince1970,
            "nonce": nonce.withUnsafeBytes { Data($0).base64EncodedString() }
        ] as [String : Any]
        
        let metadataURL = secureContainerURL.appendingPathComponent(encryptedFileName + ".meta")
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try metadataData.write(to: metadataURL)
        
        AuditLogger.shared.logEvent(type: .fileEncrypted, fileURL: url, details: "File encrypted and stored in vault")
        
        return encryptedFileURL
    }
    
    func decryptFile(encryptedFileURL: URL) throws -> (data: Data, originalFilename: String) {
        guard let masterKey = self.masterKey else {
            throw NSError(domain: "EncryptionServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vault is locked. Unlock first."])
        }
        
        let encryptedData = try Data(contentsOf: encryptedFileURL)
        
        let metadataURL = URL(string: encryptedFileURL.absoluteString + ".meta")!
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONSerialization.jsonObject(with: metadataData) as! [String: Any]
        
        let originalFileName = metadata["originalFileName"] as! String
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)
        
        AuditLogger.shared.logEvent(type: .fileDecrypted, fileURL: encryptedFileURL, details: "File decrypted: \(originalFileName)")
        
        return (decryptedData, originalFileName)
    }
    
    func getVaultContents() throws -> [VaultFile] {
        let fileManager = FileManager.default
        
        let files = try fileManager.contentsOfDirectory(at: secureContainerURL, includingPropertiesForKeys: nil)
        
        var vaultFiles = [VaultFile]()
        
        for file in files {
            if file.pathExtension == "encrypted" {
                do {
                    let metadataURL = URL(string: file.absoluteString + ".meta")!
                    let metadataData = try Data(contentsOf: metadataURL)
                    let metadata = try JSONSerialization.jsonObject(with: metadataData) as! [String: Any]
                    
                    let originalFileName = metadata["originalFileName"] as! String
                    let dateEncrypted = Date(timeIntervalSince1970: metadata["dateEncrypted"] as! TimeInterval)
                    
                    let attributes = try fileManager.attributesOfItem(atPath: file.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    let vaultFile = VaultFile(
                        id: UUID(),
                        originalName: originalFileName,
                        encryptedURL: file,
                        dateAdded: dateEncrypted,
                        size: fileSize
                    )
                    
                    vaultFiles.append(vaultFile)
                } catch {
                    print("Error processing vault file \(file): \(error)")
                }
            }
        }
        
        return vaultFiles
    }
    
    var isVaultUnlocked: Bool {
        return masterKey != nil
    }
    
    func lockVault() {
        masterKey = nil
    }
    
    func encryptMetadata(_ file: VaultFile) throws -> String {
        guard let masterKey = self.masterKey else {
            throw NSError(domain: "EncryptionServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vault is locked. Unlock first."])
        }
        
        let metadata = [
            "filename": file.originalName,
            "size": file.size,
            "date_added": file.dateAdded.timeIntervalSince1970,
            "file_id": file.id.uuidString
        ] as [String: Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata)
        
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(jsonData, using: masterKey, nonce: nonce)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
}

struct VaultFile: Identifiable, Hashable {
    let id: UUID
    let originalName: String
    let encryptedURL: URL
    let dateAdded: Date
    let size: Int64
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VaultFile, rhs: VaultFile) -> Bool {
        return lhs.id == rhs.id
    }
}

extension URLResourceValues {
    init(isExcludedFromBackup: Bool) {
        self.init()
        self.isExcludedFromBackup = isExcludedFromBackup
    }
}
