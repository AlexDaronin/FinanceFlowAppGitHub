//
//  CreditManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class CreditManager: ObservableObject {
    @Published var credits: [Credit] = []
    
    private let creditsKey = "savedCredits"
    
    init() {
        loadData()
    }
    
    // MARK: - Credit Management
    
    func addCredit(_ credit: Credit) {
        credits.append(credit)
        saveData()
    }
    
    func updateCredit(_ credit: Credit) {
        if let index = credits.firstIndex(where: { $0.id == credit.id }) {
            credits[index] = credit
            saveData()
        }
    }
    
    func deleteCredit(_ credit: Credit, accountManager: AccountManager? = nil) {
        // Delete linked account if it exists
        if let linkedAccountId = credit.linkedAccountId,
           let accountManager = accountManager {
            accountManager.deleteAccount(linkedAccountId)
        }
        
        credits.removeAll { $0.id == credit.id }
        saveData()
    }
    
    func getCredit(id: UUID) -> Credit? {
        credits.first { $0.id == id }
    }
    
    // MARK: - Credit Balance Updates
    
    /// Update credit balance when a payment is made
    func updateCreditBalance(creditId: UUID, paymentAmount: Double, accountManager: AccountManager? = nil) {
        guard let index = credits.firstIndex(where: { $0.id == creditId }) else { return }
        
        var credit = credits[index]
        credit.remaining = max(0, credit.remaining - paymentAmount)
        credit.paid = credit.totalAmount - credit.remaining
        
        // Update linked account balance if it exists
        if let linkedAccountId = credit.linkedAccountId,
           let accountManager = accountManager,
           var linkedAccount = accountManager.getAccount(id: linkedAccountId) {
            // For credit accounts, adding money reduces the debt (negative balance becomes less negative)
            linkedAccount.balance += paymentAmount
            accountManager.updateAccount(linkedAccount)
        }
        
        credits[index] = credit
        saveData()
        objectWillChange.send()
    }
    
    /// Sync credit balance from linked account (used for transfers where TransactionManager updates account first)
    func syncCreditFromAccount(creditId: UUID, accountManager: AccountManager) {
        guard let index = credits.firstIndex(where: { $0.id == creditId }),
              let linkedAccountId = credits[index].linkedAccountId,
              let linkedAccount = accountManager.getAccount(id: linkedAccountId) else { return }
        
        var credit = credits[index]
        // Account balance is negative (debt), so remaining = abs(balance)
        credit.remaining = abs(linkedAccount.balance)
        credit.paid = credit.totalAmount - credit.remaining
        
        credits[index] = credit
        saveData()
        objectWillChange.send()
    }
    
    // MARK: - Computed Properties
    
    var totalRemaining: Double {
        credits.map(\.remaining).reduce(0, +)
    }
    
    var nextDueDate: Date? {
        credits
            .filter { $0.remaining > 0 }
            .map(\.dueDate)
            .min()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(credits) {
            UserDefaults.standard.set(encoded, forKey: creditsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: creditsKey),
           let decoded = try? JSONDecoder().decode([Credit].self, from: data) {
            credits = decoded
        }
    }
}

