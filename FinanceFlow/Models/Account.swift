//
//  Account.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum AccountType: String, CaseIterable, Identifiable {
    case cash
    case card
    case bankAccount
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .bankAccount: return "Bank Account"
        }
    }
    
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .bankAccount: return "building.columns"
        }
    }
}

struct Account: Identifiable {
    let id: UUID
    var name: String
    var balance: Double
    var includedInTotal: Bool
    var accountType: AccountType
    var currency: String
    var isPinned: Bool
    var isSavings: Bool
    var iconName: String
    
    init(id: UUID = UUID(), name: String, balance: Double, includedInTotal: Bool = true, accountType: AccountType = .card, currency: String = "USD", isPinned: Bool = false, isSavings: Bool = false, iconName: String? = nil) {
        self.id = id
        self.name = name
        self.balance = balance
        self.includedInTotal = includedInTotal
        self.accountType = accountType
        self.currency = currency
        self.isPinned = isPinned
        self.isSavings = isSavings
        self.iconName = iconName ?? CategoryIconLibrary.iconName(for: accountType)
    }
    
    static let sample: [Account] = [
        Account(name: "Main Card", balance: 1480.32, includedInTotal: true, accountType: .card, currency: "USD", isPinned: true),
        Account(name: "Savings", balance: 3250.00, includedInTotal: true, accountType: .bankAccount, currency: "USD", isPinned: true, isSavings: true, iconName: "dollarsign.circle.fill"),
        Account(name: "Cash", balance: 240.75, includedInTotal: false, accountType: .cash, currency: "USD"),
        Account(name: "Credit Card", balance: -1200.00, includedInTotal: true, accountType: .card, currency: "USD", isPinned: false),
        Account(name: "Investment Account", balance: 15000.00, includedInTotal: false, accountType: .bankAccount, currency: "USD", isSavings: true, iconName: "chart.line.uptrend.xyaxis"),
        Account(name: "Business Card", balance: 3200.50, includedInTotal: true, accountType: .card, currency: "USD")
    ]
}

