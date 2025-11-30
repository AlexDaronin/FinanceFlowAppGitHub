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
        return subscriptions
            .filter { subscription in
                subscription.status == .upcoming &&
                !subscription.isIncome &&
                subscription.date >= period.start &&
                subscription.date < period.end
            }
            .map(\.amount)
            .reduce(0, +)
    }
    
    /// Calculates total monthly income for the current financial period
    func totalMonthlyIncome(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        return subscriptions
            .filter { subscription in
                subscription.status == .upcoming &&
                subscription.isIncome &&
                subscription.date >= period.start &&
                subscription.date < period.end
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
        return subscriptions.filter { subscription in
            subscription.status == .upcoming &&
            subscription.date >= period.start &&
            subscription.date < period.end
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
            
            // CRITICAL: Always include first occurrence on startDate
            // The first occurrence is special - always show it if it's within the generation window
            // even if it's slightly in the past (up to 30 days), as it's the user's chosen start date
            let startDateStart = calendar.startOfDay(for: startDate)
            let todayStart = calendar.startOfDay(for: today)
            let actualEndDateStart = calendar.startOfDay(for: actualEndDate)
            
            // Check if startDate is skipped
            let isStartDateSkipped = skippedDates.contains { skippedDate in
                calendar.isDate(startDateStart, inSameDayAs: skippedDate)
            }
            
            // CRITICAL: The first occurrence is the user's chosen start date
            // ALWAYS include it if:
            // 1. It's not skipped
            // 2. It's within the endDate range (not terminated)
            // We don't check if it's today/future/past - the first occurrence is special
            // If the user chose November 30th as the start date, it should ALWAYS appear
            let isWithinEndDate = startDateStart <= actualEndDateStart
            
            // Always include the first occurrence - it's the user's explicit choice
            // This ensures November 30th (or any start date) always shows
            if !isStartDateSkipped && isWithinEndDate {
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
            
            // Generate subsequent occurrences: startDate + interval, startDate + 2×interval, etc.
            var currentDate = calculateNextDate(
                from: startDate,
                frequency: frequency,
                interval: interval,
                weekdays: weekdays
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
                
                // Only include today and future dates that are not skipped (use startOfDay for consistent comparison)
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
                
                // Calculate next date
                let nextDate = calculateNextDate(
                    from: currentDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays
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
    private func calculateNextDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        switch frequency {
        case .day:
            var nextDate = calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            if nextDate <= today {
                // Find next date in the future
                while nextDate <= today {
                    if let date = calendar.date(byAdding: .day, value: interval, to: nextDate) {
                        nextDate = date
                    } else {
                        break
                    }
                }
            }
            return nextDate
            
        case .week:
            if !weekdays.isEmpty {
                // Find next matching weekday
                var candidate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                var attempts = 0
                while attempts < 7 {
                    let weekday = calendar.component(.weekday, from: candidate)
                    let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
                    if weekdays.contains(adjustedWeekday) && candidate > today {
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
                if nextDate <= today {
                    nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: nextDate) ?? nextDate
                }
                return nextDate
            }
            
        case .month:
            var nextDate = calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
            // Preserve day of month, handle end-of-month edge cases
            if let day = calendar.dateComponents([.day], from: startDate).day {
                var components = calendar.dateComponents([.year, .month], from: nextDate)
                components.day = min(day, calendar.range(of: .day, in: .month, for: nextDate)?.count ?? day)
                nextDate = calendar.date(from: components) ?? nextDate
            }
            if nextDate <= today {
                nextDate = calendar.date(byAdding: .month, value: interval, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .year:
            var nextDate = calendar.date(byAdding: .year, value: interval, to: startDate) ?? startDate
            if nextDate <= today {
                nextDate = calendar.date(byAdding: .year, value: interval, to: nextDate) ?? nextDate
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

