//
//  DebtTransaction.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum DebtTransactionType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case lent = "lent"      // I lent money (they owe me)
    case borrowed = "borrowed" // I borrowed money (I owe them)
    
    var title: String {
        switch self {
        case .lent:
            return "I lent"
        case .borrowed:
            return "I borrowed"
        }
    }
    
    var direction: DebtDirection {
        switch self {
        case .lent:
            return .owedToMe
        case .borrowed:
            return .iOwe
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

