//
//  AccountUseCases.swift
//  FinanceFlow
//
//  Business logic for account operations
//

import Foundation

// TransactionType is defined in Models/Transaction.swift

/// Use case for creating an account
final class CreateAccountUseCase {
    private let accountRepository: AccountRepositoryProtocol
    
    init(accountRepository: AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
    }
    
    func execute(_ account: AccountEntity) async throws {
        try await accountRepository.createAccount(account)
    }
}

/// Use case for updating an account
final class UpdateAccountUseCase {
    private let accountRepository: AccountRepositoryProtocol
    
    init(accountRepository: AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
    }
    
    func execute(_ account: AccountEntity) async throws {
        try await accountRepository.updateAccount(account)
    }
}

/// Use case for deleting an account with validation
final class DeleteAccountUseCase {
    private let accountRepository: AccountRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    
    init(
        accountRepository: AccountRepositoryProtocol,
        transactionRepository: TransactionRepositoryProtocol
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }
    
    func execute(id: UUID) async throws {
        // Check if account has transactions
        let transactions = try await transactionRepository.getTransactions(
            accountId: id,
            fromDate: nil as Date?,
            toDate: nil as Date?,
            type: nil as TransactionType?,
            limit: nil as Int?
        )
        
        if !transactions.isEmpty {
            throw AccountError.accountHasTransactions
        }
        
        // Check if it's the default account
        if let defaultId = try await accountRepository.getDefaultAccountId(),
           defaultId == id {
            try await accountRepository.setDefaultAccountId(nil)
        }
        
        // Delete account
        try await accountRepository.deleteAccount(id: id)
    }
}

// MARK: - Account Errors
enum AccountError: LocalizedError {
    case accountNotFound
    case accountHasTransactions
    
    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Account not found"
        case .accountHasTransactions:
            return "Cannot delete account with existing transactions"
        }
    }
}


