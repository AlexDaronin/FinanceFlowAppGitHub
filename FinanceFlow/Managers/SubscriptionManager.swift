//
//  SubscriptionManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 03/12/2025.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [PlannedPayment] = []
    
    private let subscriptionsKey = "savedSubscriptions"
    private let transactionManager: TransactionManagerAdapter // Still needed for creating transactions via adapter
    private let transactionRepository: TransactionRepositoryProtocol
    private let deleteTransactionChainUseCase: DeleteTransactionChainUseCase
    private let deleteTransactionUseCase: DeleteTransactionUseCase
    private var modelContext: ModelContext?
    
    init(
        transactionManager: TransactionManagerAdapter,
        transactionRepository: TransactionRepositoryProtocol? = nil,
        deleteTransactionChainUseCase: DeleteTransactionChainUseCase? = nil,
        deleteTransactionUseCase: DeleteTransactionUseCase? = nil,
        modelContext: ModelContext? = nil
    ) {
        self.transactionManager = transactionManager
        // Use provided repository or fallback to Dependencies.shared (for backward compatibility)
        self.transactionRepository = transactionRepository ?? Dependencies.shared.transactionRepository
        // Create UseCases if not provided
        if let chainUseCase = deleteTransactionChainUseCase {
            self.deleteTransactionChainUseCase = chainUseCase
        } else {
            self.deleteTransactionChainUseCase = DeleteTransactionChainUseCase(
                transactionRepository: self.transactionRepository,
                accountRepository: Dependencies.shared.accountRepository
            )
        }
        if let deleteUseCase = deleteTransactionUseCase {
            self.deleteTransactionUseCase = deleteUseCase
        } else {
            self.deleteTransactionUseCase = DeleteTransactionUseCase(
                transactionRepository: self.transactionRepository,
                accountRepository: Dependencies.shared.accountRepository
            )
        }
        self.modelContext = modelContext
        loadData()
        Task {
            await generateUpcomingTransactions()
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
        Task {
            await generateUpcomingTransactions()
        }
    }
    
    // MARK: - Subscription Management
    
    func addSubscription(_ subscription: PlannedPayment) {
        subscriptions.append(subscription)
        saveData()
        Task {
            await generateUpcomingTransactions()
        }
    }
    
    func updateSubscription(_ subscription: PlannedPayment) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveData()
            // Remove old generated transactions and regenerate
            removeGeneratedTransactions(for: subscription.id)
            Task {
                await generateUpcomingTransactions()
            }
        }
    }
    
    func deleteSubscription(_ subscription: PlannedPayment) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveData()
        removeGeneratedTransactions(for: subscription.id)
    }
    
    func getSubscription(id: UUID) -> PlannedPayment? {
        subscriptions.first { $0.id == id }
    }
    
    // MARK: - Transaction Generation
    
    /// Generate upcoming transactions from all subscriptions
    /// Always maintains exactly 12 months of future transactions
    /// IDEMPOTENT: Can be called multiple times without creating duplicates
    private func generateUpcomingTransactions() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for subscription in subscriptions {
            guard subscription.isRepeating,
                  let frequency = subscription.repetitionFrequency,
                  let interval = subscription.repetitionInterval else {
                // For non-repeating subscriptions, create a single transaction
                // BUG FIX 1: Use startDate if available (for credits), otherwise use subscription.date
                let baseDate = subscription.startDate ?? subscription.date
                let baseDateStart = calendar.startOfDay(for: baseDate)
                // Remove past transactions for non-repeating subscriptions
                await removePastTransactions(for: subscription.id, before: today)
                // Only create transaction if date is today or in the future (for SubscriptionsView to show it)
                if baseDateStart >= today {
                    await createTransactionIfNeeded(from: subscription, date: baseDate)
                }
                continue
            }
            
            // Remove only past transactions (keep future ones to avoid regeneration issues)
            await removePastTransactions(for: subscription.id, before: today)
            
            // Calculate target date: 12 months from today
            let targetDate = calendar.date(byAdding: .month, value: 12, to: today) ?? today
            
            // Get existing future transactions up to target date from Repository (Single Source of Truth)
            let existingFutureTransactions: [TransactionEntity]
            do {
                existingFutureTransactions = try await getFutureTransactions(for: subscription.id, from: today)
                    .filter { calendar.startOfDay(for: $0.date) <= targetDate }
            } catch {
                print("Error fetching future transactions: \(error)")
                existingFutureTransactions = []
            }
            
            // Find the latest future transaction within the 12-month window
            let latestFutureDate = existingFutureTransactions
                .map { calendar.startOfDay(for: $0.date) }
                .max()
            
            // Determine starting date for generation
            var startDate: Date
            if let latestDate = latestFutureDate, latestDate >= today && latestDate < targetDate {
                // Start from the day after the latest existing transaction within 12 months
                startDate = calendar.date(byAdding: .day, value: 1, to: latestDate) ?? latestDate
            } else {
                // BUG FIX 1: Use startDate if available (for credits), otherwise use subscription.date
                // Normalize date to day level (without time) using local timezone
                let baseDate = subscription.startDate ?? subscription.date
                let subscriptionDate = calendar.startOfDay(for: baseDate)
                // For first transaction, always use the exact startDate (don't use today if startDate is in the past)
                // This ensures the first transaction is created on the user-selected date
                startDate = subscriptionDate
            }
            
            // Generate transactions until we reach 12 months ahead
            var currentDate = calendar.startOfDay(for: startDate)
            var generatedCount = 0
            let maxTransactions = 500 // Increased limit for complex intervals
            var isFirstTransaction = true
            
            // BUG FIX 1: Get the base startDate (from subscription.startDate or subscription.date)
            // This is used to identify the first transaction
            let baseStartDate = calendar.startOfDay(for: subscription.startDate ?? subscription.date)
            
            // BUG FIX 2: Extract original day of month to preserve it across months
            // This prevents date drift (e.g., 30th -> 28th -> 28th should be 30th -> 28th -> 30th)
            let originalDay = calendar.component(.day, from: baseStartDate)
            
            // Generate transactions until we have coverage up to 12 months ahead
            while currentDate <= targetDate && generatedCount < maxTransactions {
                // Skip if date is in skippedDates
                if let skippedDates = subscription.skippedDates,
                   skippedDates.contains(where: { Calendar.current.isDate(calendar.startOfDay(for: $0), inSameDayAs: currentDate) }) {
                    currentDate = calculateNextDate(
                        from: currentDate,
                        frequency: frequency,
                        interval: interval,
                        weekdays: subscription.selectedWeekdays,
                        originalDay: originalDay
                    )
                    currentDate = calendar.startOfDay(for: currentDate)
                    isFirstTransaction = false
                    continue
                }
                
                // Skip if date is before endDate (for "Delete All Future")
                if let endDate = subscription.endDate, currentDate >= endDate {
                    break
                }
                
                // BUG FIX 1: Always create the first transaction on startDate (even if in the past)
                // For subsequent transactions, only create if they are in the future
                let shouldCreate = isFirstTransaction && calendar.isDate(currentDate, inSameDayAs: baseStartDate) || currentDate >= today
                if shouldCreate {
                    await createTransactionIfNeeded(from: subscription, date: currentDate)
                }
                
                // Calculate next date - preserve originalDay to prevent date drift
                currentDate = calculateNextDate(
                    from: currentDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: subscription.selectedWeekdays,
                    originalDay: originalDay
                )
                currentDate = calendar.startOfDay(for: currentDate)
                isFirstTransaction = false
                
                generatedCount += 1
            }
        }
    }
    
    /// Ensure future transactions are maintained (called periodically)
    /// This method maintains exactly 12 months of future transactions
    func ensureFutureTransactions() {
        Task {
            await generateUpcomingTransactions()
        }
    }
    
    /// Get all future transactions for a subscription from Repository (Single Source of Truth)
    private func getFutureTransactions(for subscriptionId: UUID, from date: Date) async throws -> [TransactionEntity] {
        let calendar = Calendar.current
        let fromDate = calendar.startOfDay(for: date)
        
        // Fetch from Repository, not from memory array
        let allTransactions = try await transactionRepository.fetchTransactions(sourceId: subscriptionId)
        
        return allTransactions.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate >= fromDate
        }
    }
    
    /// Remove only past transactions for a subscription (keeps future ones)
    /// Uses DeleteTransactionUseCase to ensure balance rollbacks
    private func removePastTransactions(for subscriptionId: UUID, before date: Date) async {
        let calendar = Calendar.current
        let beforeDate = calendar.startOfDay(for: date)
        
        // Fetch from Repository (Single Source of Truth)
        guard let allTransactions = try? await transactionRepository.fetchTransactions(sourceId: subscriptionId) else {
            return
        }
        
        let transactionsToRemove = allTransactions.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate < beforeDate
        }
        
        // Delete each transaction through UseCase to ensure balance rollbacks
        for transaction in transactionsToRemove {
            do {
                try await deleteTransactionUseCase.execute(id: transaction.id)
            } catch {
                print("Error deleting past transaction \(transaction.id): \(error)")
            }
        }
    }
    
    /// Create a transaction from subscription if it doesn't already exist
    /// IDEMPOTENT: Checks Repository (Single Source of Truth) before creating
    private func createTransactionIfNeeded(from subscription: PlannedPayment, date: Date) async {
        // Check Repository (Single Source of Truth) - not memory array
        let exists: Bool
        do {
            exists = try await transactionRepository.transactionExists(sourceId: subscription.id, date: date)
        } catch {
            print("Error checking transaction existence: \(error)")
            return
        }
        
        guard !exists else { return }
        
        // Get currency from UserDefaults (same way AppSettings does)
        let currency = UserDefaults.standard.string(forKey: "mainCurrency") ?? "USD"
        
        // Determine transaction type: transfer if toAccountId is set, otherwise income/expense
        let transactionType: TransactionType
        if subscription.toAccountId != nil {
            transactionType = .transfer
        } else {
            transactionType = subscription.isIncome ? .income : .expense
        }
        
        // Determine category: "Transfer" for transfers, otherwise use subscription category or default
        let category: String
        if transactionType == .transfer {
            category = "Transfer"
        } else {
            category = subscription.category ?? "General"
        }
        
        // Create new transaction
        let transaction = Transaction(
            title: subscription.title.isEmpty ? (subscription.isIncome ? "Recurring Income" : "Recurring Expense") : subscription.title,
            category: category,
            amount: subscription.amount,
            date: date,
            type: transactionType,
            accountId: subscription.accountId,
            toAccountId: subscription.toAccountId,
            currency: currency,
            sourcePlannedPaymentId: subscription.id,
            occurrenceDate: date
        )
        
        transactionManager.addTransaction(transaction)
    }
    
    /// Calculate next date based on frequency and interval
    /// - Parameters:
    ///   - startDate: The current date to calculate from
    ///   - frequency: The repetition frequency (Day, Week, Month, Year)
    ///   - interval: The interval value (e.g., every 2 months)
    ///   - weekdays: Optional weekdays for weekly repetition
    ///   - originalDay: Optional original day of month to preserve (for monthly/yearly frequencies)
    private func calculateNextDate(from startDate: Date, frequency: String, interval: Int, weekdays: [Int]?, originalDay: Int? = nil) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        switch frequency {
        case "Day":
            var nextDate = calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            if nextDate <= today {
                let daysFromToday = calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
                let additionalDays = abs(daysFromToday) + interval
                nextDate = calendar.date(byAdding: .day, value: additionalDays, to: today) ?? nextDate
            }
            return nextDate
            
        case "Week":
            if let weekdays = weekdays, !weekdays.isEmpty {
                // Find next matching weekday
                var checkDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                let maxDaysToCheck = 14
                var daysChecked = 0
                
                while daysChecked < maxDaysToCheck {
                    let weekday = calendar.component(.weekday, from: checkDate)
                    let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convert to 0-6 (Mon-Sun)
                    
                    if weekdays.contains(adjustedWeekday) {
                        // Found matching weekday
                        if interval > 1 {
                            // Add (interval - 1) weeks
                            checkDate = calendar.date(byAdding: .weekOfYear, value: interval - 1, to: checkDate) ?? checkDate
                        }
                        if checkDate <= today {
                            checkDate = calendar.date(byAdding: .weekOfYear, value: interval, to: checkDate) ?? checkDate
                        }
                        return checkDate
                    }
                    
                    checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
                    daysChecked += 1
                }
            }
            
            // No weekdays specified, just add interval weeks
            var nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
            if nextDate <= today {
                nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case "Month":
            // Preserve the original day of month to prevent date drift (e.g., 30th -> 28th -> 28th)
            let dayToPreserve = originalDay ?? calendar.component(.day, from: startDate)
            
            // Calculate target month
            var nextDate = calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
            
            // Get the target month/year components
            let targetComponents = calendar.dateComponents([.year, .month], from: nextDate)
            
            // Try to set the original day
            var components = targetComponents
            components.day = dayToPreserve
            
            // Check if the target month has enough days
            if let daysInMonth = calendar.range(of: .day, in: .month, for: nextDate)?.count {
                // Clamp to last day of month if originalDay doesn't exist in target month
                components.day = min(dayToPreserve, daysInMonth)
            }
            
            nextDate = calendar.date(from: components) ?? nextDate
            
            // Ensure it's in the future
            if nextDate <= today {
                // Calculate next month while preserving originalDay
                if let nextMonth = calendar.date(byAdding: .month, value: interval, to: nextDate) {
                    let nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                    var nextComponents = nextMonthComponents
                    if let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count {
                        nextComponents.day = min(dayToPreserve, daysInNextMonth)
                    } else {
                        nextComponents.day = dayToPreserve
                    }
                    nextDate = calendar.date(from: nextComponents) ?? nextMonth
                }
            }
            return nextDate
            
        case "Year":
            // Preserve the original day of month to handle leap years correctly
            let dayToPreserve = originalDay ?? calendar.component(.day, from: startDate)
            
            // Calculate target year
            var nextDate = calendar.date(byAdding: .year, value: interval, to: startDate) ?? startDate
            
            // Get the target year/month components
            let targetComponents = calendar.dateComponents([.year, .month], from: nextDate)
            
            // Try to set the original day
            var components = targetComponents
            components.day = dayToPreserve
            
            // Check if the target month has enough days (handles leap years)
            if let daysInMonth = calendar.range(of: .day, in: .month, for: nextDate)?.count {
                components.day = min(dayToPreserve, daysInMonth)
            }
            
            nextDate = calendar.date(from: components) ?? nextDate
            
            // Ensure it's in the future
            if nextDate <= today {
                // Calculate next year while preserving originalDay
                if let nextYear = calendar.date(byAdding: .year, value: interval, to: nextDate) {
                    let nextYearComponents = calendar.dateComponents([.year, .month], from: nextYear)
                    var nextComponents = nextYearComponents
                    if let daysInNextYearMonth = calendar.range(of: .day, in: .month, for: nextYear)?.count {
                        nextComponents.day = min(dayToPreserve, daysInNextYearMonth)
                    } else {
                        nextComponents.day = dayToPreserve
                    }
                    nextDate = calendar.date(from: nextComponents) ?? nextYear
                }
            }
            return nextDate
            
        default:
            return startDate
        }
    }
    
    /// Remove all generated transactions for a subscription
    /// Uses DeleteTransactionChainUseCase for atomic deletion with balance rollbacks
    private func removeGeneratedTransactions(for subscriptionId: UUID) {
        Task {
            do {
                try await deleteTransactionChainUseCase.execute(sourceId: subscriptionId)
            } catch {
                print("Error deleting transaction chain for subscription \(subscriptionId): \(error)")
            }
        }
    }
    
    /// Delete a single occurrence (transaction) of a subscription
    func deleteSingleOccurrence(transaction: Transaction) {
        guard let subscriptionId = transaction.sourcePlannedPaymentId else { return }
        
        // First, delete the transaction to prevent it from being regenerated
        transactionManager.deleteTransaction(transaction)
        
        // For non-repeating subscriptions, delete the entire subscription
        if let subscription = getSubscription(id: subscriptionId), !subscription.isRepeating {
            deleteSubscription(subscription)
            return
        }
        
        // For repeating subscriptions, add the date to skippedDates to prevent regeneration
        if let subscription = getSubscription(id: subscriptionId) {
            var skippedDates = subscription.skippedDates ?? []
            let transactionDate = Calendar.current.startOfDay(for: transaction.date)
            
            // Only add if not already in skippedDates
            if !skippedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: transactionDate) }) {
                skippedDates.append(transactionDate)
            }
            
            let updatedSubscription = PlannedPayment(
                id: subscription.id,
                title: subscription.title,
                amount: subscription.amount,
                date: subscription.date,
                status: subscription.status,
                accountId: subscription.accountId,
                toAccountId: subscription.toAccountId,
                category: subscription.category,
                type: subscription.type,
                isIncome: subscription.isIncome,
                totalLoanAmount: subscription.totalLoanAmount,
                remainingBalance: subscription.remainingBalance,
                startDate: subscription.startDate,
                interestRate: subscription.interestRate,
                linkedCreditId: subscription.linkedCreditId,
                isRepeating: subscription.isRepeating,
                repetitionFrequency: subscription.repetitionFrequency,
                repetitionInterval: subscription.repetitionInterval,
                selectedWeekdays: subscription.selectedWeekdays,
                skippedDates: skippedDates,
                endDate: subscription.endDate
            )
            
            // Update subscription without regenerating transactions (since we already deleted it)
            if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                subscriptions[index] = updatedSubscription
                saveData()
            }
            
            // Ensure we still have 12 months of future transactions
            ensureFutureTransactions()
        }
    }
    
    /// Delete all occurrences of a subscription
    func deleteAllOccurrences(subscriptionId: UUID) {
        guard let subscription = getSubscription(id: subscriptionId) else { return }
        // Delete subscription (this removes all transactions and stops generation)
        deleteSubscription(subscription)
    }
    
    // MARK: - Reset
    
    func reset() {
        // Remove all generated transactions first
        for subscription in subscriptions {
            removeGeneratedTransactions(for: subscription.id)
        }
        subscriptions = []
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<SDPlannedPayment>()
            if let sdPayments = try? modelContext.fetch(descriptor) {
                for sdPayment in sdPayments {
                    modelContext.delete(sdPayment)
                }
                try? modelContext.save()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: subscriptionsKey)
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let encoded = try? JSONEncoder().encode(subscriptions) {
                UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
            }
            return
        }
        
        // Get all existing SDPlannedPayments
        let descriptor = FetchDescriptor<SDPlannedPayment>()
        guard let existingSDPayments = try? modelContext.fetch(descriptor) else { return }
        
        // Create a map of existing payments by ID
        var existingMap: [UUID: SDPlannedPayment] = [:]
        for sdPayment in existingSDPayments {
            existingMap[sdPayment.id] = sdPayment
        }
        
        // Update or create SDPlannedPayments
        for payment in subscriptions {
            if let existing = existingMap[payment.id] {
                // Update existing
                let statusString: String
                switch payment.status {
                case .upcoming: statusString = "upcoming"
                case .past: statusString = "past"
                }
                
                let typeString: String
                switch payment.type {
                case .subscription: typeString = "subscription"
                case .loan: typeString = "loan"
                }
                
                existing.title = payment.title
                existing.amount = payment.amount
                existing.date = payment.date
                existing.status = statusString
                existing.accountId = payment.accountId
                existing.toAccountId = payment.toAccountId
                existing.category = payment.category
                existing.type = typeString
                existing.isIncome = payment.isIncome
                existing.totalLoanAmount = payment.totalLoanAmount
                existing.remainingBalance = payment.remainingBalance
                existing.startDate = payment.startDate
                existing.interestRate = payment.interestRate
                existing.linkedCreditId = payment.linkedCreditId
                existing.isRepeating = payment.isRepeating
                existing.repetitionFrequency = payment.repetitionFrequency
                existing.repetitionInterval = payment.repetitionInterval
                existing.selectedWeekdays = payment.selectedWeekdays
                existing.skippedDates = payment.skippedDates
                existing.endDate = payment.endDate
            } else {
                // Create new
                modelContext.insert(SDPlannedPayment.from(payment))
            }
        }
        
        // Delete SDPlannedPayments that are no longer in subscriptions array
        let paymentIds = Set(subscriptions.map { $0.id })
        for sdPayment in existingSDPayments {
            if !paymentIds.contains(sdPayment.id) {
                modelContext.delete(sdPayment)
            }
        }
        
        try? modelContext.save()
    }
    
    private func loadData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
               let decoded = try? JSONDecoder().decode([PlannedPayment].self, from: data) {
                subscriptions = decoded
            }
            return
        }
        
        let descriptor = FetchDescriptor<SDPlannedPayment>()
        
        if let sdPayments = try? modelContext.fetch(descriptor) {
            subscriptions = sdPayments.compactMap { $0.toPlannedPayment() }
        }
    }
}

