//
//  FinanceFlowApp.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import SwiftData

private func migrateDataIfNeeded(context: ModelContext) {
    let migrationKey = "hasMigratedToSwiftData"
    
    // Check if migration has already been done
    if UserDefaults.standard.bool(forKey: migrationKey) {
        return
    }
    
    // Migrate transactions
    if let data = UserDefaults.standard.data(forKey: "savedTransactions"),
       let transactions = try? JSONDecoder().decode([Transaction].self, from: data) {
        for transaction in transactions {
            context.insert(SDTransaction.from(transaction))
        }
    }
    
    // Migrate accounts
    if let data = UserDefaults.standard.data(forKey: "savedAccounts"),
       let accounts = try? JSONDecoder().decode([Account].self, from: data) {
        for account in accounts {
            context.insert(SDAccount.from(account))
        }
    }
    
    // Migrate credits
    if let data = UserDefaults.standard.data(forKey: "savedCredits"),
       let credits = try? JSONDecoder().decode([Credit].self, from: data) {
        for credit in credits {
            context.insert(SDCredit.from(credit))
        }
    }
    
    // Migrate contacts
    if let data = UserDefaults.standard.data(forKey: "savedContacts"),
       let contacts = try? JSONDecoder().decode([Contact].self, from: data) {
        for contact in contacts {
            context.insert(SDContact.from(contact))
        }
    }
    
    // Migrate debt transactions
    if let data = UserDefaults.standard.data(forKey: "savedDebtTransactions"),
       let debtTransactions = try? JSONDecoder().decode([DebtTransaction].self, from: data) {
        for debtTransaction in debtTransactions {
            context.insert(SDDebtTransaction.from(debtTransaction))
        }
    }
    
    // Migrate subscriptions
    if let data = UserDefaults.standard.data(forKey: "savedSubscriptions"),
       let subscriptions = try? JSONDecoder().decode([PlannedPayment].self, from: data) {
        for subscription in subscriptions {
            context.insert(SDPlannedPayment.from(subscription))
        }
    }
    
    // Save context and mark migration as complete
    try? context.save()
    UserDefaults.standard.set(true, forKey: migrationKey)
}

@main
struct FinanceFlowApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var settings = AppSettings()
    @StateObject private var transactionManager: TransactionManagerAdapter
    @StateObject private var accountManager: AccountManagerAdapter
    @StateObject private var debtManager: DebtManager
    @StateObject private var creditManager: CreditManager
    @StateObject private var subscriptionManager: SubscriptionManager
    
    let modelContainer: ModelContainer
    
    init() {
        // Create ModelContainer with all SwiftData models
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCredit.self,
            SDContact.self,
            SDDebtTransaction.self,
            SDPlannedPayment.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, try to delete the old database and create a new one
            print("Migration failed: \(error)")
            print("Attempting to delete old database and create a new one...")
            
            // Delete the old database file
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
            
            // Try to create a new container
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after deleting old database: \(error)")
            }
        }
        modelContainer = container
        
        // Get ModelContext immediately
        let context = container.mainContext
        
        // CRITICAL: Migrate data BEFORE creating managers
        // Managers call loadData() in their init, so migration must happen first
        let migrationKey = "hasMigratedToSwiftData"
        let accountIdMigrationKey = "hasMigratedAccountNamesToIds"
        
        // First, migrate from UserDefaults to SwiftData if needed
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            // Migrate transactions
            if let data = UserDefaults.standard.data(forKey: "savedTransactions"),
               let transactions = try? JSONDecoder().decode([Transaction].self, from: data) {
                for transaction in transactions {
                    context.insert(SDTransaction.from(transaction))
                }
            }
            
            // Migrate accounts
            if let data = UserDefaults.standard.data(forKey: "savedAccounts"),
               let accounts = try? JSONDecoder().decode([Account].self, from: data) {
                for account in accounts {
                    context.insert(SDAccount.from(account))
                }
            }
            
            // Migrate credits
            if let data = UserDefaults.standard.data(forKey: "savedCredits"),
               let credits = try? JSONDecoder().decode([Credit].self, from: data) {
                for credit in credits {
                    context.insert(SDCredit.from(credit))
                }
            }
            
            // Migrate contacts
            if let data = UserDefaults.standard.data(forKey: "savedContacts"),
               let contacts = try? JSONDecoder().decode([Contact].self, from: data) {
                for contact in contacts {
                    context.insert(SDContact.from(contact))
                }
            }
            
            // Migrate debt transactions
            if let data = UserDefaults.standard.data(forKey: "savedDebtTransactions"),
               let debtTransactions = try? JSONDecoder().decode([DebtTransaction].self, from: data) {
                for debtTransaction in debtTransactions {
                    context.insert(SDDebtTransaction.from(debtTransaction))
                }
            }
            
            // Migrate subscriptions
            if let data = UserDefaults.standard.data(forKey: "savedSubscriptions"),
               let subscriptions = try? JSONDecoder().decode([PlannedPayment].self, from: data) {
                for subscription in subscriptions {
                    context.insert(SDPlannedPayment.from(subscription))
                }
            }
            
            // Save context and mark migration as complete
            try? context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
        
        // Migrate account names to IDs in SwiftData if needed
        if !UserDefaults.standard.bool(forKey: accountIdMigrationKey) {
            Self.migrateAccountNamesToIds(context: context)
            UserDefaults.standard.set(true, forKey: accountIdMigrationKey)
        }
        
        // Initialize new architecture (Clean Architecture + MVVM + Repository)
        let dependencies = Dependencies(modelContext: context)
        
        // Create ViewModels
        let transactionViewModel = TransactionViewModel(
            transactionRepository: dependencies.transactionRepository,
            accountRepository: dependencies.accountRepository
        )
        
        let accountViewModel = AccountViewModel(
            accountRepository: dependencies.accountRepository,
            transactionRepository: dependencies.transactionRepository
        )
        
        // Create adapters for backward compatibility with existing Views
        let transactionManagerAdapter = TransactionManagerAdapter(viewModel: transactionViewModel)
        let accountManagerAdapter = AccountManagerAdapter(viewModel: accountViewModel)
        
        // Create UseCases for SubscriptionManager
        let deleteTransactionChainUseCase = DeleteTransactionChainUseCase(
            transactionRepository: dependencies.transactionRepository,
            accountRepository: dependencies.accountRepository
        )
        
        let deleteTransactionUseCase = DeleteTransactionUseCase(
            transactionRepository: dependencies.transactionRepository,
            accountRepository: dependencies.accountRepository
        )
        
        // Keep old managers for other features (will be migrated later)
        let debtManager = DebtManager(modelContext: context)
        let creditManager = CreditManager(modelContext: context)
        
        // SubscriptionManager uses Repository and UseCases (Single Source of Truth)
        let subscriptionManager = SubscriptionManager(
            transactionManager: transactionManagerAdapter,
            transactionRepository: dependencies.transactionRepository,
            deleteTransactionChainUseCase: deleteTransactionChainUseCase,
            deleteTransactionUseCase: deleteTransactionUseCase,
            modelContext: context
        )
        
        _transactionManager = StateObject(wrappedValue: transactionManagerAdapter)
        _accountManager = StateObject(wrappedValue: accountManagerAdapter)
        _debtManager = StateObject(wrappedValue: debtManager)
        _creditManager = StateObject(wrappedValue: creditManager)
        _subscriptionManager = StateObject(wrappedValue: subscriptionManager)
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .environmentObject(transactionManager)
                    .environmentObject(accountManager)
                    .environmentObject(debtManager)
                    .environmentObject(creditManager)
                    .environmentObject(subscriptionManager)
                    .environment(\.locale, settings.locale)
                    .modelContainer(modelContainer)
            } else {
                AuthView()
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .environment(\.locale, settings.locale)
                    .modelContainer(modelContainer)
            }
        }
    }
    
    /// Migrate account names to account IDs in SwiftData
    private static func migrateAccountNamesToIds(context: ModelContext) {
        // Load all accounts to create a name-to-ID mapping
        let accountsDescriptor = FetchDescriptor<SDAccount>()
        guard let accounts = try? context.fetch(accountsDescriptor) else { return }
        
        var nameToIdMap: [String: UUID] = [:]
        for account in accounts {
            nameToIdMap[account.name] = account.id
        }
        
        // Migrate transactions
        let transactionsDescriptor = FetchDescriptor<SDTransaction>()
        if let transactions = try? context.fetch(transactionsDescriptor) {
            for transaction in transactions {
                // If accountId is not set but accountName is, migrate it
                if transaction.accountName != nil && nameToIdMap[transaction.accountName!] != nil {
                    transaction.accountId = nameToIdMap[transaction.accountName!]!
                }
                
                // If toAccountId is not set but toAccountName is, migrate it
                if let toAccountName = transaction.toAccountName, let toAccountId = nameToIdMap[toAccountName] {
                    transaction.toAccountId = toAccountId
                }
            }
        }
        
        // Migrate planned payments
        let paymentsDescriptor = FetchDescriptor<SDPlannedPayment>()
        if let payments = try? context.fetch(paymentsDescriptor) {
            // Get first account as fallback
            let firstAccountId = accounts.first?.id
            
            var paymentsToDelete: [SDPlannedPayment] = []
            
            for payment in payments {
                // If accountId is not set, try to migrate from accountName
                if payment.accountId == nil {
                    if let accountName = payment.accountName, let accountId = nameToIdMap[accountName] {
                        payment.accountId = accountId
                    } else if let fallbackId = firstAccountId {
                        // Use first account as fallback if accountName not found
                        payment.accountId = fallbackId
                    } else {
                        // If no account found and no fallback, mark for deletion
                        paymentsToDelete.append(payment)
                        continue
                    }
                }
                
                // If toAccountId is not set but toAccountName is, migrate it
                if payment.toAccountId == nil, let toAccountName = payment.toAccountName, let toAccountId = nameToIdMap[toAccountName] {
                    payment.toAccountId = toAccountId
                }
            }
            
            // Delete payments that couldn't be migrated
            for payment in paymentsToDelete {
                context.delete(payment)
            }
        }
        
        // Migrate credits
        let creditsDescriptor = FetchDescriptor<SDCredit>()
        if let credits = try? context.fetch(creditsDescriptor) {
            for credit in credits {
                // If paymentAccountId is not set but accountName is, migrate it
                if let accountName = credit.accountName, let accountId = nameToIdMap[accountName] {
                    credit.paymentAccountId = accountId
                }
            }
        }
        
        // Save changes
        try? context.save()
    }
}
