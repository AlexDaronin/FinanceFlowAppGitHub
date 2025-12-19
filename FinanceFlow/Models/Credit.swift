//
//  Credit.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct Credit: Identifiable, Codable {
    let id: UUID
    let title: String
    let totalAmount: Double
    var remaining: Double
    var paid: Double
    let monthsLeft: Int
    let dueDate: Date
    let monthlyPayment: Double
    let interestRate: Double?
    let startDate: Date?
    let paymentAccountId: UUID? // Changed from accountName to paymentAccountId (account used for payments)
    let termMonths: Int? // Total loan term in months (optional)
    var linkedAccountId: UUID? // Link to the Account created for this credit
    
    init(
        id: UUID = UUID(),
        title: String,
        totalAmount: Double,
        remaining: Double,
        paid: Double,
        monthsLeft: Int,
        dueDate: Date,
        monthlyPayment: Double,
        interestRate: Double? = nil,
        startDate: Date? = nil,
        paymentAccountId: UUID? = nil,
        termMonths: Int? = nil,
        linkedAccountId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.totalAmount = totalAmount
        self.remaining = remaining
        self.paid = paid
        self.monthsLeft = monthsLeft
        self.dueDate = dueDate
        self.monthlyPayment = monthlyPayment
        self.interestRate = interestRate
        self.startDate = startDate
        self.paymentAccountId = paymentAccountId
        self.termMonths = termMonths
        self.linkedAccountId = linkedAccountId
    }
    
    var progress: Double {
        guard totalAmount > 0 else { return 0 }
        return (paid / totalAmount) * 100
    }
    
    var percentPaid: Double {
        progress
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

// MARK: - Helper Extensions for Account Resolution

extension Credit {
    /// Get payment account name from AccountManager
    func paymentAccountName(accountManager: AccountManager) -> String? {
        guard let paymentAccountId = paymentAccountId else { return nil }
        return accountManager.getAccount(id: paymentAccountId)?.name
    }
}

