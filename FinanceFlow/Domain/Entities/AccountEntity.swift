//
//  AccountEntity.swift
//  FinanceFlow
//
//  Domain entity for Account - pure business model
//

import Foundation

/// Domain entity representing a financial account
struct AccountEntity: Identifiable, Equatable {
    let id: UUID
    var name: String
    var balance: Double
    var includedInTotal: Bool
    var accountType: AccountType
    var currency: String
    var isPinned: Bool
    var isSavings: Bool
    var iconName: String
    
    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        includedInTotal: Bool = true,
        accountType: AccountType = .card,
        currency: String = "USD",
        isPinned: Bool = false,
        isSavings: Bool = false,
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.includedInTotal = includedInTotal
        self.accountType = accountType
        self.currency = currency
        self.isPinned = isPinned
        self.isSavings = isSavings
        self.iconName = iconName ?? AccountEntity.defaultIconName(for: accountType)
    }
    
    private static func defaultIconName(for type: AccountType) -> String {
        switch type {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .bankAccount: return "building.columns"
        case .credit: return "creditcard.fill"
        }
    }
}

// AccountType is defined in Models/Account.swift


