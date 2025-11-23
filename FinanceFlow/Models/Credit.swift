//
//  Credit.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct Credit: Identifiable {
    let id = UUID()
    let title: String
    let totalAmount: Double
    let remaining: Double
    let paid: Double
    let monthsLeft: Int
    let dueDate: Date
    let monthlyPayment: Double
    
    var progress: Double {
        guard totalAmount > 0 else { return 0 }
        return (paid / totalAmount) * 100
    }
    
    static let sample: [Credit] = {
        let calendar = Calendar.current
        return [
            Credit(
                title: "Car Loan",
                totalAmount: 25_000,
                remaining: 13_000,
                paid: 12_000,
                monthsLeft: 29,
                dueDate: calendar.date(byAdding: .day, value: 11, to: Date()) ?? Date(),
                monthlyPayment: 450
            ),
            Credit(
                title: "Home Mortgage",
                totalAmount: 250_000,
                remaining: 200_000,
                paid: 50_000,
                monthsLeft: 167,
                dueDate: calendar.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
                monthlyPayment: 1500
            ),
            Credit(
                title: "Personal Loan",
                totalAmount: 6_500,
                remaining: 6_500,
                paid: 0,
                monthsLeft: 24,
                dueDate: calendar.date(byAdding: .day, value: 8, to: Date()) ?? Date(),
                monthlyPayment: 270
            )
        ]
    }()
}

struct CreditSummary {
    let remaining: Double
    let nextDue: Date
    
    static let sample = CreditSummary(
        remaining: 203_500,
        nextDue: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
    )
}

