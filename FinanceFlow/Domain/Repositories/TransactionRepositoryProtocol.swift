//
//  TransactionRepositoryProtocol.swift
//  FinanceFlow
//
//  Repository protocol for Transaction data access
//

import Foundation
import Combine

/// Protocol defining transaction data operations
/// Single Source of Truth for transactions
protocol TransactionRepositoryProtocol {
    /// Get all transactions
    func getAllTransactions() async throws -> [TransactionEntity]
    
    /// Get transactions with filters
    func getTransactions(
        accountId: UUID?,
        fromDate: Date?,
        toDate: Date?,
        type: TransactionType?,
        limit: Int?
    ) async throws -> [TransactionEntity]
    
    /// Get transaction by ID
    func getTransaction(id: UUID) async throws -> TransactionEntity?
    
    /// Create new transaction
    func createTransaction(_ transaction: TransactionEntity) async throws
    
    /// Update existing transaction
    func updateTransaction(_ transaction: TransactionEntity) async throws
    
    /// Delete transaction
    func deleteTransaction(id: UUID) async throws
    
    /// Delete multiple transactions
    func deleteTransactions(ids: [UUID]) async throws
    
    /// Get transactions count
    func getTransactionsCount() async throws -> Int
    
    /// Check if transaction exists by sourceId and date (for idempotent generation)
    func transactionExists(sourceId: UUID, date: Date) async throws -> Bool
    
    /// Get all transactions by sourceId (for subscriptions, credits, debts)
    func fetchTransactions(sourceId: UUID) async throws -> [TransactionEntity]
    
    /// Delete all transactions by sourceId (atomic operation)
    func deleteTransactions(sourceId: UUID) async throws
    
    /// Publisher for transaction changes (reactive updates)
    var transactionsPublisher: AnyPublisher<[TransactionEntity], Never> { get }
}


