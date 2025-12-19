//
//  ContentView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts
import Combine
import UIKit

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var debtManager: DebtManager
    @EnvironmentObject var creditManager: CreditManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Int = 0
    
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
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("", systemImage: "square.grid.2x2")
                }
                .tag(0)
                .id("tab-0-\(selectedTab)")
            
            TransactionsView()
                .tabItem {
                    Label("", systemImage: "list.bullet")
                }
                .tag(1)
                .id("tab-1-\(selectedTab)")
            
            StatisticsView()
                .tabItem {
                    Label("", systemImage: "chart.bar")
                }
                .tag(2)
                .id("tab-2-\(selectedTab)")
            
            AIChatView()
                .tabItem {
                    Label("", systemImage: "sparkles")
                }
                .tag(3)
                .id("tab-3-\(selectedTab)")
            
            SettingsView()
                .tabItem {
                    Label("", systemImage: "gearshape")
                }
                .tag(4)
                .id("tab-4-\(selectedTab)")
        }
        .preferredColorScheme(colorScheme)
        .environment(\.locale, settings.locale)
        .onAppear {
            // Hide tab bar labels to make it icon-only
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            // Remove title text completely
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
            appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            
            // Ensure future transactions are maintained (12 months ahead)
            subscriptionManager.ensureFutureTransactions()
        }
    }
}

#Preview {
    ContentView()
}
