//
//  CreditManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class CreditManager: ObservableObject {
    @Published var credits: [Credit] = []
    
    private let creditsKey = "savedCredits"
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadData()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
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
    
    func deleteCredit(_ credit: Credit, accountManager: AccountManagerAdapter? = nil, subscriptionManager: SubscriptionManager? = nil) {
        // Delete linked subscription if it exists
        if let subscriptionManager = subscriptionManager,
           let subscription = subscriptionManager.subscriptions.first(where: { $0.linkedCreditId == credit.id }) {
            subscriptionManager.deleteSubscription(subscription)
        }
        
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
    /// NOTE: Account balance should be updated ONLY through transactions (via UseCases)
    /// This method only updates credit internal state, not account balance
    func updateCreditBalance(creditId: UUID, paymentAmount: Double, accountManager: AccountManagerAdapter? = nil) {
        guard let index = credits.firstIndex(where: { $0.id == creditId }) else { return }
        
        var credit = credits[index]
        credit.remaining = max(0, credit.remaining - paymentAmount)
        credit.paid = credit.totalAmount - credit.remaining
        
        // REMOVED: Direct account balance modification
        // Account balance MUST be updated only through transactions (via UseCases)
        // If a transaction was created for this payment, the balance is already updated correctly
        
        credits[index] = credit
        saveData()
        // BUG FIX 3: @Published automatically triggers UI updates
    }
    
    /// Sync credit balance from linked account (used for transfers where TransactionManager updates account first)
    func syncCreditFromAccount(creditId: UUID, accountManager: AccountManagerAdapter) {
        guard let index = credits.firstIndex(where: { $0.id == creditId }),
              let linkedAccountId = credits[index].linkedAccountId,
              let linkedAccount = accountManager.getAccount(id: linkedAccountId) else { return }
        
        var credit = credits[index]
        // Account balance is negative (debt), so remaining = abs(balance)
        credit.remaining = abs(linkedAccount.balance)
        credit.paid = credit.totalAmount - credit.remaining
        
        credits[index] = credit
        saveData()
        // BUG FIX 3: @Published automatically triggers UI updates
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
    
    // MARK: - Reset
    
    func reset() {
        credits = []
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<SDCredit>()
            if let sdCredits = try? modelContext.fetch(descriptor) {
                for sdCredit in sdCredits {
                    modelContext.delete(sdCredit)
                }
                try? modelContext.save()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: creditsKey)
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let encoded = try? JSONEncoder().encode(credits) {
                UserDefaults.standard.set(encoded, forKey: creditsKey)
            }
            return
        }
        
        // Get all existing SDCredits
        let descriptor = FetchDescriptor<SDCredit>()
        guard let existingSDCredits = try? modelContext.fetch(descriptor) else { return }
        
        // Create a map of existing credits by ID
        var existingMap: [UUID: SDCredit] = [:]
        for sdCredit in existingSDCredits {
            existingMap[sdCredit.id] = sdCredit
        }
        
        // Update or create SDCredits
        for credit in credits {
            if let existing = existingMap[credit.id] {
                // Update existing
                existing.title = credit.title
                existing.totalAmount = credit.totalAmount
                existing.remaining = credit.remaining
                existing.paid = credit.paid
                existing.monthsLeft = credit.monthsLeft
                existing.dueDate = credit.dueDate
                existing.monthlyPayment = credit.monthlyPayment
                existing.interestRate = credit.interestRate
                existing.startDate = credit.startDate
                existing.paymentAccountId = credit.paymentAccountId
                existing.termMonths = credit.termMonths
                existing.linkedAccountId = credit.linkedAccountId
            } else {
                // Create new
                modelContext.insert(SDCredit.from(credit))
            }
        }
        
        // Delete SDCredits that are no longer in credits array
        let creditIds = Set(credits.map { $0.id })
        for sdCredit in existingSDCredits {
            if !creditIds.contains(sdCredit.id) {
                modelContext.delete(sdCredit)
            }
        }
        
        try? modelContext.save()
    }
    
    private func loadData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let data = UserDefaults.standard.data(forKey: creditsKey),
               let decoded = try? JSONDecoder().decode([Credit].self, from: data) {
                credits = decoded
            }
            return
        }
        
        let descriptor = FetchDescriptor<SDCredit>()
        
        if let sdCredits = try? modelContext.fetch(descriptor) {
            credits = sdCredits.map { $0.toCredit() }
        }
    }
}



