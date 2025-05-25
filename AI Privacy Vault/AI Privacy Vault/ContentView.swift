//
//  ContentView.swift
//  AI Privacy Vault
//
//  Created by Ch Awais on 24/05/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vaultViewModel = VaultViewModel()
    @StateObject private var viewModel = FileViewModel()
    @State private var searchText: String = ""
    @State private var selectedCategory: Category = .all
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
                .onChange(of: selectedCategory) { newValue in
                    DispatchQueue.main.async {
                        viewModel.selectedCategory = newValue
                    }
                }
        } detail: {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { newValue in
                            viewModel.searchText = newValue
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                
                DragDropView(viewModel: viewModel)
                    .environmentObject(vaultViewModel)
                
                FileListView(viewModel: viewModel)
            }
            .frame(minWidth: 400, minHeight: 300)
            .alert(item: Binding<ViewError?>(
                get: { viewModel.errorMessage.map { ViewError(message: $0) } },
                set: { viewModel.errorMessage = $0?.message }
            )) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationTitle("AI Privacy Vault")
        .onAppear {
            selectedCategory = viewModel.selectedCategory
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    openFileImporter()
                }) {
                    Label("Open File", systemImage: "plus")
                }
            }
        }
        .environmentObject(vaultViewModel)
    }
    
    private func openFileImporter() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.addFile(url: url, category: selectedCategory)
        }
    }
}

// Helper for error alerts - Define if it doesn't already exist
//struct ViewError: Identifiable {
//    let id = UUID()
//    let message: String
//}

#Preview {
    ContentView()
}
