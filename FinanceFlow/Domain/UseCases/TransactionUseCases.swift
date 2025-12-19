//
//  TransactionUseCases.swift
//  FinanceFlow
//
//  Business logic for transaction operations
//

import Foundation

/// Use case for creating a transaction with account balance updates
final class CreateTransactionUseCase {
    private let transactionRepository: TransactionRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        accountRepository: AccountRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }
    
    func execute(_ transaction: TransactionEntity) async throws {
        // Create transaction
        try await transactionRepository.createTransaction(transaction)
        
        // Update account balances
        try await updateAccountBalances(for: transaction)
    }
    
    private func updateAccountBalances(for transaction: TransactionEntity) async throws {
        switch transaction.type {
        case .income:
            // Add to account balance
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .expense:
            // Subtract from account balance
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .transfer:
            // Transfer between accounts
            guard let toAccountId = transaction.toAccountId else {
                throw TransactionError.invalidTransfer
            }
            
            // Subtract from source account
            if let fromAccount = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedFromAccount = fromAccount
                updatedFromAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedFromAccount)
            }
            
            // Add to destination account
            if let toAccount = try await accountRepository.getAccount(id: toAccountId) {
                var updatedToAccount = toAccount
                updatedToAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedToAccount)
            }
            
        case .debt:
            // Debt transactions don't affect account balance directly
            // (handled separately in debt management)
            break
        }
    }
}

/// Use case for updating a transaction with account balance recalculation
final class UpdateTransactionUseCase {
    private let transactionRepository: TransactionRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        accountRepository: AccountRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }
    
    func execute(_ transaction: TransactionEntity) async throws {
        // Get old transaction to reverse its effects
        guard let oldTransaction = try await transactionRepository.getTransaction(id: transaction.id) else {
            throw TransactionError.transactionNotFound
        }
        
        // Reverse old transaction effects
        try await reverseTransactionEffects(oldTransaction)
        
        // Update transaction
        try await transactionRepository.updateTransaction(transaction)
        
        // Apply new transaction effects
        try await applyTransactionEffects(transaction)
    }
    
    private func reverseTransactionEffects(_ transaction: TransactionEntity) async throws {
        switch transaction.type {
        case .income:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .expense:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .transfer:
            guard let toAccountId = transaction.toAccountId else { return }
            
            // Reverse: add back to source, subtract from destination
            if let fromAccount = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedFromAccount = fromAccount
                updatedFromAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedFromAccount)
            }
            
            if let toAccount = try await accountRepository.getAccount(id: toAccountId) {
                var updatedToAccount = toAccount
                updatedToAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedToAccount)
            }
            
        case .debt:
            break
        }
    }
    
    private func applyTransactionEffects(_ transaction: TransactionEntity) async throws {
        switch transaction.type {
        case .income:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .expense:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .transfer:
            guard let toAccountId = transaction.toAccountId else { return }
            
            if let fromAccount = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedFromAccount = fromAccount
                updatedFromAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedFromAccount)
            }
            
            if let toAccount = try await accountRepository.getAccount(id: toAccountId) {
                var updatedToAccount = toAccount
                updatedToAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedToAccount)
            }
            
        case .debt:
            break
        }
    }
}

/// Use case for deleting a transaction with account balance updates
final class DeleteTransactionUseCase {
    private let transactionRepository: TransactionRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        accountRepository: AccountRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }
    
    func execute(id: UUID) async throws {
        // Get transaction to reverse its effects
        guard let transaction = try await transactionRepository.getTransaction(id: id) else {
            throw TransactionError.transactionNotFound
        }
        
        // Reverse transaction effects on accounts
        try await reverseTransactionEffects(transaction)
        
        // Delete transaction
        try await transactionRepository.deleteTransaction(id: id)
    }
    
    private func reverseTransactionEffects(_ transaction: TransactionEntity) async throws {
        switch transaction.type {
        case .income:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .expense:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .transfer:
            guard let toAccountId = transaction.toAccountId else { return }
            
            // Reverse: add back to source, subtract from destination
            if let fromAccount = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedFromAccount = fromAccount
                updatedFromAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedFromAccount)
            }
            
            if let toAccount = try await accountRepository.getAccount(id: toAccountId) {
                var updatedToAccount = toAccount
                updatedToAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedToAccount)
            }
            
        case .debt:
            break
        }
    }
}

/// Use case for deleting a chain of transactions by sourceId (atomic operation)
/// Ensures all balance rollbacks happen before deletion
final class DeleteTransactionChainUseCase {
    private let transactionRepository: TransactionRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        accountRepository: AccountRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }
    
    /// Delete all transactions for a given sourceId (subscription, credit, debt)
    /// First reverses all balance effects, then deletes all transactions atomically
    func execute(sourceId: UUID) async throws {
        // Fetch all transactions for this sourceId from Repository (Single Source of Truth)
        let transactions = try await transactionRepository.fetchTransactions(sourceId: sourceId)
        
        guard !transactions.isEmpty else {
            // No transactions to delete - this is fine, just return
            return
        }
        
        // Reverse balance effects for each transaction (in reverse order for safety)
        // This ensures balances are correctly rolled back before deletion
        for transaction in transactions.reversed() {
            try await reverseTransactionEffects(transaction)
        }
        
        // Delete all transactions atomically through Repository
        try await transactionRepository.deleteTransactions(sourceId: sourceId)
    }
    
    private func reverseTransactionEffects(_ transaction: TransactionEntity) async throws {
        switch transaction.type {
        case .income:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .expense:
            if let account = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedAccount = account
                updatedAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedAccount)
            }
            
        case .transfer:
            guard let toAccountId = transaction.toAccountId else { return }
            
            // Reverse: add back to source, subtract from destination
            if let fromAccount = try await accountRepository.getAccount(id: transaction.accountId) {
                var updatedFromAccount = fromAccount
                updatedFromAccount.balance += transaction.amount
                try await accountRepository.updateAccount(updatedFromAccount)
            }
            
            if let toAccount = try await accountRepository.getAccount(id: toAccountId) {
                var updatedToAccount = toAccount
                updatedToAccount.balance -= transaction.amount
                try await accountRepository.updateAccount(updatedToAccount)
            }
            
        case .debt:
            break
        }
    }
}

// MARK: - Transaction Errors
enum TransactionError: LocalizedError {
    case transactionNotFound
    case invalidTransfer
    case accountNotFound
    
    var errorDescription: String? {
        switch self {
        case .transactionNotFound:
            return "Transaction not found"
        case .invalidTransfer:
            return "Invalid transfer: destination account required"
        case .accountNotFound:
            return "Account not found"
        }
    }
}


