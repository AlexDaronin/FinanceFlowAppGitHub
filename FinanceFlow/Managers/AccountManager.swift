//
//  AccountManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class AccountManager: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var defaultAccountId: UUID? {
        didSet {
            saveDefaultAccountId()
        }
    }
    
    private let accountsKey = "savedAccounts"
    private let defaultAccountIdKey = "defaultAccountId"
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadData()
        loadDefaultAccountId()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
        loadDefaultAccountId()
    }
    
    // MARK: - Account Management
    
    func addAccount(_ account: Account) {
        accounts.append(account)
        saveData()
    }
    
    func updateAccount(_ account: Account, transactionManager: TransactionManager? = nil) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            // Update the account
            accounts[index] = account
            saveData()
            
            // No need to update transactions anymore - they use accountId, not accountName
            // Transactions will automatically show the new name when displayed
        }
    }
    
    func deleteAccount(_ accountId: UUID) {
        accounts.removeAll { $0.id == accountId }
        // If deleted account was the default, clear default
        if defaultAccountId == accountId {
            defaultAccountId = nil
        }
        saveData()
    }
    
    /// Reorder accounts array using source/destination indices.
    /// Keeps pinned and non-pinned groups separated by ignoring cross-group moves.
    func reorder(from sourceIndex: Int, to destinationIndex: Int) {
        guard accounts.indices.contains(sourceIndex) else { return }
        
        // Clamp destination into valid bounds
        let clampedDestination = max(0, min(destinationIndex, accounts.count - 1))
        
        let sourcePinned = accounts[sourceIndex].isPinned
        let destinationPinned = accounts[clampedDestination].isPinned
        
        // Disallow moving between pinned/non-pinned groups
        guard sourcePinned == destinationPinned else { return }
        
        // Adjust insert index because removing shifts indices
        let account = accounts.remove(at: sourceIndex)
        let adjustedDestination = sourceIndex < clampedDestination ? clampedDestination - 1 : clampedDestination
        
        accounts.insert(account, at: adjustedDestination)
        saveData()
    }
    
    func getAccount(id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }
    
    func getAccount(name: String) -> Account? {
        accounts.first { $0.name == name }
    }
    
    // MARK: - Default Account Management
    
    /// Get the default account, or first available account if default is not set or doesn't exist
    func getDefaultAccount() -> Account? {
        if let defaultId = defaultAccountId,
           let account = getAccount(id: defaultId) {
            return account
        }
        return accounts.first
    }
    
    /// Get the default account ID, or first available account ID if default is not set or doesn't exist
    func getDefaultAccountId() -> UUID? {
        if let defaultId = defaultAccountId,
           getAccount(id: defaultId) != nil {
            return defaultId
        }
        return accounts.first?.id
    }
    
    /// Set the default account
    func setDefaultAccount(_ accountId: UUID?) {
        // Validate that the account exists
        if let accountId = accountId,
           getAccount(id: accountId) == nil {
            return
        }
        defaultAccountId = accountId
    }
    
    // MARK: - Reset
    
    func reset() {
        accounts = []
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<SDAccount>()
            if let sdAccounts = try? modelContext.fetch(descriptor) {
                for sdAccount in sdAccounts {
                    modelContext.delete(sdAccount)
                }
                try? modelContext.save()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: accountsKey)
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let encoded = try? JSONEncoder().encode(accounts) {
                UserDefaults.standard.set(encoded, forKey: accountsKey)
            }
            return
        }
        
        // Get all existing SDAccounts
        let descriptor = FetchDescriptor<SDAccount>()
        guard let existingSDAccounts = try? modelContext.fetch(descriptor) else { return }
        
        // Create a map of existing accounts by ID
        var existingMap: [UUID: SDAccount] = [:]
        for sdAccount in existingSDAccounts {
            existingMap[sdAccount.id] = sdAccount
        }
        
        // Update or create SDAccounts
        for account in accounts {
            if let existing = existingMap[account.id] {
                // Update existing
                existing.name = account.name
                existing.balance = account.balance
                existing.includedInTotal = account.includedInTotal
                existing.accountType = account.accountType.rawValue
                existing.currency = account.currency
                existing.isPinned = account.isPinned
                existing.isSavings = account.isSavings
                existing.iconName = account.iconName
            } else {
                // Create new
                modelContext.insert(SDAccount.from(account))
            }
        }
        
        // Delete SDAccounts that are no longer in accounts array
        let accountIds = Set(accounts.map { $0.id })
        for sdAccount in existingSDAccounts {
            if !accountIds.contains(sdAccount.id) {
                modelContext.delete(sdAccount)
            }
        }
        
        try? modelContext.save()
    }
    
    private func loadData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let data = UserDefaults.standard.data(forKey: accountsKey),
               let decoded = try? JSONDecoder().decode([Account].self, from: data) {
                accounts = decoded
            }
            return
        }
        
        let descriptor = FetchDescriptor<SDAccount>()
        
        if let sdAccounts = try? modelContext.fetch(descriptor) {
            accounts = sdAccounts.map { $0.toAccount() }
        }
    }
    
    // MARK: - Default Account Persistence
    
    private func saveDefaultAccountId() {
        if let accountId = defaultAccountId {
            UserDefaults.standard.set(accountId.uuidString, forKey: defaultAccountIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultAccountIdKey)
        }
    }
    
    private func loadDefaultAccountId() {
        if let uuidString = UserDefaults.standard.string(forKey: defaultAccountIdKey),
           let accountId = UUID(uuidString: uuidString) {
            // Validate that the account still exists
            if getAccount(id: accountId) != nil {
                defaultAccountId = accountId
            } else {
                defaultAccountId = nil
            }
        } else {
            defaultAccountId = nil
        }
    }
}




