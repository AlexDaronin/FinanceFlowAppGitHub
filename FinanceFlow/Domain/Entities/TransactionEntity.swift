//
//  TransactionEntity.swift
//  FinanceFlow
//
//  Domain entity for Transaction - pure business model
//

import Foundation
import SwiftUI

// TransactionType is defined in Models/Transaction.swift

/// Domain entity representing a financial transaction
struct TransactionEntity: Identifiable, Equatable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let accountId: UUID
    let toAccountId: UUID?
    let currency: String
    let sourcePlannedPaymentId: UUID?
    let occurrenceDate: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        amount: Double,
        date: Date,
        type: TransactionType,
        accountId: UUID,
        toAccountId: UUID? = nil,
        currency: String = "USD",
        sourcePlannedPaymentId: UUID? = nil,
        occurrenceDate: Date? = nil
    ) {
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
        self.occurrenceDate = occurrenceDate ?? date
    }
}


