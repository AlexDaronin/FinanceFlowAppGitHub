//
//  Transaction.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct Transaction: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let accountName: String
    
    init(id: UUID = UUID(), title: String, category: String, amount: Double, date: Date, type: TransactionType, accountName: String) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
        self.type = type
        self.accountName = accountName
    }
    
    func displayAmount(currencyCode: String = "USD") -> String {
        let value = currencyString(abs(amount), code: currencyCode)
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
    
    static let sample: [Transaction] = [
        Transaction(title: "Groceries", category: "Food & Dining", amount: 82.45, date: Date().addingTimeInterval(-60 * 60 * 24 * 1), type: .expense, accountName: "Main Card"),
        Transaction(title: "Salary", category: "Income", amount: 2400, date: Date().addingTimeInterval(-60 * 60 * 24 * 2), type: .income, accountName: "Main Card"),
        Transaction(title: "Gym Membership", category: "Health", amount: 45.99, date: Date().addingTimeInterval(-60 * 60 * 24 * 3), type: .expense, accountName: "Main Card"),
        Transaction(title: "Coffee", category: "Food & Dining", amount: 6.75, date: Date().addingTimeInterval(-60 * 60 * 24 * 4), type: .expense, accountName: "Cash"),
        Transaction(title: "Freelance", category: "Income", amount: 480, date: Date().addingTimeInterval(-60 * 60 * 24 * 5), type: .income, accountName: "Savings"),
        Transaction(title: "Electric Bill", category: "Utilities", amount: 110.34, date: Date().addingTimeInterval(-60 * 60 * 24 * 6), type: .expense, accountName: "Main Card"),
        Transaction(title: "Transfer to Savings", category: "Transfer", amount: 300, date: Date().addingTimeInterval(-60 * 60 * 24 * 7), type: .transfer, accountName: "Main Card"),
        Transaction(title: "Debt Repayment", category: "Debt", amount: 150, date: Date().addingTimeInterval(-60 * 60 * 24 * 8), type: .debt, accountName: "Loans")
    ]
}

enum TransactionType: String, CaseIterable, Identifiable {
    case income
    case expense
    case transfer
    case debt
    
    var id: String { rawValue }
    
    var title: String {
        rawValue.capitalized
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
    var accountName: String
    var toAccountName: String? // For transfer transactions
    
    static var empty: TransactionDraft {
        TransactionDraft(
            id: UUID(),
            title: "",
            category: "",
            amount: 0,
            date: Date(),
            type: .expense,
            accountName: "Main Card",
            toAccountName: nil
        )
    }
    
    init(id: UUID = UUID(), title: String, category: String, amount: Double, date: Date, type: TransactionType, accountName: String, toAccountName: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
        self.type = type
        self.accountName = accountName
        self.toAccountName = toAccountName
    }
    
    init(transaction: Transaction) {
        self.id = transaction.id
        self.title = transaction.title
        self.category = transaction.category
        self.amount = transaction.amount
        self.date = transaction.date
        self.type = transaction.type
        self.accountName = transaction.accountName
        self.toAccountName = nil // Extract from title or add to Transaction model later
    }
    
    init(type: TransactionType) {
        self = TransactionDraft(
            title: "",
            category: "",
            amount: 0,
            date: Date(),
            type: type,
            accountName: "Main Card",
            toAccountName: type == .transfer ? nil : nil
        )
    }
    
    var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let hasAmount = amount > 0
        let hasValidTransfer = type != .transfer || (toAccountName != nil && toAccountName != accountName)
        return hasTitle && hasAmount && hasValidTransfer
    }
    
    func toTransaction(existingId: UUID?) -> Transaction {
        Transaction(
            id: existingId ?? id,
            title: title.isEmpty ? "Untitled" : title,
            category: category.isEmpty ? "General" : category,
            amount: abs(amount),
            date: date,
            type: type,
            accountName: accountName.isEmpty ? "Main Card" : accountName
        )
    }
}

enum TransactionFormMode: Equatable {
    case add(TransactionType)
    case edit(UUID)
    
    var title: String {
        switch self {
        case .add:
            return "New Transaction"
        case .edit:
            return "Edit Transaction"
        }
    }
}

enum TransactionTab {
    case past
    case planned
    case missed
}

