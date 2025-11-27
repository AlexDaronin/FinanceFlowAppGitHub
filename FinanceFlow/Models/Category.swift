//
//  Category.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

enum CategoryType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    
    var displayName: String {
        switch self {
        case .income:
            return String(localized: "Income", comment: "Income category type")
        case .expense:
            return String(localized: "Expense", comment: "Expense category type")
        }
    }
}

struct Subcategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String
    
    init(id: UUID = UUID(), name: String, iconName: String = "tag.fill") {
        self.id = id
        self.name = name
        self.iconName = iconName
    }
}

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String
    var colorName: String
    var type: CategoryType
    var subcategories: [Subcategory]
    
    init(id: UUID = UUID(), name: String, iconName: String, colorName: String = "blue", type: CategoryType = .expense, subcategories: [Subcategory] = []) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorName = colorName
        self.type = type
        self.subcategories = subcategories
    }
    
    var color: Color {
        CategoryColorLibrary.color(for: colorName)
    }
    
    static let defaultCategories: [Category] = [
        Category(name: "Food & Dining", iconName: "fork.knife", colorName: "orange", type: .expense),
        Category(name: "Income", iconName: "arrow.down.circle.fill", colorName: "green", type: .income),
        Category(name: "Health", iconName: "heart.fill", colorName: "pink", type: .expense),
        Category(name: "Utilities", iconName: "bolt.fill", colorName: "yellow", type: .expense),
        Category(name: "Transfer", iconName: "arrow.left.arrow.right", colorName: "blue", type: .expense),
        Category(name: "Debt", iconName: "creditcard.fill", colorName: "red", type: .expense),
        Category(name: "Shopping", iconName: "bag.fill", colorName: "purple", type: .expense),
        Category(name: "Transport", iconName: "car.fill", colorName: "cyan", type: .expense),
        Category(name: "Entertainment", iconName: "tv.fill", colorName: "indigo", type: .expense),
        Category(name: "Education", iconName: "book.fill", colorName: "teal", type: .expense)
    ]
}

