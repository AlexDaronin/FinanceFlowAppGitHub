//
//  TransactionManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    private let transactionsKey = "savedTransactions"
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadData()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        saveData()
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            saveData()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveData()
    }
    
    func getTransaction(id: UUID) -> Transaction? {
        transactions.first { $0.id == id }
    }
    
    // MARK: - Reset
    
    func reset() {
        transactions = []
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<SDTransaction>()
            if let sdTransactions = try? modelContext.fetch(descriptor) {
                for sdTransaction in sdTransactions {
                    modelContext.delete(sdTransaction)
                }
                try? modelContext.save()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: transactionsKey)
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let encoded = try? JSONEncoder().encode(transactions) {
                UserDefaults.standard.set(encoded, forKey: transactionsKey)
            }
            return
        }
        
        // Get all existing SDTransactions
        let descriptor = FetchDescriptor<SDTransaction>()
        guard let existingSDTransactions = try? modelContext.fetch(descriptor) else { return }
        
        // Create a map of existing transactions by ID
        var existingMap: [UUID: SDTransaction] = [:]
        for sdTransaction in existingSDTransactions {
            existingMap[sdTransaction.id] = sdTransaction
        }
        
        // Update or create SDTransactions
        for transaction in transactions {
            if let existing = existingMap[transaction.id] {
                // Update existing
                existing.title = transaction.title
                existing.category = transaction.category
                existing.amount = transaction.amount
                existing.date = transaction.date
                existing.type = transaction.type.rawValue
                existing.accountId = transaction.accountId
                existing.toAccountId = transaction.toAccountId
                existing.currency = transaction.currency
                existing.sourcePlannedPaymentId = transaction.sourcePlannedPaymentId
                existing.occurrenceDate = transaction.occurrenceDate
            } else {
                // Create new
                modelContext.insert(SDTransaction.from(transaction))
            }
        }
        
        // Delete SDTransactions that are no longer in transactions array
        let transactionIds = Set(transactions.map { $0.id })
        for sdTransaction in existingSDTransactions {
            if !transactionIds.contains(sdTransaction.id) {
                modelContext.delete(sdTransaction)
            }
        }
        
        try? modelContext.save()
    }
    
    private func loadData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let data = UserDefaults.standard.data(forKey: transactionsKey),
               let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
                transactions = decoded
            }
            return
        }
        
        let descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        if let sdTransactions = try? modelContext.fetch(descriptor) {
            transactions = sdTransactions.map { $0.toTransaction() }
        }
    }
}

