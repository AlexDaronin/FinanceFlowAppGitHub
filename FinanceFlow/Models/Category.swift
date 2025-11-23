//
//  Category.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var iconName: String
    
    init(id: UUID = UUID(), name: String, iconName: String) {
        self.id = id
        self.name = name
        self.iconName = iconName
    }
    
    static let defaultCategories: [Category] = [
        Category(name: "Food & Dining", iconName: "fork.knife"),
        Category(name: "Income", iconName: "arrow.down.circle.fill"),
        Category(name: "Health", iconName: "heart.fill"),
        Category(name: "Utilities", iconName: "bolt.fill"),
        Category(name: "Transfer", iconName: "arrow.left.arrow.right"),
        Category(name: "Debt", iconName: "creditcard.fill"),
        Category(name: "Shopping", iconName: "bag.fill"),
        Category(name: "Transport", iconName: "car.fill"),
        Category(name: "Entertainment", iconName: "tv.fill"),
        Category(name: "Education", iconName: "book.fill")
    ]
}

