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
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var accountManager = AccountManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var debtManager = DebtManager()
    @StateObject private var creditManager = CreditManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .environmentObject(transactionManager)
                    .environmentObject(accountManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(debtManager)
                    .environmentObject(creditManager)
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
