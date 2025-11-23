//
//  MonthlySummary.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct MonthlySummary: Identifiable {
    let id = UUID()
    let month: String
    let income: Double
    let expense: Double
    let planned: Double
    
    static let sample: [MonthlySummary] = [
        .init(month: "Nov", income: 4200, expense: 3100, planned: 3200),
        .init(month: "Oct", income: 3950, expense: 2800, planned: 3000),
        .init(month: "Sep", income: 4100, expense: 3300, planned: 3400),
        .init(month: "Aug", income: 3800, expense: 2900, planned: 3000),
        .init(month: "Jul", income: 3600, expense: 2700, planned: 2800),
        .init(month: "Jun", income: 3500, expense: 2600, planned: 2700)
    ]
}

