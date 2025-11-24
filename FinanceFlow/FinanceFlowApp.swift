//
//  FinanceFlowApp.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

@main
struct FinanceFlowApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .environment(\.locale, settings.locale)
            } else {
                AuthView()
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .environment(\.locale, settings.locale)
            }
        }
    }
}
