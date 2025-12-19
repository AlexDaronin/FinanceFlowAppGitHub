//
//  ChartDataService.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

/// Service for calculating chart data from transactions
/// Separates business logic from UI layer
struct ChartDataService {
    
    // MARK: - Data Models
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let cumulativeIncome: Double
        let cumulativeExpenses: Double
        
        var balance: Double {
            cumulativeIncome - cumulativeExpenses
        }
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        let periodStart: Date
        let periodEnd: Date
        let debtTransactions: [DebtTransaction]
        
        static func currentPeriod(startDay: Int, debtTransactions: [DebtTransaction]) -> Configuration {
            let period = DateRangeHelper.currentPeriod(for: startDay)
            return Configuration(
                periodStart: period.start,
                periodEnd: period.end,
                debtTransactions: debtTransactions
            )
        }
    }
    
    // MARK: - Main Calculation Method
    
    /// Calculates cumulative income and expenses data points for the chart
    /// - Parameters:
    ///   - transactions: Array of confirmed transactions (should be filtered before passing)
    ///   - configuration: Period and debt transactions configuration
    /// - Returns: Array of chart data points sorted by date
    static func calculateChartData(
        from transactions: [Transaction],
        configuration: Configuration
    ) -> [ChartDataPoint] {
        let calendar = Calendar.current
        var dataPoints: [ChartDataPoint] = []
        var cumulativeIncome: Double = 0
        var cumulativeExpenses: Double = 0
        
        // Create a map of debt transaction types by transaction ID
        let debtTypeMap = Dictionary(
            uniqueKeysWithValues: configuration.debtTransactions.map { ($0.id, $0.type) }
        )
        
        var currentDate = calendar.startOfDay(for: configuration.periodStart)
        
        while currentDate < configuration.periodEnd {
            let dayStart = currentDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            // Get all transactions for this day
            let dayTransactions = transactions.filter { transaction in
                let transactionDate = calendar.startOfDay(for: transaction.date)
                return transactionDate >= dayStart && transactionDate < dayEnd
            }
            
            // Calculate income and expenses for this day
            let dayIncome = dayTransactions.map { transaction in
                getIncomeAmount(for: transaction, debtTypeMap: debtTypeMap)
            }.reduce(0, +)
            
            let dayExpenses = dayTransactions.map { transaction in
                getExpenseAmount(for: transaction, debtTypeMap: debtTypeMap)
            }.reduce(0, +)
            
            cumulativeIncome += dayIncome
            cumulativeExpenses += dayExpenses
            
            dataPoints.append(ChartDataPoint(
                date: currentDate,
                cumulativeIncome: cumulativeIncome,
                cumulativeExpenses: cumulativeExpenses
            ))
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dataPoints
    }
    
    // MARK: - Transaction Classification
    
    /// Calculates income amount for a transaction
    private static func getIncomeAmount(
        for transaction: Transaction,
        debtTypeMap: [UUID: DebtTransactionType]
    ) -> Double {
        switch transaction.type {
        case .income:
            return transaction.amount
        case .debt:
            // Only .borrowedReturn counts as income (when they return debt to me)
            if let debtType = debtTypeMap[transaction.id],
               debtType == .borrowedReturn {
                return transaction.amount
            }
            return 0
        case .transfer:
            // Transfers are internal movements between accounts, not income/expense
            return 0
        case .expense:
            return 0
        }
    }
    
    /// Calculates expense amount for a transaction
    private static func getExpenseAmount(
        for transaction: Transaction,
        debtTypeMap: [UUID: DebtTransactionType]
    ) -> Double {
        switch transaction.type {
        case .expense:
            return transaction.amount
        case .debt:
            // Only .lent counts as expense (when I give a loan)
            if let debtType = debtTypeMap[transaction.id],
               debtType == .lent {
                return transaction.amount
            }
            return 0
        case .transfer:
            // Transfers are internal movements between accounts, not income/expense
            return 0
        case .income:
            return 0
        }
    }
    
    // MARK: - Filtering
    
    /// Filters transactions to only include confirmed ones
    /// Excludes scheduled, unconfirmed, and missed payments
    static func filterConfirmedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { $0.sourcePlannedPaymentId == nil }
    }
    
    /// Filters transactions for a specific period
    static func filterTransactions(
        _ transactions: [Transaction],
        periodStart: Date,
        periodEnd: Date
    ) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate >= periodStart && transactionDate < periodEnd
        }
    }
}


