import SwiftUI

struct ServerConnectionView: View {
    @StateObject private var viewModel = SyncViewModel()
    @EnvironmentObject private var vaultViewModel: VaultViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username = ""
    @State private var password = ""
    @State private var isShowingAuth = false
    @State private var isSignUp = false
    @State private var showLoginError = false
    @State private var loginErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Top bar with title and close button
            HStack {
                Text("Server Synchronization")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            // Connection status
            HStack {
                Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(viewModel.isConnected ? .green : .red)
                Text(viewModel.isConnected ? "Connected" : "Not Connected")
                
                Spacer()
                
                if viewModel.isAuthenticated {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundColor(.green)
                    Text("Authenticated")
                }
            }
            .padding(.horizontal)
            
            // Direct connection to local server - simplified UI
            if !viewModel.isConnected {
                VStack(spacing: 15) {
                    Image(systemName: "server.rack")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .foregroundColor(.accentColor)
                    
                    Text("Connect to your local AI Privacy Vault Server")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("Your server is running on your local machine or network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    
                    Button(action: {
                        viewModel.connectToLocalServer()
                    }) {
                        HStack {
                            Image(systemName: "network")
                            Text("Connect to Local Server")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.isLoading)
                }
                .padding()
                .background(Color(.windowBackgroundColor).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Authentication and sync section
            if viewModel.isConnected {
                if viewModel.isAuthenticated {
                    syncStatusView
                } else {
                    Button("Login or Sign Up") {
                        isShowingAuth = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top)
                }
            }
            
            // Error messages
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 400)
        .sheet(isPresented: $isShowingAuth) {
            authenticationView
                .frame(width: 350, height: 250)
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Processing...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(.windowBackgroundColor).opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
        )
        .onAppear {
            // Automatically attempt to connect to local server
            viewModel.connectToLocalServer()
        }
    }
    
    private var syncStatusView: some View {
        VStack(spacing: 15) {
            if let lastSyncTime = viewModel.lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                    Text("Last sync: \(formattedDate(lastSyncTime))")
                    Spacer()
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "doc.fill")
                    Text("Items synchronized: \(viewModel.itemCount)")
                    Spacer()
                }
                .font(.caption)
            }
            
            if viewModel.syncProgress > 0 {
                ProgressView(value: viewModel.syncProgress)
                    .padding(.vertical, 5)
            }
            
            Button("Synchronize Vault Files") {
                viewModel.syncVaultFiles(
                    vaultFiles: vaultViewModel.vaultFiles,
                    encryptionService: EncryptionService.shared
                )
            }
            .disabled(viewModel.isLoading)
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var authenticationView: some View {
        ZStack {
            VStack(spacing: 15) {
                Text(isSignUp ? "Create Account" : "Login")
                    .font(.headline)
                
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        authenticateUser()
                    }
                
                HStack {
                    Button(isSignUp ? "Back to Login" : "Need an account?") {
                        isSignUp.toggle()
                        showLoginError = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    
                    Spacer()
                    
                    Button(isSignUp ? "Sign Up" : "Login") {
                        authenticateUser()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || viewModel.isLoading)
                }
                
                Spacer()
            }
            .padding()
            .onDisappear {
                // Clear fields when sheet closes
                username = ""
                password = ""
                showLoginError = false
            }
            
            // Error popup overlay
            if showLoginError {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        
                        Text(loginErrorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: {
                            showLoginError = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red)
                    )
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: showLoginError)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func authenticateUser() {
        if isSignUp {
            viewModel.register(username: username, password: password) { success, message in
                if success {
                    isShowingAuth = false
                } else {
                    showLoginError = true
                    loginErrorMessage = message
                }
            }
        } else {
            viewModel.login(username: username, password: password) { success, message in
                if success {
                    isShowingAuth = false
                } else {
                    showLoginError = true
                    loginErrorMessage = message
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ServerConnectionView()
        .environmentObject(VaultViewModel())
}
