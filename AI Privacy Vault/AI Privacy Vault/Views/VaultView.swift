import SwiftUI
import LocalAuthentication

struct VaultView: View {
    @StateObject private var viewModel = VaultViewModel()
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingUnlockSheet = false
    @State private var showingSetupSheet = false
    @State private var showingAuditLogs = false
    @State private var showFileImporter = false
    @State private var selectedFile: VaultFile?
    @State private var showingServerConnectionSheet = false
    
    var body: some View {
        Group {
            if !viewModel.isVaultSetup {
                setupVaultView
            } else if viewModel.isVaultLocked {
                lockedVaultView
            } else {
                unlockedVaultView
            }
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage != nil ? ViewError(message: viewModel.errorMessage!) : nil },
            set: { _ in viewModel.errorMessage = nil }
        )) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingUnlockSheet) {
            unlockVaultView
        }
        .sheet(isPresented: $showingSetupSheet) {
            setupPasswordView
        }
        .sheet(isPresented: $showingAuditLogs) {
            auditLogView
        }
        .sheet(isPresented: $showingServerConnectionSheet) {
            ServerConnectionView()
                .environmentObject(viewModel)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.addFileToVault(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = "File import failed: \(error.localizedDescription)"
            }
        }
    }
    
    private var setupVaultView: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]), 
                           startPoint: .topLeading, 
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 10)
                
                Text("Set Up Your Secure Vault")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Create a secure vault to store your most sensitive files.\nAll files will be encrypted with AES-256 encryption.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 400)
                    .padding(.bottom, 20)
                
                Button(action: {
                    withAnimation {
                        showingSetupSheet = true
                    }
                }) {
                    Text("Create Vault")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]), 
                                          startPoint: .leading, 
                                          endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .padding(.top, 10)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.windowBackgroundColor).opacity(0.7))
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
            )
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var setupPasswordView: some View {
        ZStack {
            Color(.windowBackgroundColor).opacity(0.97).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Image(systemName: "key.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)
                
                Text("Create Master Password")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("This password will be used to unlock your vault.\nMake sure it's strong and memorable.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                
                VStack(spacing: 15) {
                    SecureField("Enter Master Password", text: $password)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    SecureField("Confirm Master Password", text: $confirmPassword)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        password = ""
                        confirmPassword = ""
                        showingSetupSheet = false
                    }
                    .keyboardShortcut(.escape)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    
                    Button("Create Vault") {
                        if password == confirmPassword && !password.isEmpty {
                            viewModel.setupVault(password: password)
                            if !viewModel.isVaultLocked {
                                password = ""
                                confirmPassword = ""
                                showingSetupSheet = false
                            }
                        } else if password != confirmPassword {
                            viewModel.errorMessage = "Passwords do not match"
                        } else {
                            viewModel.errorMessage = "Password cannot be empty"
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(password.isEmpty || password != confirmPassword)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                    .background(
                        (password.isEmpty || password != confirmPassword) ?
                            Color.accentColor.opacity(0.3) :
                            Color.accentColor
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
            )
        }
    }
    
    private var lockedVaultView: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), 
                           startPoint: .topLeading, 
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 10)
                    .rotationEffect(.degrees(viewModel.isLoading ? 10 : 0))
                    .animation(viewModel.isLoading ? Animation.easeInOut(duration: 0.2).repeatForever(autoreverses: true) : .default, value: viewModel.isLoading)
                
                Text("Secure Vault is Locked")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Your encrypted files are securely stored.\nUnlock the vault to access your protected files.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 400)
                    .padding(.bottom, 20)
                
                VStack(spacing: 15) {
                    Button(action: {
                        withAnimation {
                            showingUnlockSheet = true
                        }
                    }) {
                        Text("Unlock Vault")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .frame(width: 250)
                            .background(
                                LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]), 
                                              startPoint: .leading, 
                                              endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if canUseBiometrics() {
                        Button(action: {
                            Task {
                                await viewModel.unlockVaultWithBiometrics()
                            }
                        }) {
                            HStack {
                                Image(systemName: "touchid")
                                    .font(.headline)
                                Text("Unlock with Touch ID")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .frame(width: 250)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.windowBackgroundColor).opacity(0.7))
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
            )
            .padding(40)
            .overlay(
                Group {
                    if viewModel.isLoading {
                        ZStack {
                            Color.black.opacity(0.4)
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding()
                                Text("Authenticating...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                            .padding(30)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(.windowBackgroundColor).opacity(0.9))
                            )
                        }
                        .transition(.opacity)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var unlockVaultView: some View {
        ZStack {
            Color(.windowBackgroundColor).opacity(0.97).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Image(systemName: "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)
                
                Text("Unlock Vault")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Enter your master password to access the vault")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                SecureField("Enter Master Password", text: $password)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        password = ""
                        showingUnlockSheet = false
                    }
                    .keyboardShortcut(.escape)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    
                    Button("Unlock") {
                        viewModel.unlockVault(password: password)
                        if !viewModel.isVaultLocked {
                            password = ""
                            showingUnlockSheet = false
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(password.isEmpty)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                    .background(password.isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
            )
        }
    }
    
    private var unlockedVaultView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 15) {
                Image(systemName: "shield.checkerboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)
                
                Text("Secure Vault")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
                
                Button(action: {
                    viewModel.loadAuditLogs()
                    showingAuditLogs = true
                }) {
                    Label("Access Logs", systemImage: "list.bullet.clipboard")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Color(.controlBackgroundColor).opacity(0.7))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Access Logs")
                
                Button(action: {
                    showFileImporter = true
                }) {
                    Label("Add File", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Color(.controlBackgroundColor).opacity(0.7))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add File")
                
                Button(action: {
                    showingServerConnectionSheet = true
                }) {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Color(.controlBackgroundColor).opacity(0.7))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Sync")
                
                Button(action: {
                    withAnimation {
                        viewModel.lockVault()
                    }
                }) {
                    Label("Lock Vault", systemImage: "lock.fill")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Lock Vault")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                Color(.windowBackgroundColor)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
            )
            
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading...")
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else if viewModel.vaultFiles.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "folder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text("No files in vault")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    
                    Text("Add files to securely encrypt and store them")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showFileImporter = true
                    }) {
                        Label("Add Your First File", systemImage: "plus.circle.fill")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.vaultFiles) { file in
                            VaultFileRow(file: file)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .contextMenu {
                                    Button(action: {
                                        if let data = viewModel.accessFile(file) {
                                            exportFile(data: data, filename: file.originalName)
                                        }
                                    }) {
                                        Label("Open", systemImage: "eye")
                                    }
                                    
                                    Button(action: {
                                        viewModel.deleteFile(file)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.97))
        .onAppear {
            viewModel.loadVaultContents()
        }
    }
    
    private var auditLogView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Access Audit Logs")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: {
                    showingAuditLogs = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.auditLogs) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: log.eventType.icon)
                                    .foregroundColor(log.eventType.color)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle()
                                            .fill(log.eventType.color.opacity(0.1))
                                            .frame(width: 30, height: 30)
                                    )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(log.eventType.rawValue)
                                        .fontWeight(.medium)
                                    
                                    Text(log.formattedTimestamp)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            if let filename = log.filename {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.accentColor.opacity(0.7))
                                        .font(.caption)
                                    Text("File: \(filename)")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .padding(.leading, 30)
                            }
                            
                            Text(log.details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 30)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.controlBackgroundColor).opacity(0.5))
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.97))
        .frame(width: 600, height: 400)
    }
    
    // Helper function to check if biometrics are available
    private func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // Helper function to export/preview a file
    private func exportFile(data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        
        // Open the file using the system default application
        NSWorkspace.shared.open(tempURL)
    }
}

// Helper Views
struct VaultFileRow: View {
    let file: VaultFile
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForFile(file.originalName).opacity(0.15))
                    .frame(width: 45, height: 45)
                
                Image(systemName: getSystemIconForFile(file.originalName))
                    .font(.system(size: 22))
                    .foregroundColor(colorForFile(file.originalName))
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(file.originalName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 15) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(file.dateAdded))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(formatFileSize(file.size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("Encrypted")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.green.opacity(0.1))
                    )
            )
        }
        .padding(.vertical, 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func getSystemIconForFile(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png": return "photo.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "chart.bar.doc.horizontal.fill"
        case "txt": return "doc.plaintext.fill"
        default: return "doc.fill"
        }
    }
    
    private func colorForFile(_ fileName: String) -> Color {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf": return .red
        case "jpg", "jpeg", "png": return .blue
        case "doc", "docx": return .purple
        case "xls", "xlsx": return .green
        case "txt": return .orange
        default: return .accentColor
        }
    }
}

// Helper for displaying errors
struct ViewError: Identifiable {
    let id = UUID()
    let message: String
}
