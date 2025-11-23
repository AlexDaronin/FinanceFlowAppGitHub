//
//  AuthManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let userDefaultsKey = "isAuthenticated"
    
    init() {
        // Check if user was previously authenticated
        isAuthenticated = UserDefaults.standard.bool(forKey: userDefaultsKey)
        if isAuthenticated {
            // Load user data if needed
            loadUserData()
        }
    }
    
    @MainActor
    func signIn(with provider: AuthProvider, email: String? = nil, name: String? = nil) {
        // In a real app, this would handle actual authentication
        // For now, we'll simulate successful authentication
        isAuthenticated = true
        currentUser = User(
            id: UUID().uuidString,
            email: email ?? "user@example.com",
            name: name ?? "User",
            provider: provider
        )
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        saveUserData()
    }
    
    @MainActor
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
    }
    
    @MainActor
    private func loadUserData() {
        // Load user data from UserDefaults or keychain
        currentUser = User(
            id: UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString,
            email: UserDefaults.standard.string(forKey: "userEmail") ?? "",
            name: UserDefaults.standard.string(forKey: "userName") ?? "User",
            provider: AuthProvider(rawValue: UserDefaults.standard.string(forKey: "authProvider") ?? "email") ?? .email
        )
    }
    
    private func saveUserData() {
        guard let user = currentUser else { return }
        UserDefaults.standard.set(user.id, forKey: "userId")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(user.name, forKey: "userName")
        UserDefaults.standard.set(user.provider.rawValue, forKey: "authProvider")
    }
}

