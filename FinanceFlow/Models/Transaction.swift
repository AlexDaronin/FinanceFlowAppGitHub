//
//  Transaction.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let accountId: UUID // Changed from accountName to accountId
    let toAccountId: UUID? // Changed from toAccountName to toAccountId
    let currency: String
    
    // ISSUE 2 FIX: Optional fields for scheduled repeating payments
    // These allow generated occurrences to reference their source PlannedPayment
    let sourcePlannedPaymentId: UUID? // The ID of the PlannedPayment that generated this occurrence
    let occurrenceDate: Date? // The specific date of this occurrence (same as date, but stored for clarity)
    
    init(id: UUID = UUID(), title: String, category: String, amount: Double, date: Date, type: TransactionType, accountId: UUID, toAccountId: UUID? = nil, currency: String = "USD", sourcePlannedPaymentId: UUID? = nil, occurrenceDate: Date? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
        self.type = type
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.currency = currency
        self.sourcePlannedPaymentId = sourcePlannedPaymentId
        self.occurrenceDate = occurrenceDate ?? date // Default to date if not provided
    }
    
    
    func displayAmount(currencyCode: String? = nil) -> String {
        let code = currencyCode ?? currency
        let value = currencyString(abs(amount), code: code)
        switch type {
        case .income:
            return "+\(value)"
        case .expense:
            return "-\(value)"
        case .transfer:
            return value
        case .debt:
            return value
        }
    }
    
    static func sample(accountIds: [UUID] = [UUID(), UUID(), UUID()]) -> [Transaction] {
        [
            Transaction(title: "Groceries", category: "Food & Dining", amount: 82.45, date: Date().addingTimeInterval(-60 * 60 * 24 * 1), type: .expense, accountId: accountIds[0], currency: "USD"),
            Transaction(title: "Salary", category: "Income", amount: 2400, date: Date().addingTimeInterval(-60 * 60 * 24 * 2), type: .income, accountId: accountIds[0], currency: "USD"),
            Transaction(title: "Gym Membership", category: "Health", amount: 45.99, date: Date().addingTimeInterval(-60 * 60 * 24 * 3), type: .expense, accountId: accountIds[0], currency: "USD"),
            Transaction(title: "Coffee", category: "Food & Dining", amount: 6.75, date: Date().addingTimeInterval(-60 * 60 * 24 * 4), type: .expense, accountId: accountIds[1], currency: "USD"),
            Transaction(title: "Freelance", category: "Income", amount: 480, date: Date().addingTimeInterval(-60 * 60 * 24 * 5), type: .income, accountId: accountIds[2], currency: "USD"),
            Transaction(title: "Electric Bill", category: "Utilities", amount: 110.34, date: Date().addingTimeInterval(-60 * 60 * 24 * 6), type: .expense, accountId: accountIds[0], currency: "USD"),
            Transaction(title: "Transfer to Savings", category: "Transfer", amount: 300, date: Date().addingTimeInterval(-60 * 60 * 24 * 7), type: .transfer, accountId: accountIds[0], toAccountId: accountIds[2], currency: "USD"),
            Transaction(title: "Debt Repayment", category: "Debt", amount: 150, date: Date().addingTimeInterval(-60 * 60 * 24 * 8), type: .debt, accountId: accountIds[0], currency: "USD")
        ]
    }
}

enum TransactionType: String, CaseIterable, Identifiable, Codable {
    case income
    case expense
    case transfer
    case debt
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .income:
            return String(localized: "Income", comment: "Income transaction type")
        case .expense:
            return String(localized: "Expense", comment: "Expense transaction type")
        case .transfer:
            return String(localized: "Transfer", comment: "Transfer transaction type")
        case .debt:
            return String(localized: "Debt", comment: "Debt transaction type")
        }
    }
    
    var color: Color {
        switch self {
        case .income:
            return .green
        case .expense:
            return .red
        case .transfer:
            return .blue
        case .debt:
            return .orange
        }
    }
    
    var iconName: String {
        switch self {
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        case .debt:
            return "creditcard.fill"
        }
    }
}

struct TransactionDraft: Identifiable {
    let id: UUID
    var title: String
    var category: String
    var amount: Double
    var date: Date
    var type: TransactionType
    var accountId: UUID // Changed from accountName to accountId
    var toAccountId: UUID? // Changed from toAccountName to toAccountId
    var currency: String
    
    static func empty(currency: String = "USD", accountId: UUID? = nil) -> TransactionDraft {
        TransactionDraft(
            id: UUID(),
            title: "",
            category: "",
            amount: 0,
            date: Date(),
            type: .expense,
            accountId: accountId ?? UUID(),
            toAccountId: nil,
            currency: currency
        )
    }
    
    init(id: UUID = UUID(), title: String, category: String, amount: Double, date: Date, type: TransactionType, accountId: UUID, toAccountId: UUID? = nil, currency: String = "USD") {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
        self.type = type
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.currency = currency
    }
    
    init(transaction: Transaction) {
        self.id = transaction.id
        self.title = transaction.title
        self.category = transaction.category
        self.amount = transaction.amount
        self.date = transaction.date
        self.type = transaction.type
        self.accountId = transaction.accountId
        self.toAccountId = transaction.toAccountId
        self.currency = transaction.currency
    }
    
    init(type: TransactionType, currency: String = "USD", accountId: UUID? = nil) {
        self = TransactionDraft(
            title: "",
            category: "",
            amount: 0,
            date: Date(),
            type: type,
            accountId: accountId ?? UUID(),
            toAccountId: nil,
            currency: currency
        )
    }
    
    var isValid: Bool {
        let hasAmount = amount > 0
        let hasValidTransfer = type != .transfer || (toAccountId != nil && toAccountId != accountId)
        return hasAmount && hasValidTransfer
    }
    
    func toTransaction(existingId: UUID?) -> Transaction {
        Transaction(
            id: existingId ?? id,
            title: title.isEmpty ? "Untitled" : title,
            category: category.isEmpty ? "General" : category,
            amount: abs(amount),
            date: date,
            type: type,
            accountId: accountId,
            toAccountId: toAccountId,
            currency: currency
        )
    }
}

enum TransactionFormMode: Equatable, Hashable {
    case add(TransactionType)
    case edit(UUID)
    
    var title: String {
        switch self {
        case .add:
            return String(localized: "New Transaction", comment: "New transaction form title")
        case .edit:
            return String(localized: "Edit Transaction", comment: "Edit transaction form title")
        }
    }
    
    var transactionId: UUID? {
        switch self {
        case .add:
            return nil
        case .edit(let id):
            return id
        }
    }
}

enum TransactionTab {
    case past
    case planned
    case missed
}

// MARK: - Helper Extensions for Account Resolution

extension Transaction {
    /// Get account name from AccountManager
    func accountName(accountManager: AccountManagerAdapter) -> String {
        accountManager.getAccount(id: accountId)?.name ?? "Unknown Account"
    }
    
    /// Get destination account name for transfers
    func toAccountName(accountManager: AccountManagerAdapter) -> String? {
        guard let toAccountId = toAccountId else { return nil }
        return accountManager.getAccount(id: toAccountId)?.name
    }
}

