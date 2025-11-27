//
//  ChartDataModel.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 25/11/2025.
//

import Foundation
import Combine

// MARK: - Weekly Spending Data Point
struct WeeklySpendingDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let weekday: String // Abbreviated weekday (Mon, Tue, etc.)
    
    init(date: Date, amount: Double) {
        self.date = date
        self.amount = amount
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        self.weekday = formatter.string(from: date)
    }
}

// MARK: - Income vs Expense Summary
struct IncomeExpenseSummary {
    let income: Double
    let expense: Double
    
    var netBalance: Double {
        income - expense
    }
    
    var total: Double {
        income + expense
    }
}

// MARK: - Chart Data Provider
class ChartDataProvider: ObservableObject {
    @Published var weeklySpendingData: [WeeklySpendingDataPoint] = []
    @Published var incomeExpenseSummary: IncomeExpenseSummary = IncomeExpenseSummary(income: 0, expense: 0)
    
    var transactions: [Transaction]
    private let currency: String
    
    init(transactions: [Transaction], currency: String = "PLN") {
        self.transactions = transactions
        self.currency = currency
        updateData()
    }
    
    func updateData() {
        updateWeeklySpending()
        updateIncomeExpenseSummary()
    }
    
    func updateTransactions(_ newTransactions: [Transaction]) {
        self.transactions = newTransactions
        updateData()
    }
    
    // MARK: - Weekly Spending (Last 7 Days)
    private func updateWeeklySpending() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dataPoints: [WeeklySpendingDataPoint] = []
        
        // Get last 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            // Sum expenses for this day
            let dayExpenses = transactions
                .filter { transaction in
                    transaction.type == .expense &&
                    transaction.date >= dayStart &&
                    transaction.date < dayEnd
                }
                .map(\.amount)
                .reduce(0, +)
            
            dataPoints.append(WeeklySpendingDataPoint(date: date, amount: dayExpenses))
        }
        
        // Reverse to show oldest to newest (left to right)
        weeklySpendingData = dataPoints.reversed()
    }
    
    // MARK: - Income vs Expense (Current Month)
    private func updateIncomeExpenseSummary() {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return
        }
        
        let monthTransactions = transactions.filter { transaction in
            transaction.date >= monthStart && transaction.date < monthEnd
        }
        
        let income = monthTransactions
            .filter { $0.type == .income }
            .map(\.amount)
            .reduce(0, +)
        
        let expense = monthTransactions
            .filter { $0.type == .expense }
            .map(\.amount)
            .reduce(0, +)
        
        incomeExpenseSummary = IncomeExpenseSummary(income: income, expense: expense)
    }
}
