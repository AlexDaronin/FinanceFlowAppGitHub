//
//  DebtTransaction.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum DebtTransactionType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Исходящий долг: я дал в долг (мне должны)
    case lent = "lent"
    // Возврат исходящего долга: я вернул долг (уменьшает долг)
    case lentReturn = "lentReturn"
    // Входящий долг: мне дали в долг (я должен)
    case borrowed = "borrowed"
    // Возврат входящего долга: мне вернули долг (уменьшает долг)
    case borrowedReturn = "borrowedReturn"
    
    var title: String {
        switch self {
        case .lent:
            return String(localized: "I lent", comment: "I lent money")
        case .lentReturn:
            return String(localized: "I returned debt", comment: "I returned a debt")
        case .borrowed:
            return String(localized: "I borrowed", comment: "I borrowed money")
        case .borrowedReturn:
            return String(localized: "They returned debt", comment: "They returned a debt to me")
        }
    }
    
    var displayTitle: String {
        switch self {
        case .lent:
            return String(localized: "I lent / I returned debt", comment: "I lent or returned debt")
        case .lentReturn:
            return String(localized: "I lent / I returned debt", comment: "I lent or returned debt")
        case .borrowed:
            return String(localized: "They lent / They returned debt", comment: "They lent or returned debt")
        case .borrowedReturn:
            return String(localized: "They lent / They returned debt", comment: "They lent or returned debt")
        }
    }
    
    var direction: DebtDirection {
        switch self {
        case .lent, .lentReturn:
            return .owedToMe
        case .borrowed, .borrowedReturn:
            return .iOwe
        }
    }
    
    var isReturn: Bool {
        switch self {
        case .lentReturn, .borrowedReturn:
            return true
        default:
            return false
        }
    }
    
    var baseType: DebtTransactionType {
        switch self {
        case .lent, .lentReturn:
            return .lent
        case .borrowed, .borrowedReturn:
            return .borrowed
        }
    }
}

struct DebtTransaction: Identifiable, Codable {
    let id: UUID
    var contactId: UUID
    var amount: Double
    var type: DebtTransactionType
    var date: Date
    var note: String?
    var isSettled: Bool
    var accountId: UUID
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        contactId: UUID,
        amount: Double,
        type: DebtTransactionType,
        date: Date = Date(),
        note: String? = nil,
        isSettled: Bool = false,
        accountId: UUID = UUID(),
        currency: String = "USD",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.contactId = contactId
        self.amount = amount
        self.type = type
        self.date = date
        self.note = note
        self.isSettled = isSettled
        self.accountId = accountId
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static let sample: [DebtTransaction] = [
        DebtTransaction(contactId: UUID(), amount: 250.00, type: .lent, date: Date().addingTimeInterval(-60 * 60 * 24 * 5), note: "Lent for groceries"),
        DebtTransaction(contactId: UUID(), amount: 150.00, type: .lent, date: Date().addingTimeInterval(-60 * 60 * 24 * 10)),
        DebtTransaction(contactId: UUID(), amount: 500.00, type: .borrowed, date: Date().addingTimeInterval(-60 * 60 * 24 * 3), note: "Restaurant bill split"),
        DebtTransaction(contactId: UUID(), amount: 75.50, type: .borrowed, date: Date().addingTimeInterval(-60 * 60 * 24 * 7))
    ]
}

