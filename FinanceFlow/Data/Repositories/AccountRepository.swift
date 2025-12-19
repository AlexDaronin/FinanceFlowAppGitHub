//
//  AccountRepository.swift
//  FinanceFlow
//
//  SwiftData implementation of AccountRepositoryProtocol
//

import Foundation
import SwiftData
import Combine

/// SwiftData implementation of AccountRepositoryProtocol
/// Single Source of Truth for accounts - no duplication
final class AccountRepository: AccountRepositoryProtocol {
    private let modelContext: ModelContext
    private let accountsSubject = CurrentValueSubject<[AccountEntity], Never>([])
    private let defaultAccountIdKey = "defaultAccountId"
    
    var accountsPublisher: AnyPublisher<[AccountEntity], Never> {
        accountsSubject.eraseToAnyPublisher()
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Repository Implementation
    
    func getAllAccounts() async throws -> [AccountEntity] {
        let descriptor = FetchDescriptor<SDAccount>()
        let sdAccounts = try modelContext.fetch(descriptor)
        let entities = sdAccounts.map { $0.toEntity() }
        
        await MainActor.run {
            accountsSubject.send(entities)
        }
        
        return entities
    }
    
    func getAccount(id: UUID) async throws -> AccountEntity? {
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate<SDAccount> { $0.id == id }
        )
        
        guard let sdAccount = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return sdAccount.toEntity()
    }
    
    func createAccount(_ account: AccountEntity) async throws {
        let sdAccount = SDAccount.from(account)
        modelContext.insert(sdAccount)
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func updateAccount(_ account: AccountEntity) async throws {
        let accountId = account.id
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate<SDAccount> { $0.id == accountId }
        )
        
        guard let sdAccount = try modelContext.fetch(descriptor).first else {
            throw AccountError.accountNotFound
        }
        
        // Update properties
        sdAccount.name = account.name
        sdAccount.balance = account.balance
        sdAccount.includedInTotal = account.includedInTotal
        sdAccount.accountType = account.accountType.rawValue
        sdAccount.currency = account.currency
        sdAccount.isPinned = account.isPinned
        sdAccount.isSavings = account.isSavings
        sdAccount.iconName = account.iconName
        
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func deleteAccount(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate<SDAccount> { $0.id == id }
        )
        
        guard let sdAccount = try modelContext.fetch(descriptor).first else {
            throw AccountError.accountNotFound
        }
        
        modelContext.delete(sdAccount)
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func getDefaultAccountId() async throws -> UUID? {
        if let uuidString = UserDefaults.standard.string(forKey: defaultAccountIdKey),
           let accountId = UUID(uuidString: uuidString) {
            // Validate that account still exists
            if try await getAccount(id: accountId) != nil {
                return accountId
            } else {
                // Account doesn't exist, clear default
                try await setDefaultAccountId(nil)
                return nil
            }
        }
        return nil
    }
    
    func setDefaultAccountId(_ id: UUID?) async throws {
        if let id = id {
            // Validate account exists
            guard try await getAccount(id: id) != nil else {
                throw AccountError.accountNotFound
            }
            UserDefaults.standard.set(id.uuidString, forKey: defaultAccountIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultAccountIdKey)
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadInitialData() async {
        do {
            let accounts = try await getAllAccounts()
            await MainActor.run {
                accountsSubject.send(accounts)
            }
        } catch {
            print("Error loading initial accounts: \(error)")
        }
    }
    
    private func refreshPublisher() async {
        do {
            let accounts = try await getAllAccounts()
            await MainActor.run {
                accountsSubject.send(accounts)
            }
        } catch {
            print("Error refreshing accounts: \(error)")
        }
    }
}

// MARK: - SwiftData Model Extension
extension SDAccount {
    func toEntity() -> AccountEntity {
        AccountEntity(
            id: id,
            name: name,
            balance: balance,
            includedInTotal: includedInTotal,
            accountType: AccountType(rawValue: accountType) ?? .card,
            currency: currency,
            isPinned: isPinned,
            isSavings: isSavings,
            iconName: iconName
        )
    }
    
    static func from(_ entity: AccountEntity) -> SDAccount {
        SDAccount(
            id: entity.id,
            name: entity.name,
            balance: entity.balance,
            includedInTotal: entity.includedInTotal,
            accountType: entity.accountType.rawValue,
            currency: entity.currency,
            isPinned: entity.isPinned,
            isSavings: entity.isSavings,
            iconName: entity.iconName
        )
    }
}


