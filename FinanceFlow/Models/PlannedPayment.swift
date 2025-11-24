//
//  PlannedPayment.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

enum PlannedPaymentType: Codable {
    case subscription
    case loan
    
    var label: String {
        switch self {
        case .subscription:
            return "Subscription"
        case .loan:
            return "Loan"
        }
    }
}

struct PlannedPayment: Identifiable, Codable {
    let id: UUID
    let title: String
    let amount: Double // Monthly payment amount
    let date: Date
    let status: PlannedPaymentStatus
    let accountName: String
    let category: String?
    let type: PlannedPaymentType
    let isIncome: Bool // true for income (salary, etc.), false for expenses (subscriptions)
    
    // Loan-specific properties
    let totalLoanAmount: Double? // Total loan amount (nil for subscriptions)
    let remainingBalance: Double? // Remaining balance (nil for subscriptions)
    let startDate: Date? // Loan start date (nil for subscriptions)
    let interestRate: Double? // Interest rate percentage (optional)
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        status: PlannedPaymentStatus,
        accountName: String,
        category: String? = nil,
        type: PlannedPaymentType = .subscription,
        isIncome: Bool = false,
        totalLoanAmount: Double? = nil,
        remainingBalance: Double? = nil,
        startDate: Date? = nil,
        interestRate: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.status = status
        self.accountName = accountName
        self.category = category
        self.type = type
        self.isIncome = isIncome
        self.totalLoanAmount = totalLoanAmount
        self.remainingBalance = remainingBalance
        self.startDate = startDate
        self.interestRate = interestRate
    }
    
    // Computed properties for loans
    var progress: Double {
        guard let total = totalLoanAmount, let remaining = remainingBalance, total > 0 else {
            return 0
        }
        let paid = total - remaining
        return (paid / total) * 100
    }
    
    var monthsRemaining: Int? {
        guard let remaining = remainingBalance, amount > 0 else {
            return nil
        }
        return Int(ceil(remaining / amount))
    }
    
    static let sample: [PlannedPayment] = [
        // Subscriptions
        PlannedPayment(title: "Spotify Premium", amount: 9.99, date: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(), status: .upcoming, accountName: "Main Card", category: "Entertainment", type: .subscription),
        PlannedPayment(title: "Netflix", amount: 15.99, date: Calendar.current.date(byAdding: .day, value: 8, to: Date()) ?? Date(), status: .upcoming, accountName: "Main Card", category: "Entertainment", type: .subscription),
        PlannedPayment(title: "YouTube Premium", amount: 11.99, date: Calendar.current.date(byAdding: .day, value: 11, to: Date()) ?? Date(), status: .upcoming, accountName: "Main Card", category: "Entertainment", type: .subscription),
        PlannedPayment(title: "Phone Bill", amount: 45.5, date: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(), status: .past, accountName: "Main Card", category: "Utilities", type: .subscription),
        
        // Loans
        PlannedPayment(
            title: "Car Loan",
            amount: 450,
            date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            status: .upcoming,
            accountName: "Main Card",
            category: "Debt",
            type: .loan,
            totalLoanAmount: 25000,
            remainingBalance: 13000,
            startDate: Calendar.current.date(byAdding: .month, value: -12, to: Date()),
            interestRate: 4.5
        ),
        PlannedPayment(
            title: "Home Mortgage",
            amount: 1500,
            date: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
            status: .upcoming,
            accountName: "Main Card",
            category: "Housing",
            type: .loan,
            totalLoanAmount: 250000,
            remainingBalance: 200000,
            startDate: Calendar.current.date(byAdding: .month, value: -24, to: Date()),
            interestRate: 3.2
        )
    ]
}

enum PlannedPaymentStatus: Codable {
    case upcoming
    case past
    
    var label: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .past:
            return "Past due"
        }
    }
    
    var tint: Color {
        switch self {
        case .upcoming:
            return .blue
        case .past:
            return .orange
        }
    }
}

struct PlannedDataPoint: Identifiable {
    let id = UUID()
    let dayLabel: String
    let planned: Double
    let actual: Double
    
    static let sample: [PlannedDataPoint] = [
        .init(dayLabel: "18 Oct", planned: 3000, actual: 2500),
        .init(dayLabel: "20 Oct", planned: 4000, actual: 3200),
        .init(dayLabel: "25 Oct", planned: 4500, actual: 3700),
        .init(dayLabel: "30 Oct", planned: 5000, actual: 4200),
        .init(dayLabel: "5 Nov", planned: 5500, actual: 4600),
        .init(dayLabel: "10 Nov", planned: 6000, actual: 4800),
        .init(dayLabel: "17 Nov", planned: 6500, actual: 5211)
    ]
}

