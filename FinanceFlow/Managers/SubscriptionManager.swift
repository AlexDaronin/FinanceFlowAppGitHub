//
//  SubscriptionManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

// Repetition frequency enum for subscription generation
enum RepetitionFrequency: String {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [PlannedPayment] = []
    @Published var upcomingTransactions: [Transaction] = [] // Single source of truth for generated subscription transactions
    
    private let subscriptionsKey = "savedSubscriptions"
    
    init() {
        loadData()
        generateUpcomingTransactions()
    }
    
    /// Clean up old subscription transactions from TransactionManager
    /// This should be called after TransactionManager is initialized
    func cleanupOldTransactions(in transactionManager: TransactionManager) {
        transactionManager.cleanupAllSubscriptionTransactions(subscriptionManager: self)
    }
    
    // MARK: - Subscription Management
    
    func addSubscription(_ subscription: PlannedPayment) {
        subscriptions.append(subscription)
        saveData()
        generateUpcomingTransactions() // Regenerate after adding
        // Force UI refresh in both Planned and Future tabs
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    func updateSubscription(_ subscription: PlannedPayment) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveData()
            generateUpcomingTransactions() // Regenerate after updating
            // Force UI refresh in both Planned and Future tabs
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    
    func deleteSubscription(_ subscription: PlannedPayment) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveData()
        generateUpcomingTransactions() // Regenerate after deleting
        // Force UI refresh in both Planned and Future tabs
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    func getSubscription(id: UUID) -> PlannedPayment? {
        subscriptions.first { $0.id == id }
    }
    
    // MARK: - Calculations
    
    /// Calculates total monthly burn (expenses) for the current financial period
    func totalMonthlyBurn(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        let calendar = Calendar.current
        
        return subscriptions
            .filter { subscription in
                // 1. Basic checks (Status, Type, Date Range)
                guard subscription.status == .upcoming,
                      !subscription.isIncome,
                      subscription.date >= period.start,
                      subscription.date < period.end else {
                    return false
                }
                
                // 2. Check Termination (Delete All Future)
                // If the scheduled date is strictly after the end date, ignore it.
                if let endDate = subscription.endDate {
                    let dateStart = calendar.startOfDay(for: subscription.date)
                    let endDateStart = calendar.startOfDay(for: endDate)
                    if dateStart > endDateStart {
                        return false
                    }
                }
                
                // 3. Check Skipped (Delete Only This)
                // If the scheduled date is in the skipped list, ignore it.
                if let skipped = subscription.skippedDates {
                    if skipped.contains(where: { calendar.isDate($0, inSameDayAs: subscription.date) }) {
                        return false
                    }
                }
                
                return true
            }
            .map(\.amount)
            .reduce(0, +)
    }
    
    /// Calculates total monthly income for the current financial period
    func totalMonthlyIncome(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        let calendar = Calendar.current
        
        return subscriptions
            .filter { subscription in
                // 1. Basic checks (Status, Type, Date Range)
                guard subscription.status == .upcoming,
                      subscription.isIncome,
                      subscription.date >= period.start,
                      subscription.date < period.end else {
                    return false
                }
                
                // 2. Check Termination (Delete All Future)
                // If the scheduled date is strictly after the end date, ignore it.
                if let endDate = subscription.endDate {
                    let dateStart = calendar.startOfDay(for: subscription.date)
                    let endDateStart = calendar.startOfDay(for: endDate)
                    if dateStart > endDateStart {
                        return false
                    }
                }
                
                // 3. Check Skipped (Delete Only This)
                // If the scheduled date is in the skipped list, ignore it.
                if let skipped = subscription.skippedDates {
                    if skipped.contains(where: { calendar.isDate($0, inSameDayAs: subscription.date) }) {
                        return false
                    }
                }
                
                return true
            }
            .map(\.amount)
            .reduce(0, +)
    }
    
    /// Monthly burn rate for the current financial period
    func monthlyBurnRate(startDay: Int) -> Double {
        totalMonthlyBurn(startDay: startDay)
    }
    
    /// Monthly projected income for the current financial period
    func monthlyProjectedIncome(startDay: Int) -> Double {
        totalMonthlyIncome(startDay: startDay)
    }
    
    /// Active subscriptions count within the current financial period
    func activeSubscriptionsCount(startDay: Int) -> Int {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        let calendar = Calendar.current
        
        return subscriptions.filter { subscription in
            // 1. Basic checks (Status, Date Range)
            // Note: Count both income and expenses, or strictly expenses depending on UI intent. 
            // Usually dashboard counts all active items.
            guard subscription.status == .upcoming,
                  subscription.date >= period.start,
                  subscription.date < period.end else {
                return false
            }
            
            // 2. Check Termination (Delete All Future)
            // If the scheduled date is strictly after the end date, the subscription is dead.
            if let endDate = subscription.endDate {
                let dateStart = calendar.startOfDay(for: subscription.date)
                let endDateStart = calendar.startOfDay(for: endDate)
                if dateStart > endDateStart {
                    return false
                }
            }
            
            // 3. Check Skipped (Delete Only This)
            if let skipped = subscription.skippedDates {
                if skipped.contains(where: { calendar.isDate($0, inSameDayAs: subscription.date) }) {
                    return false
                }
            }
            
            return true
        }.count
    }
    
    /// Legacy computed properties for backward compatibility (uses default startDay = 1)
    var totalMonthlyBurn: Double {
        totalMonthlyBurn(startDay: 1)
    }
    
    var totalMonthlyIncome: Double {
        totalMonthlyIncome(startDay: 1)
    }
    
    var monthlyBurnRate: Double {
        totalMonthlyBurn
    }
    
    var monthlyProjectedIncome: Double {
        totalMonthlyIncome
    }
    
    var activeSubscriptionsCount: Int {
        activeSubscriptionsCount(startDay: 1)
    }
    
    func subscriptions(isIncome: Bool) -> [PlannedPayment] {
        subscriptions.filter { $0.isIncome == isIncome }
    }
    
    // MARK: - Pay Early Feature
    
    /// Pay a subscription early by creating a real transaction and skipping the scheduled occurrence
    /// - Parameters:
    ///   - subscription: The subscription to pay early
    ///   - occurrenceDate: The specific date of the occurrence to pay (and skip)
    ///   - transactionManager: The transaction manager to add the new transaction to
    func payEarly(subscription: PlannedPayment, occurrenceDate: Date, transactionManager: TransactionManager) {
        // Create a new standalone transaction with today's date
        // Do not link it to a source payment ID; treat it as a standalone transaction
        let newTransaction = Transaction(
            id: UUID(),
            title: subscription.title,
            category: subscription.category ?? "General",
            amount: subscription.amount,
            date: Date(), // Pay now, not on the scheduled date
            type: subscription.isIncome ? .income : .expense,
            accountName: subscription.accountName,
            toAccountName: nil,
            currency: UserDefaults.standard.string(forKey: "mainCurrency") ?? "USD",
            sourcePlannedPaymentId: nil, // Standalone transaction, not linked to subscription
            occurrenceDate: nil // Standalone transaction, no occurrence date
        )
        
        // Add the transaction to TransactionManager
        transactionManager.addTransaction(newTransaction)
        
        // Skip the scheduled occurrence so it disappears from the "Future" list
        skipDate(for: subscription, date: occurrenceDate)
        
        // Force UI refresh
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // Skip a specific date for a repeating payment
    func skipDate(for payment: PlannedPayment, date: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == payment.id }) else {
            return
        }
        
        let calendar = Calendar.current
        let dateToSkip = calendar.startOfDay(for: date)
        
        var existingSkippedDates = payment.skippedDates ?? []
        
        // Check if date is already skipped
        if !existingSkippedDates.contains(where: { calendar.isDate($0, inSameDayAs: dateToSkip) }) {
            existingSkippedDates.append(dateToSkip)
            
            // Update the payment with new skipped dates
            let updatedPayment = PlannedPayment(
                id: payment.id,
                title: payment.title,
                amount: payment.amount,
                date: payment.date,
                status: payment.status,
                accountName: payment.accountName,
                category: payment.category,
                type: payment.type,
                isIncome: payment.isIncome,
                totalLoanAmount: payment.totalLoanAmount,
                remainingBalance: payment.remainingBalance,
                startDate: payment.startDate,
                interestRate: payment.interestRate,
                isRepeating: payment.isRepeating,
                repetitionFrequency: payment.repetitionFrequency,
                repetitionInterval: payment.repetitionInterval,
                selectedWeekdays: payment.selectedWeekdays,
                skippedDates: existingSkippedDates,
                endDate: payment.endDate
            )
            
            subscriptions[index] = updatedPayment
            saveData()
            generateUpcomingTransactions() // Regenerate after skipping date
        }
    }
    
    // Set end date for a repeating payment (terminate chain from a specific date forward)
    func setEndDate(for payment: PlannedPayment, endDate: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == payment.id }) else {
            return
        }
        
        let calendar = Calendar.current
        let endDateToSet = calendar.startOfDay(for: endDate)
        
        // Update the payment with end date
        let updatedPayment = PlannedPayment(
            id: payment.id,
            title: payment.title,
            amount: payment.amount,
            date: payment.date,
            status: payment.status,
            accountName: payment.accountName,
            category: payment.category,
            type: payment.type,
            isIncome: payment.isIncome,
            totalLoanAmount: payment.totalLoanAmount,
            remainingBalance: payment.remainingBalance,
            startDate: payment.startDate,
            interestRate: payment.interestRate,
            isRepeating: payment.isRepeating,
            repetitionFrequency: payment.repetitionFrequency,
            repetitionInterval: payment.repetitionInterval,
            selectedWeekdays: payment.selectedWeekdays,
            skippedDates: payment.skippedDates,
            endDate: endDateToSet
        )
        
        subscriptions[index] = updatedPayment
        saveData()
        generateUpcomingTransactions() // Regenerate after setting end date
    }
    
    // MARK: - Transaction Generation (Single Source of Truth)
    
    /// Generate upcoming transactions for all repeating subscriptions
    /// This is the SINGLE SOURCE OF TRUTH - no standalone transactions should be created
    func generateUpcomingTransactions() {
        var allTransactions: [Transaction] = []
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        
        // Get all repeating subscriptions
        let repeatingSubscriptions = subscriptions.filter { $0.isRepeating }
        
        for subscription in repeatingSubscriptions {
            guard let frequencyString = subscription.repetitionFrequency,
                  let frequency = RepetitionFrequency(rawValue: frequencyString),
                  let interval = subscription.repetitionInterval else {
                continue
            }
            
            let startDate = subscription.date
            let weekdays = subscription.selectedWeekdays.map { Set($0) } ?? []
            let skippedDates = subscription.skippedDates ?? []
            let subscriptionEndDate = subscription.endDate
            
            // Determine actual end date (use subscription's endDate if set)
            let actualEndDate = subscriptionEndDate ?? endDate
            
            let startDateStart = calendar.startOfDay(for: startDate)
            let todayStart = calendar.startOfDay(for: today)
            let actualEndDateStart = calendar.startOfDay(for: actualEndDate)
            
            // Extract original day component from startDate for month/year frequencies
            // This ensures we preserve the original day (e.g., 31st) across months
            let originalDay = calendar.component(.day, from: startDate)
            
            // BUG FIX 1: Always include first occurrence on startDate
            // The user expects the subscription to start on the day they selected
            let isStartDateSkipped = skippedDates.contains { skippedDate in
                calendar.isDate(startDateStart, inSameDayAs: skippedDate)
            }
            
            let isWithinEndDate = startDateStart <= actualEndDateStart
            
            // CRITICAL FIX: Always include first occurrence if it's today or in the future
            // Use >= (inclusive) to ensure today is included
            // Also include recent past (up to 90 days) to ensure visibility
            let ninetyDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -90, to: today) ?? today)
            let isTodayOrFuture = startDateStart >= todayStart
            let isRecentPast = startDateStart >= ninetyDaysAgo && startDateStart < todayStart
            
            // Include if: (today or future) OR (recent past within 90 days)
            let shouldIncludeFirst = isTodayOrFuture || isRecentPast
            
            if !isStartDateSkipped && isWithinEndDate && shouldIncludeFirst {
                let transaction = Transaction(
                    id: Self.generateOccurrenceId(subscriptionId: subscription.id, occurrenceDate: startDate),
                    title: subscription.title,
                    category: subscription.category ?? "General",
                    amount: subscription.amount,
                    date: startDate,
                    type: subscription.isIncome ? .income : .expense,
                    accountName: subscription.accountName,
                    toAccountName: nil,
                    currency: UserDefaults.standard.string(forKey: "mainCurrency") ?? "USD",
                    sourcePlannedPaymentId: subscription.id,
                    occurrenceDate: startDate
                )
                allTransactions.append(transaction)
            }
            
            // Generate subsequent occurrences
            // BUG FIX 2: Preserve originalDay for month/year frequencies to prevent date drift
            var currentDate = calculateNextDate(
                from: startDate,
                frequency: frequency,
                interval: interval,
                weekdays: weekdays,
                originalDay: originalDay
            )
            
            var iterationCount = 0
            let maxIterations = 1000
            
            // Generate until we reach end date
            while currentDate <= actualEndDate && iterationCount < maxIterations {
                iterationCount += 1
                
                let currentDateStart = calendar.startOfDay(for: currentDate)
                
                // Check if this date is skipped
                let isSkipped = skippedDates.contains { skippedDate in
                    calendar.isDate(currentDateStart, inSameDayAs: skippedDate)
                }
                
                // Check if date is after endDate
                if currentDateStart > actualEndDateStart {
                    break
                }
                
                // Only include today and future dates that are not skipped
                if currentDateStart >= todayStart && !isSkipped {
                    let transaction = Transaction(
                        id: Self.generateOccurrenceId(subscriptionId: subscription.id, occurrenceDate: currentDate),
                        title: subscription.title,
                        category: subscription.category ?? "General",
                        amount: subscription.amount,
                        date: currentDate,
                        type: subscription.isIncome ? .income : .expense,
                        accountName: subscription.accountName,
                        toAccountName: nil,
                        currency: UserDefaults.standard.string(forKey: "mainCurrency") ?? "USD",
                        sourcePlannedPaymentId: subscription.id,
                        occurrenceDate: currentDate
                    )
                    allTransactions.append(transaction)
                }
                
                // Calculate next date - preserve originalDay to prevent drift
                let nextDate = calculateNextDate(
                    from: currentDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays,
                    originalDay: originalDay
                )
                
                if nextDate <= currentDate || nextDate > actualEndDate {
                    break
                }
                
                currentDate = nextDate
            }
        }
        
        // Sort by date and update published property on main thread
        // CRITICAL: Always update on main thread to ensure UI refreshes
        let sortedTransactions = allTransactions.sorted { $0.date < $1.date }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.upcomingTransactions = sortedTransactions
            self.objectWillChange.send() // Explicitly trigger UI update
        }
    }
    
    // Helper function to calculate next date based on frequency
    // BUG FIX 2: Added originalDay parameter to preserve the original day of month
    // This prevents date drift (e.g., 31st -> 28th -> 28th should be 31st -> 28th -> 31st)
    private func calculateNextDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>,
        originalDay: Int
    ) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        switch frequency {
        case .day:
            var nextDate = calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            // CRITICAL FIX: Use < (exclusive) to ensure today is included if startDate is today
            // Only advance if the date is strictly in the past (before today)
            let todayStart = calendar.startOfDay(for: today)
            let nextDateStart = calendar.startOfDay(for: nextDate)
            if nextDateStart < todayStart {
                // Find next date in the future
                while nextDateStart < todayStart {
                    if let date = calendar.date(byAdding: .day, value: interval, to: nextDate) {
                        nextDate = date
                        let newNextDateStart = calendar.startOfDay(for: nextDate)
                        if newNextDateStart >= todayStart {
                            break
                        }
                    } else {
                        break
                    }
                }
            }
            return nextDate
            
        case .week:
            let todayStart = calendar.startOfDay(for: today)
            if !weekdays.isEmpty {
                // Find next matching weekday
                var candidate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                var attempts = 0
                while attempts < 7 {
                    let weekday = calendar.component(.weekday, from: candidate)
                    let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
                    let candidateStart = calendar.startOfDay(for: candidate)
                    // CRITICAL FIX: Use >= (inclusive) to ensure today is included
                    if weekdays.contains(adjustedWeekday) && candidateStart >= todayStart {
                        return candidate
                    }
                    if let next = calendar.date(byAdding: .day, value: 1, to: candidate) {
                        candidate = next
                    } else {
                        break
                    }
                    attempts += 1
                }
                // Fallback to interval weeks
                return calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
            } else {
                var nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                let nextDateStart = calendar.startOfDay(for: nextDate)
                // CRITICAL FIX: Use < (exclusive) to ensure today is included
                if nextDateStart < todayStart {
                    nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: nextDate) ?? nextDate
                }
                return nextDate
            }
            
        case .month:
            // BUG FIX 2: Calculate target month, then force originalDay
            // This ensures 31st stays 31st for months that have it, and only clamps when necessary
            let targetDate = calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
            
            // Get the target month/year
            let targetComponents = calendar.dateComponents([.year, .month], from: targetDate)
            
            // Try to set the original day
            var components = targetComponents
            components.day = originalDay
            
            // Check if the target month has enough days
            if let daysInMonth = calendar.range(of: .day, in: .month, for: targetDate)?.count {
                // Clamp to last day of month if originalDay doesn't exist in target month
                // But remember: we want to use originalDay for the NEXT iteration, not stick to clamped day
                components.day = min(originalDay, daysInMonth)
            }
            
            var nextDate = calendar.date(from: components) ?? targetDate
            
            // CRITICAL FIX: Use >= (inclusive) instead of > to ensure today is included
            // Only advance if the date is strictly in the past (before today)
            let todayStart = calendar.startOfDay(for: today)
            let nextDateStart = calendar.startOfDay(for: nextDate)
            
            if nextDateStart < todayStart {
                // Calculate next month while preserving originalDay
                if let nextMonth = calendar.date(byAdding: .month, value: interval, to: nextDate) {
                    let nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                    var nextComponents = nextMonthComponents
                    if let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count {
                        nextComponents.day = min(originalDay, daysInNextMonth)
                    } else {
                        nextComponents.day = originalDay
                    }
                    nextDate = calendar.date(from: nextComponents) ?? nextMonth
                }
            }
            
            return nextDate
            
        case .year:
            // BUG FIX 2: For yearly, also preserve originalDay to handle leap years correctly
            let targetDate = calendar.date(byAdding: .year, value: interval, to: startDate) ?? startDate
            
            // Get the target year/month
            let targetComponents = calendar.dateComponents([.year, .month], from: targetDate)
            
            // Try to set the original day
            var components = targetComponents
            components.day = originalDay
            
            // Check if the target month has enough days (handles leap years)
            if let daysInMonth = calendar.range(of: .day, in: .month, for: targetDate)?.count {
                components.day = min(originalDay, daysInMonth)
            }
            
            var nextDate = calendar.date(from: components) ?? targetDate
            
            // CRITICAL FIX: Use < (exclusive) instead of <= to ensure today is included
            // Only advance if the date is strictly in the past (before today)
            let todayStart = calendar.startOfDay(for: today)
            let nextDateStart = calendar.startOfDay(for: nextDate)
            
            if nextDateStart < todayStart {
                // Calculate next year while preserving originalDay
                if let nextYear = calendar.date(byAdding: .year, value: interval, to: nextDate) {
                    let nextYearComponents = calendar.dateComponents([.year, .month], from: nextYear)
                    var nextComponents = nextYearComponents
                    if let daysInNextYearMonth = calendar.range(of: .day, in: .month, for: nextYear)?.count {
                        nextComponents.day = min(originalDay, daysInNextYearMonth)
                    } else {
                        nextComponents.day = originalDay
                    }
                    nextDate = calendar.date(from: nextComponents) ?? nextYear
                }
            }
            
            return nextDate
        }
    }
    
    // MARK: - Unified Deletion Functions (REQUIREMENT D)
    
    /// Generate a deterministic occurrenceId from subscriptionId and date (REQUIREMENT A)
    /// This ensures the same occurrence always has the same ID for reliable deletion
    static func generateOccurrenceId(subscriptionId: UUID, occurrenceDate: Date) -> UUID {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: occurrenceDate)
        let dateString = ISO8601DateFormatter().string(from: dateOnly)
        let combinedString = "\(subscriptionId.uuidString)-\(dateString)"
        
        // Use hash to create deterministic UUID (simplified but sufficient)
        var hasher = Hasher()
        hasher.combine(combinedString)
        let hashValue = hasher.finalize()
        
        // Convert hash to UUID bytes using multiple hash iterations for full 16 bytes
        var bytes = [UInt8](repeating: 0, count: 16)
        var value = UInt64(truncatingIfNeeded: hashValue)
        
        // First 8 bytes from hash
        for i in 0..<8 {
            bytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        
        // Second 8 bytes from additional hash of reversed string
        var hasher2 = Hasher()
        hasher2.combine(combinedString.reversed())
        let hashValue2 = hasher2.finalize()
        value = UInt64(truncatingIfNeeded: hashValue2)
        for i in 8..<16 {
            bytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        
        // Format as UUID v4-like (but deterministic)
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                               bytes[0], bytes[1], bytes[2], bytes[3],
                               bytes[4], bytes[5],
                               (bytes[6] & 0x0F) | 0x40, bytes[7], // Version 4
                               (bytes[8] & 0x3F) | 0x80, bytes[9], // Variant
                               bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    /// Delete all future occurrences from a specific date forward (REQUIREMENT D: Delete All Future)
    /// - Parameters:
    ///   - subscriptionId: The ID of the subscription
    ///   - fromDate: Delete all occurrences with date >= fromDate (REQUIREMENT E.2: use >= not >)
    func deleteAllFuture(subscriptionId: UUID, fromDate: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            // Subscription not found - might be an old subscription that was deleted
            // Regenerate transactions anyway to ensure UI is up to date
            generateUpcomingTransactions()
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
            return
        }
        
        let payment = subscriptions[index]
        let calendar = Calendar.current
        let fromDateStart = calendar.startOfDay(for: fromDate)
        
        // Set endDate to the day before fromDate to exclude fromDate and all later dates
        // This ensures occurrences with date >= fromDate are excluded (REQUIREMENT E.2)
        if let endDate = calendar.date(byAdding: .day, value: -1, to: fromDateStart) {
            setEndDate(for: payment, endDate: endDate)
        }
        // Force UI refresh in both Planned and Future tabs
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// Delete only a specific occurrence by date (REQUIREMENT D: Delete Only This)
    /// - Parameters:
    ///   - subscriptionId: The ID of the subscription
    ///   - occurrenceDate: The exact date of the occurrence to delete
    func deleteOccurrence(subscriptionId: UUID, occurrenceDate: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            // Subscription not found - might be an old subscription that was deleted
            // Regenerate transactions anyway to ensure UI is up to date
            generateUpcomingTransactions()
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
            return
        }
        
        let payment = subscriptions[index]
        let calendar = Calendar.current
        let dateToSkip = calendar.startOfDay(for: occurrenceDate)
        
        // Add to skipped dates
        skipDate(for: payment, date: dateToSkip)
        // Force UI refresh in both Planned and Future tabs
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// Reload all subscriptions from storage and publish changes (REQUIREMENT F)
    func reloadAll() {
        loadData()
        objectWillChange.send()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
            // REQUIREMENT F: Publish changes immediately for UI updates
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([PlannedPayment].self, from: data) {
            subscriptions = decoded
            generateUpcomingTransactions() // Regenerate after loading
        }
    }
}

