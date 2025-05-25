//
//  AI_Privacy_VaultApp.swift
//  AI Privacy Vault
//
//  Created by Ch Awais on 24/05/2025.
//

import SwiftUI

@main
struct AI_Privacy_VaultApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("AI Privacy Scanner", systemImage: "shield.lefthalf.filled")
                    }
                
                VaultView()
                    .tabItem {
                        Label("Secure Vault", systemImage: "lock.shield")
                    }
            }
            .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
