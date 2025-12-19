//
//  SettingsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var creditManager: CreditManager
    @EnvironmentObject var debtManager: DebtManager
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                // General settings - most commonly used, ordered by importance
                Section(String(localized: "General", comment: "General settings section")) {
                    // Language first for accessibility
                    Picker(String(localized: "Language", comment: "Language picker"), selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    
                    // Theme for visual preferences
                    Picker(String(localized: "Theme", comment: "Theme picker"), selection: $settings.theme) {
                        ForEach(ThemeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    
                    // Currency for financial display
                    Picker(String(localized: "Currency", comment: "Currency picker"), selection: $settings.currency) {
                        ForEach(["USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "INR", "PLN", "RUB", "BRL", "MXN", "KRW", "SGD", "HKD", "NZD", "SEK", "NOK", "DKK"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    
                    // Start day for monthly calculations
                    Picker(String(localized: "Start day of month", comment: "Start day of month label"), selection: $settings.startDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)\(daySuffix(day))").tag(day)
                        }
                    }
                }
                
                // Accounts & Categories - data management
                Section(String(localized: "Accounts & Categories", comment: "Accounts & Categories section")) {
                    // Default Account Picker
                    if !accountManager.accounts.isEmpty {
                        Picker(String(localized: "Default Account", comment: "Default account picker"), selection: Binding(
                            get: { accountManager.defaultAccountId },
                            set: { accountManager.setDefaultAccount($0) }
                        )) {
                            Text(String(localized: "None", comment: "No default account")).tag(nil as UUID?)
                            ForEach(accountManager.accounts) { account in
                                Text(account.name).tag(account.id as UUID?)
                            }
                        }
                    }
                    
                    NavigationLink(String(localized: "Manage categories", comment: "Manage categories link")) {
                        CategoryManagementView()
                            .environmentObject(settings)
                    }
                }
                
                // Notifications - all notification preferences together
                Section(String(localized: "Notifications", comment: "Notifications section")) {
                    Toggle(String(localized: "Payment reminders", comment: "Payment reminders toggle"), isOn: $settings.notificationsEnabled)
                    Toggle(String(localized: "Subscription alerts", comment: "Subscription alerts toggle"), isOn: $settings.subscriptionAlerts)
                }
                
                // Premium - subscription management
                Section(String(localized: "Premium", comment: "Premium section")) {
                    Button(role: settings.premiumEnabled ? .destructive : .none) {
                        settings.premiumEnabled.toggle()
                    } label: {
                        Text(settings.premiumEnabled ? String(localized: "Cancel subscription", comment: "Cancel subscription button") : String(localized: "Start premium trial", comment: "Start premium trial button"))
                            .foregroundStyle(settings.premiumEnabled ? .red : .accentColor)
                    }
                }
                
                // Data & Backup - advanced features at the end
                Section(String(localized: "Data & Backup", comment: "Data & Backup section")) {
                    Button(String(localized: "Export local backup", comment: "Export backup button")) {
                        // TODO: integrate backup flow
                    }
                    Button(String(localized: "Restore from backup", comment: "Restore backup button")) {
                        // TODO: integrate restore flow
                    }
                }
                
                #if DEBUG
                // STEP 0: A/B TEST - GPU Performance Toggle
                Section("Debug - GPU Performance") {
                    Toggle("Fast Row Style (No clipShape/overlay)", isOn: Binding(
                        get: { TransactionsView.USE_FAST_ROW_STYLE },
                        set: { 
                            // Use reflection or make it mutable
                            // For now, user needs to change the flag in code
                        }
                    ))
                    .disabled(true)
                    Text("Change TransactionsView.USE_FAST_ROW_STYLE in code to toggle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
                
                // Reset Data - dangerous action
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Text(String(localized: "Reset all data", comment: "Reset all data button"))
                    }
                } footer: {
                    Text(String(localized: "This will permanently delete all transactions, accounts, subscriptions, credits, and debts. This action cannot be undone.", comment: "Reset data warning"))
                }
            }
            .alert(String(localized: "Reset all data", comment: "Reset confirmation title"), isPresented: $showResetConfirmation) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Reset", comment: "Reset confirmation button"), role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text(String(localized: "Are you sure you want to reset all data? This will permanently delete all your transactions, accounts, subscriptions, credits, and debts. This action cannot be undone.", comment: "Reset confirmation message"))
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(Text("Settings", comment: "Settings view title"))
        }
    }
    
    // MARK: - Reset Data
    
    private func resetAllData() {
        // Reset all managers
        transactionManager.reset()
        accountManager.reset()
        subscriptionManager.reset()
        creditManager.reset()
        debtManager.reset()
    }
}

private func daySuffix(_ day: Int) -> String {
    switch day {
    case 1, 21:
        return "st"
    case 2, 22:
        return "nd"
    case 3, 23:
        return "rd"
    default:
        return "th"
    }
}


