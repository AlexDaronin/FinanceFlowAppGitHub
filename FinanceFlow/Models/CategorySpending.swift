//
//  CategorySpending.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct CategorySpending: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    
    static let sample: [CategorySpending] = [
        .init(name: "Housing", amount: 1200),
        .init(name: "Food", amount: 650),
        .init(name: "Transport", amount: 320),
        .init(name: "Entertainment", amount: 280),
        .init(name: "Health", amount: 210),
        .init(name: "Other", amount: 180)
    ]
}

