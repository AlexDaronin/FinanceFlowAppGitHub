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
        // Note: cleanupAllSubscriptionTransactions was removed from TransactionManager
        // This function is kept for compatibility but does nothing
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
        let periodStart = calendar.startOfDay(for: period.start)
        let periodEnd = calendar.startOfDay(for: period.end)
        
        var total: Double = 0
        
        for subscription in subscriptions {
            // 1. Basic checks (Status, Type)
            guard subscription.status == .upcoming,
                  !subscription.isIncome else {
                continue
            }
            
            // 2. Check Termination (Delete All Future)
            // If subscription has been terminated before the period, skip it
            if let endDate = subscription.endDate {
                let endDateStart = calendar.startOfDay(for: endDate)
                if endDateStart < periodStart {
                    continue // Subscription ended before this period
                }
            }
            
            // 3. For repeating subscriptions, calculate occurrences in the period
            if subscription.isRepeating {
                guard let frequencyString = subscription.repetitionFrequency,
                      let frequency = RepetitionFrequency(rawValue: frequencyString),
                      let interval = subscription.repetitionInterval else {
                    continue
                }
                
                let startDate = subscription.date
                let weekdays = subscription.selectedWeekdays.map { Set($0) } ?? []
                let skippedDates = subscription.skippedDates ?? []
                let subscriptionEndDate = subscription.endDate
                
                // Determine actual end date for generation
                // Use subscription's endDate if set, otherwise generate up to period end
                // But we need to generate at least up to period end to catch all occurrences in the period
                let generateEndDate = subscriptionEndDate ?? periodEnd
                let actualEndDateStart = subscriptionEndDate != nil ? calendar.startOfDay(for: subscriptionEndDate!) : periodEnd
                
                // Count occurrences that fall within the period
                var currentDate = startDate
                let originalDay = calendar.component(.day, from: startDate)
                var iterationCount = 0
                let maxIterations = 1000
                
                // Check if start date is in period and not skipped
                let startDateStart = calendar.startOfDay(for: startDate)
                if startDateStart >= periodStart && startDateStart < periodEnd {
                    let isStartDateSkipped = skippedDates.contains { skippedDate in
                        calendar.isDate(startDateStart, inSameDayAs: skippedDate)
                    }
                    if !isStartDateSkipped && startDateStart <= actualEndDateStart {
                        total += subscription.amount
                    }
                }
                
                // Generate subsequent occurrences
                currentDate = calculateNextDate(
                    from: startDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays,
                    originalDay: originalDay
                )
                
                // Count occurrences in the period
                while currentDate <= generateEndDate && iterationCount < maxIterations {
                    iterationCount += 1
                    
                    let currentDateStart = calendar.startOfDay(for: currentDate)
                    
                    // Check if this date is in the period
                    if currentDateStart >= periodStart && currentDateStart < periodEnd {
                        // Check if this date is skipped
                        let isSkipped = skippedDates.contains { skippedDate in
                            calendar.isDate(currentDateStart, inSameDayAs: skippedDate)
                        }
                        
                        if !isSkipped {
                            total += subscription.amount
                        }
                    }
                    
                    // Calculate next date
                    let nextDate = calculateNextDate(
                        from: currentDate,
                        frequency: frequency,
                        interval: interval,
                        weekdays: weekdays,
                        originalDay: originalDay
                    )
                    
                    if nextDate <= currentDate || nextDate > generateEndDate {
                        break
                    }
                    
                    currentDate = nextDate
                }
            } else {
                // Non-repeating subscription - only count if date is in period
                let subscriptionDateStart = calendar.startOfDay(for: subscription.date)
                if subscriptionDateStart >= periodStart && subscriptionDateStart < periodEnd {
                    // Check if skipped
                    let isSkipped = subscription.skippedDates?.contains { skippedDate in
                        calendar.isDate(subscriptionDateStart, inSameDayAs: skippedDate)
                    } ?? false
                    
                    if !isSkipped {
                        total += subscription.amount
                    }
                }
            }
        }
        
        return total
    }
    
    /// Calculates total monthly income for the current financial period
    func totalMonthlyIncome(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        let calendar = Calendar.current
        let periodStart = calendar.startOfDay(for: period.start)
        let periodEnd = calendar.startOfDay(for: period.end)
        
        var total: Double = 0
        
        for subscription in subscriptions {
            // 1. Basic checks (Status, Type)
            guard subscription.status == .upcoming,
                  subscription.isIncome else {
                continue
            }
            
            // 2. Check Termination (Delete All Future)
            // If subscription has been terminated before the period, skip it
            if let endDate = subscription.endDate {
                let endDateStart = calendar.startOfDay(for: endDate)
                if endDateStart < periodStart {
                    continue // Subscription ended before this period
                }
            }
            
            // 3. For repeating subscriptions, calculate occurrences in the period
            if subscription.isRepeating {
                guard let frequencyString = subscription.repetitionFrequency,
                      let frequency = RepetitionFrequency(rawValue: frequencyString),
                      let interval = subscription.repetitionInterval else {
                    continue
                }
                
                let startDate = subscription.date
                let weekdays = subscription.selectedWeekdays.map { Set($0) } ?? []
                let skippedDates = subscription.skippedDates ?? []
                let subscriptionEndDate = subscription.endDate
                
                // Determine actual end date for generation
                // Use subscription's endDate if set, otherwise generate up to period end
                // But we need to generate at least up to period end to catch all occurrences in the period
                let generateEndDate = subscriptionEndDate ?? periodEnd
                let actualEndDateStart = subscriptionEndDate != nil ? calendar.startOfDay(for: subscriptionEndDate!) : periodEnd
                
                // Count occurrences that fall within the period
                var currentDate = startDate
                let originalDay = calendar.component(.day, from: startDate)
                var iterationCount = 0
                let maxIterations = 1000
                
                // Check if start date is in period and not skipped
                let startDateStart = calendar.startOfDay(for: startDate)
                if startDateStart >= periodStart && startDateStart < periodEnd {
                    let isStartDateSkipped = skippedDates.contains { skippedDate in
                        calendar.isDate(startDateStart, inSameDayAs: skippedDate)
                    }
                    if !isStartDateSkipped && startDateStart <= actualEndDateStart {
                        total += subscription.amount
                    }
                }
                
                // Generate subsequent occurrences
                currentDate = calculateNextDate(
                    from: startDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays,
                    originalDay: originalDay
                )
                
                // Count occurrences in the period
                while currentDate <= generateEndDate && iterationCount < maxIterations {
                    iterationCount += 1
                    
                    let currentDateStart = calendar.startOfDay(for: currentDate)
                    
                    // Check if this date is in the period
                    if currentDateStart >= periodStart && currentDateStart < periodEnd {
                        // Check if this date is skipped
                        let isSkipped = skippedDates.contains { skippedDate in
                            calendar.isDate(currentDateStart, inSameDayAs: skippedDate)
                        }
                        
                        if !isSkipped {
                            total += subscription.amount
                        }
                    }
                    
                    // Calculate next date
                    let nextDate = calculateNextDate(
                        from: currentDate,
                        frequency: frequency,
                        interval: interval,
                        weekdays: weekdays,
                        originalDay: originalDay
                    )
                    
                    if nextDate <= currentDate || nextDate > generateEndDate {
                        break
                    }
                    
                    currentDate = nextDate
                }
            } else {
                // Non-repeating subscription - only count if date is in period
                let subscriptionDateStart = calendar.startOfDay(for: subscription.date)
                if subscriptionDateStart >= periodStart && subscriptionDateStart < periodEnd {
                    // Check if skipped
                    let isSkipped = subscription.skippedDates?.contains { skippedDate in
                        calendar.isDate(subscriptionDateStart, inSameDayAs: skippedDate)
                    } ?? false
                    
                    if !isSkipped {
                        total += subscription.amount
                    }
                }
            }
        }
        
        return total
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
    /// CRITICAL FIX: Only count subscriptions that have actual occurrences in the period
    func activeSubscriptionsCount(startDay: Int) -> Int {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        let calendar = Calendar.current
        let periodStart = calendar.startOfDay(for: period.start)
        let periodEnd = calendar.startOfDay(for: period.end)
        
        var activeCount = 0
        
        for subscription in subscriptions {
            // 1. Basic checks (Status)
            guard subscription.status == .upcoming else {
                continue
            }
            
            // 2. Check Termination (Delete All Future)
            // If subscription has been terminated before the period, skip it
            if let endDate = subscription.endDate {
                let endDateStart = calendar.startOfDay(for: endDate)
                if endDateStart < periodStart {
                    continue // Subscription ended before this period
                }
            }
            
            // 3. For repeating subscriptions, check if there are any occurrences in the period
            if subscription.isRepeating {
                guard let frequencyString = subscription.repetitionFrequency,
                      let frequency = RepetitionFrequency(rawValue: frequencyString),
                      let interval = subscription.repetitionInterval else {
                    continue
                }
                
                let startDate = subscription.date
                let weekdays = subscription.selectedWeekdays.map { Set($0) } ?? []
                let skippedDates = subscription.skippedDates ?? []
                let subscriptionEndDate = subscription.endDate
                
                // Determine actual end date for generation
                let generateEndDate = subscriptionEndDate ?? periodEnd
                let actualEndDateStart = subscriptionEndDate != nil ? calendar.startOfDay(for: subscriptionEndDate!) : periodEnd
                
                var hasOccurrenceInPeriod = false
                var currentDate = startDate
                let originalDay = calendar.component(.day, from: startDate)
                var iterationCount = 0
                let maxIterations = 1000
                
                // Check if start date is in period and not skipped
                let startDateStart = calendar.startOfDay(for: startDate)
                if startDateStart >= periodStart && startDateStart < periodEnd {
                    let isStartDateSkipped = skippedDates.contains { skippedDate in
                        calendar.isDate(startDateStart, inSameDayAs: skippedDate)
                    }
                    if !isStartDateSkipped && startDateStart <= actualEndDateStart {
                        hasOccurrenceInPeriod = true
                    }
                }
                
                // If not found yet, check subsequent occurrences
                if !hasOccurrenceInPeriod {
                    currentDate = calculateNextDate(
                        from: startDate,
                        frequency: frequency,
                        interval: interval,
                        weekdays: weekdays,
                        originalDay: originalDay
                    )
                    
                    while currentDate <= generateEndDate && iterationCount < maxIterations && !hasOccurrenceInPeriod {
                        iterationCount += 1
                        
                        let currentDateStart = calendar.startOfDay(for: currentDate)
                        
                        // Check if this date is in the period
                        if currentDateStart >= periodStart && currentDateStart < periodEnd {
                            // Check if this date is skipped
                            let isSkipped = skippedDates.contains { skippedDate in
                                calendar.isDate(currentDateStart, inSameDayAs: skippedDate)
                            }
                            
                            if !isSkipped {
                                hasOccurrenceInPeriod = true
                                break
                            }
                        }
                        
                        // Calculate next date
                        let nextDate = calculateNextDate(
                            from: currentDate,
                            frequency: frequency,
                            interval: interval,
                            weekdays: weekdays,
                            originalDay: originalDay
                        )
                        
                        if nextDate <= currentDate || nextDate > generateEndDate {
                            break
                        }
                        
                        currentDate = nextDate
                    }
                }
                
                if hasOccurrenceInPeriod {
                    activeCount += 1
                }
            } else {
                // Non-repeating subscription - only count if date is in period
                let subscriptionDateStart = calendar.startOfDay(for: subscription.date)
                if subscriptionDateStart >= periodStart && subscriptionDateStart < periodEnd {
                    // Check if skipped
                    let isSkipped = subscription.skippedDates?.contains { skippedDate in
                        calendar.isDate(subscriptionDateStart, inSameDayAs: skippedDate)
                    } ?? false
                    
                    if !isSkipped {
                        activeCount += 1
                    }
                }
            }
        }
        
        return activeCount
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
    ///   - creditManager: The credit manager to update linked credit balance
    ///   - accountManager: The account manager to update account balances
    ///   - currency: The currency code for the transaction
    func payEarly(subscription: PlannedPayment, occurrenceDate: Date, transactionManager: TransactionManager, creditManager: CreditManager, accountManager: AccountManager, currency: String = "USD") {
        // Determine transaction type: if toAccountName is present, it's a transfer
        let transactionType: TransactionType
        if let toAccountName = subscription.toAccountName, !toAccountName.isEmpty {
            transactionType = .transfer
        } else {
            transactionType = subscription.isIncome ? .income : .expense
        }
        
        // Create a new standalone transaction with today's date
        // Do not link it to a source payment ID; treat it as a standalone transaction
        let newTransaction = Transaction(
            id: UUID(),
            title: subscription.title,
            category: subscription.category ?? "General",
            amount: subscription.amount,
            date: Date(), // Pay now, not on the scheduled date
            type: transactionType,
            accountName: subscription.accountName,
            toAccountName: subscription.toAccountName,
            currency: currency,
            sourcePlannedPaymentId: nil, // Standalone transaction, not linked to subscription
            occurrenceDate: nil // Standalone transaction, no occurrence date
        )
        
        // Update account balances
        // 1. Source Account: Update subscription.accountName based on transaction type
        if let sourceAccount = accountManager.getAccount(name: subscription.accountName) {
            var updatedSourceAccount = sourceAccount
            if transactionType == .transfer {
                // Transfer: subtract from source account
                updatedSourceAccount.balance -= subscription.amount
            } else if transactionType == .income {
                // Income: add to source account
                updatedSourceAccount.balance += subscription.amount
            } else {
                // Expense: subtract from source account
                updatedSourceAccount.balance -= subscription.amount
            }
            accountManager.updateAccount(updatedSourceAccount)
        }
        
        // 2. Destination Account: Add to destination if it's a transfer or has linkedCreditId
        if transactionType == .transfer, let toAccountName = subscription.toAccountName {
            // Transfer: add to destination account (reducing negative debt for credit accounts)
            if let destinationAccount = accountManager.getAccount(name: toAccountName) {
                var updatedDestinationAccount = destinationAccount
                updatedDestinationAccount.balance += subscription.amount
                accountManager.updateAccount(updatedDestinationAccount)
            }
        } else if let linkedCreditId = subscription.linkedCreditId {
            // If linked to a credit (even if not explicitly a transfer), find the credit's linked account and add to it
            // This handles cases where a subscription payment is linked to a credit account
            if let credit = creditManager.credits.first(where: { $0.id == linkedCreditId }),
               let linkedAccountId = credit.linkedAccountId,
               let destinationAccount = accountManager.getAccount(id: linkedAccountId) {
                var updatedDestinationAccount = destinationAccount
                updatedDestinationAccount.balance += subscription.amount
                accountManager.updateAccount(updatedDestinationAccount)
            }
        }
        
        // Add the transaction to TransactionManager
        transactionManager.addTransaction(newTransaction)
        
        // If subscription is linked to a credit, update the credit balance
        // Note: For transfers to credit accounts, the Account balance is already updated by TransactionManager
        // We still need to sync the Credit model's remaining/paid values
        if let linkedCreditId = subscription.linkedCreditId {
            // Update credit balance without creating a duplicate transaction
            // (transaction was already created above)
            // For transfers, we need to sync from Account balance instead
            if transactionType == .transfer, let toAccountName = subscription.toAccountName {
                // Find credit by linked account name
                if let credit = creditManager.credits.first(where: { credit in
                    if let linkedAccountId = credit.linkedAccountId,
                       let account = accountManager.getAccount(id: linkedAccountId),
                       account.name == toAccountName {
                        return true
                    }
                    return false
                }) {
                    // Sync credit from account balance (account balance was updated by TransactionManager)
                    creditManager.syncCreditFromAccount(creditId: credit.id, accountManager: accountManager)
                }
            } else {
                creditManager.updateCreditBalance(creditId: linkedCreditId, paymentAmount: subscription.amount, accountManager: accountManager)
            }
        } else if transactionType == .transfer, let toAccountName = subscription.toAccountName {
            // Even if not explicitly linked, check if transfer is to a credit account
            if let toAccount = accountManager.getAccount(name: toAccountName),
               toAccount.accountType == .credit,
               let credit = creditManager.credits.first(where: { $0.linkedAccountId == toAccount.id }) {
                // Sync credit from account balance
                creditManager.syncCreditFromAccount(creditId: credit.id, accountManager: accountManager)
            }
        }
        
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
                toAccountName: payment.toAccountName,
                category: payment.category,
                type: payment.type,
                isIncome: payment.isIncome,
                totalLoanAmount: payment.totalLoanAmount,
                remainingBalance: payment.remainingBalance,
                startDate: payment.startDate,
                interestRate: payment.interestRate,
                linkedCreditId: payment.linkedCreditId,
                isRepeating: payment.isRepeating,
                repetitionFrequency: payment.repetitionFrequency,
                repetitionInterval: payment.repetitionInterval,
                selectedWeekdays: payment.selectedWeekdays,
                skippedDates: existingSkippedDates,
                endDate: payment.endDate
            )
            
            subscriptions[index] = updatedPayment
            saveData()
            generateUpcomingTransactions() // Regenerate after skipping
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
            toAccountName: payment.toAccountName,
            category: payment.category,
            type: payment.type,
            isIncome: payment.isIncome,
            totalLoanAmount: payment.totalLoanAmount,
            remainingBalance: payment.remainingBalance,
            startDate: payment.startDate,
            interestRate: payment.interestRate,
            linkedCreditId: payment.linkedCreditId,
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
            
            // CRITICAL FIX: Track dates we've already added to prevent duplicates
            var addedDates: Set<String> = []
            
            // Helper to check and add a transaction for a specific date
            func addTransactionIfNeeded(for date: Date, isFirstOccurrence: Bool = false) {
                let dateStart = calendar.startOfDay(for: date)
                let dateKey = ISO8601DateFormatter().string(from: dateStart)
                
                // Skip if we've already added this date
                if addedDates.contains(dateKey) {
                    return
                }
                
                // Check if this date is skipped
                let isSkipped = skippedDates.contains { skippedDate in
                    calendar.isDate(dateStart, inSameDayAs: skippedDate)
                }
                
                if isSkipped {
                    return
                }
                
                // Check if date is within end date
                if dateStart > actualEndDateStart {
                    return
                }
                
                // For first occurrence: include if today/future OR recent past (90 days)
                // For subsequent occurrences: only include if today/future
                let ninetyDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -90, to: today) ?? today)
                let isTodayOrFuture = dateStart >= todayStart
                let isRecentPast = dateStart >= ninetyDaysAgo && dateStart < todayStart
                
                let shouldInclude = isFirstOccurrence ? (isTodayOrFuture || isRecentPast) : isTodayOrFuture
                
                if shouldInclude {
                    let transaction = Transaction(
                        id: Self.generateOccurrenceId(subscriptionId: subscription.id, occurrenceDate: date),
                        title: subscription.title,
                        category: subscription.category ?? "General",
                        amount: subscription.amount,
                        date: date,
                        type: subscription.isIncome ? .income : .expense,
                        accountName: subscription.accountName,
                        toAccountName: nil,
                        currency: UserDefaults.standard.string(forKey: "mainCurrency") ?? "USD",
                        sourcePlannedPaymentId: subscription.id,
                        occurrenceDate: date
                    )
                    allTransactions.append(transaction)
                    addedDates.insert(dateKey)
                }
            }
            
            // Add first occurrence (startDate)
            addTransactionIfNeeded(for: startDate, isFirstOccurrence: true)
            
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
                
                // Add transaction for current date (will check for duplicates internally)
                addTransactionIfNeeded(for: currentDate, isFirstOccurrence: false)
                
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
        
        // CRITICAL FIX: Remove any remaining duplicates by ID (defensive programming)
        // Group by ID and keep only the first occurrence
        var seenIds: Set<UUID> = []
        var uniqueTransactions: [Transaction] = []
        for transaction in allTransactions {
            if !seenIds.contains(transaction.id) {
                uniqueTransactions.append(transaction)
                seenIds.insert(transaction.id)
            }
        }
        
        // Sort by date and update published property on main thread
        // CRITICAL: Always update on main thread to ensure UI refreshes
        let sortedTransactions = uniqueTransactions.sorted { $0.date < $1.date }
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
    /// CRITICAL FIX: Uses deterministic hashing instead of non-deterministic Hasher()
    static func generateOccurrenceId(subscriptionId: UUID, occurrenceDate: Date) -> UUID {
        let calendar = Calendar.current
        let dateOnly = calendar.startOfDay(for: occurrenceDate)
        let dateString = ISO8601DateFormatter().string(from: dateOnly)
        let combinedString = "\(subscriptionId.uuidString)-\(dateString)"
        
        // CRITICAL FIX: Use deterministic hash function
        // Hasher() is NOT deterministic (uses random seed), which breaks SwiftUI's identity tracking
        // Use a simple but deterministic hash: djb2 algorithm
        var hash1: UInt64 = 5381
        var hash2: UInt64 = 5381
        for char in combinedString.utf8 {
            hash1 = ((hash1 << 5) &+ hash1) &+ UInt64(char)
        }
        // Second hash for reversed string to get more entropy
        let reversedString = String(combinedString.reversed())
        for char in reversedString.utf8 {
            hash2 = ((hash2 << 5) &+ hash2) &+ UInt64(char)
        }
        
        // Convert hashes to UUID bytes (16 bytes total)
        var bytes = [UInt8](repeating: 0, count: 16)
        
        // First 8 bytes from hash1
        var value = hash1
        for i in 0..<8 {
            bytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        
        // Second 8 bytes from hash2
        value = hash2
        for i in 8..<16 {
            bytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        
        // Set version (4) and variant bits for UUID v4 compatibility
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // Version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // Variant 10
        
        // Format as UUID string
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                               bytes[0], bytes[1], bytes[2], bytes[3],
                               bytes[4], bytes[5],
                               bytes[6], bytes[7],
                               bytes[8], bytes[9],
                               bytes[10], bytes[11],
                               bytes[12], bytes[13], bytes[14], bytes[15])
        
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
