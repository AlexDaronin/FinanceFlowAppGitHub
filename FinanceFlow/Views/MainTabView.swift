//
//  MainTabView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var settings = AppSettings()
    @State private var sharedTransactions = Transaction.sample
    @State private var sharedAccounts = Account.sample
    
    private var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var body: some View {
        TabView {
            DashboardView(transactions: $sharedTransactions, accounts: $sharedAccounts)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                }
            
            TransactionsView(transactions: $sharedTransactions, accounts: $sharedAccounts)
                .tabItem {
                    Image(systemName: "list.bullet")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                }
            
            AIChatView()
                .tabItem {
                    Image(systemName: "sparkles")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                }
        }
        .preferredColorScheme(colorScheme)
        .environmentObject(settings)
    }
}

