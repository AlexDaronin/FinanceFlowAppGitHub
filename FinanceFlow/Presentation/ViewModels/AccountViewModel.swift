//
//  AccountViewModel.swift
//  FinanceFlow
//
//  ViewModel for account management - no data duplication
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for account management
/// Uses UseCases and subscribes to Repository publishers - no data duplication
@MainActor
final class AccountViewModel: ObservableObject {
    // MARK: - Published Properties (UI State only)
    @Published var accounts: [AccountEntity] = []
    @Published var defaultAccountId: UUID?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let accountRepository: AccountRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let createUseCase: CreateAccountUseCase
    private let updateUseCase: UpdateAccountUseCase
    private let deleteUseCase: DeleteAccountUseCase
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        accountRepository: AccountRepositoryProtocol,
        transactionRepository: TransactionRepositoryProtocol
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        
        self.createUseCase = CreateAccountUseCase(accountRepository: accountRepository)
        self.updateUseCase = UpdateAccountUseCase(accountRepository: accountRepository)
        self.deleteUseCase = DeleteAccountUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository
        )
        
        // Subscribe to repository publisher - Single Source of Truth
        accountRepository.accountsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.accounts, on: self)
            .store(in: &cancellables)
        
        // Load initial data
        Task {
            await loadAccounts()
            await loadDefaultAccountId()
        }
    }
    
    // MARK: - Public Methods
    
    func loadAccounts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await accountRepository.getAllAccounts()
            // Data will be updated via publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadDefaultAccountId() async {
        do {
            defaultAccountId = try await accountRepository.getDefaultAccountId()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createAccount(_ account: AccountEntity) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await createUseCase.execute(account)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateAccount(_ account: AccountEntity) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await updateUseCase.execute(account)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteAccount(id: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await deleteUseCase.execute(id: id)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func getAccount(id: UUID) async -> AccountEntity? {
        do {
            return try await accountRepository.getAccount(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func setDefaultAccount(_ accountId: UUID?) async {
        do {
            try await accountRepository.setDefaultAccountId(accountId)
            defaultAccountId = accountId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Computed Properties for UI
    
    var defaultAccount: AccountEntity? {
        guard let defaultId = defaultAccountId else {
            return accounts.first
        }
        return accounts.first { $0.id == defaultId } ?? accounts.first
    }
    
    var pinnedAccounts: [AccountEntity] {
        accounts.filter { $0.isPinned }
            .sorted { $0.name < $1.name }
    }
    
    var unpinnedAccounts: [AccountEntity] {
        accounts.filter { !$0.isPinned }
            .sorted { $0.name < $1.name }
    }
    
    var totalBalance: Double {
        accounts
            .filter { $0.includedInTotal }
            .map { $0.balance }
            .reduce(0, +)
    }
}


