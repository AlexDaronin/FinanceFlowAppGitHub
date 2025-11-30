//
//  TransactionManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    private let transactionsKey = "savedTransactions"
    
    init() {
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
    
    /// ONE-TIME CLEANUP: Delete ALL old subscription transactions from TransactionManager
    /// Scheduled transactions should ONLY exist in SubscriptionManager.upcomingTransactions
    func cleanupAllSubscriptionTransactions(subscriptionManager: SubscriptionManager) {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        // Get all scheduled transaction IDs from SubscriptionManager (the single source of truth)
        let scheduledTransactionIds = Set(subscriptionManager.upcomingTransactions.map { $0.id })
        
        // Get all subscription titles (for matching old transactions)
        let subscriptionTitles = Set(subscriptionManager.subscriptions.map { $0.title })
        
        // Remove ALL transactions that:
        // 1. Have sourcePlannedPaymentId (should only be in SubscriptionManager)
        // 2. Are in upcomingTransactions (duplicates)
        // 3. Are future transactions matching any subscription pattern
        let toRemove = transactions.filter { transaction in
            let isFuture = calendar.startOfDay(for: transaction.date) > todayStart
            
            // Remove if it's a scheduled transaction
            if transaction.sourcePlannedPaymentId != nil {
                return true
            }
            
            // Remove if it's in the scheduled list
            if scheduledTransactionIds.contains(transaction.id) {
                return true
            }
            
            // Remove future transactions that match subscriptions
            if isFuture {
                // Exact match
                if subscriptionManager.subscriptions.contains(where: { sub in
                    sub.isRepeating &&
                    transaction.title == sub.title &&
                    abs(transaction.amount - sub.amount) < 0.01 &&
                    transaction.accountName == sub.accountName &&
                    transaction.type == (sub.isIncome ? .income : .expense)
                }) {
                    return true
                }
                
                // Title match (catches old subscriptions)
                if subscriptionTitles.contains(transaction.title) {
                    return true
                }
            }
            
            return false
        }
        
        // Remove all identified transactions
        if !toRemove.isEmpty {
            transactions.removeAll { transaction in
                toRemove.contains { $0.id == transaction.id }
            }
            saveData()
            objectWillChange.send()
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: transactionsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactions = decoded
        }
    }
}

