//
//  Debt.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

enum DebtDirection: String, CaseIterable, Identifiable {
    case owedToMe = "owedToMe"  // People owe me (green)
    case iOwe = "iOwe"          // I owe people (red)
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .owedToMe:
            return "To Receive"
        case .iOwe:
            return "To Pay"
        }
    }
    
    var label: String {
        switch self {
        case .owedToMe:
            return "Owes me"
        case .iOwe:
            return "I owe"
        }
    }
    
    var color: Color {
        switch self {
        case .owedToMe:
            return .green
        case .iOwe:
            return .red
        }
    }
}

struct Debt: Identifiable {
    let id: UUID
    var personName: String
    var amount: Double
    var direction: DebtDirection
    var note: String?
    var date: Date
    var iconName: String
    
    init(id: UUID = UUID(), personName: String, amount: Double, direction: DebtDirection, note: String? = nil, date: Date = Date(), iconName: String = "person.fill") {
        self.id = id
        self.personName = personName
        self.amount = amount
        self.direction = direction
        self.note = note
        self.date = date
        self.iconName = iconName
    }
    
    static let sample: [Debt] = [
        Debt(personName: "John Smith", amount: 250.00, direction: .owedToMe, note: "Lent for groceries", date: Date().addingTimeInterval(-60 * 60 * 24 * 5), iconName: "person.fill"),
        Debt(personName: "Sarah Johnson", amount: 150.00, direction: .owedToMe, date: Date().addingTimeInterval(-60 * 60 * 24 * 10), iconName: "person.fill"),
        Debt(personName: "Mike Wilson", amount: 500.00, direction: .iOwe, note: "Restaurant bill split", date: Date().addingTimeInterval(-60 * 60 * 24 * 3), iconName: "person.fill"),
        Debt(personName: "Emma Davis", amount: 75.50, direction: .iOwe, date: Date().addingTimeInterval(-60 * 60 * 24 * 7), iconName: "person.fill")
    ]
}

struct DebtDraft {
    var personName: String
    var amount: Double
    var direction: DebtDirection
    var note: String
    var date: Date
    var iconName: String
    
    static var empty: DebtDraft {
        DebtDraft(
            personName: "",
            amount: 0,
            direction: .iOwe,
            note: "",
            date: Date(),
            iconName: "person.fill"
        )
    }
    
    init(debt: Debt) {
        self.personName = debt.personName
        self.amount = debt.amount
        self.direction = debt.direction
        self.note = debt.note ?? ""
        self.date = debt.date
        self.iconName = debt.iconName
    }
    
    init(personName: String = "", amount: Double = 0, direction: DebtDirection = .iOwe, note: String = "", date: Date = Date(), iconName: String = "person.fill") {
        self.personName = personName
        self.amount = amount
        self.direction = direction
        self.note = note
        self.date = date
        self.iconName = iconName
    }
    
    var isValid: Bool {
        !personName.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }
    
    func toDebt(existingId: UUID?) -> Debt {
        Debt(
            id: existingId ?? UUID(),
            personName: personName.trimmingCharacters(in: .whitespaces),
            amount: amount,
            direction: direction,
            note: note.isEmpty ? nil : note,
            date: date,
            iconName: iconName
        )
    }
}

