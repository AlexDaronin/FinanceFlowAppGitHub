//
//  ActionMenuOption.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct ActionMenuOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let type: TransactionType
    
    static let transactions: [ActionMenuOption] = [
        ActionMenuOption(title: "Add Expense", icon: "arrow.up.circle.fill", tint: .red, type: .expense),
        ActionMenuOption(title: "Add Income", icon: "arrow.down.circle.fill", tint: .green, type: .income),
        ActionMenuOption(title: "Transfer", icon: "arrow.left.arrow.right.circle.fill", tint: .blue, type: .transfer),
        ActionMenuOption(title: "Debt Update", icon: "creditcard.fill", tint: .orange, type: .debt)
    ]
}

