//
//  AccountManagerAdapter.swift
//  FinanceFlow
//
//  Adapter to bridge old AccountManager interface with new architecture
//  This allows gradual migration without breaking existing Views
//

import Foundation
import SwiftUI
import Combine

/// Adapter that wraps new architecture (Repository + UseCases)
/// but provides old AccountManager interface for compatibility
final class AccountManagerAdapter: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var defaultAccountId: UUID? {
        didSet {
            Task { @MainActor in
                await viewModel.setDefaultAccount(defaultAccountId)
            }
        }
    }
    
    private let viewModel: AccountViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: AccountViewModel) {
        self.viewModel = viewModel
        
        // Convert AccountEntity to Account and publish
        viewModel.$accounts
            .map { entities in
                entities.map { entity in
                    Account(
                        id: entity.id,
                        name: entity.name,
                        balance: entity.balance,
                        includedInTotal: entity.includedInTotal,
                        accountType: entity.accountType,
                        currency: entity.currency,
                        isPinned: entity.isPinned,
                        isSavings: entity.isSavings,
                        iconName: entity.iconName
                    )
                }
            }
            .assign(to: \.accounts, on: self)
            .store(in: &cancellables)
        
        // Sync defaultAccountId
        viewModel.$defaultAccountId
            .assign(to: \.defaultAccountId, on: self)
            .store(in: &cancellables)
    }
    
    func addAccount(_ account: Account) {
        Task { @MainActor in
            let entity = AccountEntity(
                id: account.id,
                name: account.name,
                balance: account.balance,
                includedInTotal: account.includedInTotal,
                accountType: account.accountType,
                currency: account.currency,
                isPinned: account.isPinned,
                isSavings: account.isSavings,
                iconName: account.iconName
            )
            await viewModel.createAccount(entity)
        }
    }
    
    func updateAccount(_ account: Account, transactionManager: TransactionManagerAdapter? = nil) {
        Task { @MainActor in
            let entity = AccountEntity(
                id: account.id,
                name: account.name,
                balance: account.balance,
                includedInTotal: account.includedInTotal,
                accountType: account.accountType,
                currency: account.currency,
                isPinned: account.isPinned,
                isSavings: account.isSavings,
                iconName: account.iconName
            )
            await viewModel.updateAccount(entity)
        }
    }
    
    func deleteAccount(_ accountId: UUID) {
        Task { @MainActor in
            await viewModel.deleteAccount(id: accountId)
        }
    }
    
    func reorder(from sourceIndex: Int, to destinationIndex: Int) {
        // Reordering logic - can be implemented if needed
        // For now, accounts are sorted by pinned status and name
    }
    
    func getAccount(id: UUID) -> Account? {
        return accounts.first { $0.id == id }
    }
    
    func getAccount(name: String) -> Account? {
        return accounts.first { $0.name == name }
    }
    
    func getDefaultAccount() -> Account? {
        if let defaultId = defaultAccountId,
           let account = getAccount(id: defaultId) {
            return account
        }
        return accounts.first
    }
    
    func getDefaultAccountId() -> UUID? {
        if let defaultId = defaultAccountId,
           getAccount(id: defaultId) != nil {
            return defaultId
        }
        return accounts.first?.id
    }
    
    func setDefaultAccount(_ accountId: UUID?) {
        defaultAccountId = accountId
    }
    
    func reset() {
        // Not implemented in new architecture
    }
}


