//
//  TransactionsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts
import Combine

struct TransactionsView: View {
    // STEP 0: A/B TEST FLAG for TransactionRow GPU performance
    // Set to true to test fast rendering without clipShape/overlay
    // Set to false to restore original card style
    // To toggle: Change this value and rebuild
    static var USE_FAST_ROW_STYLE = true // Change this to toggle A/B test
    
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var creditManager: CreditManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var debtManager: DebtManager
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedType: TransactionType?
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    @State private var pendingEditMode: TransactionFormMode?
    @State private var editingTransaction: Transaction? // Store the transaction being edited (for scheduled transactions that may not exist in transactionManager)
    @State private var scrollOffset: CGFloat = 0
    @State private var showPlannedPayments = false
    @State private var selectedTab: TransactionTab = .past
    @State private var selectedPlannedPayment: PlannedPayment? // For editing scheduled transactions
    @State private var selectedOccurrenceDate: Date? // The specific occurrence date when paying early
    @State private var scheduledTransactionToDelete: Transaction? // For delete confirmation
    @State private var plannedPaymentToDeleteFromEdit: PlannedPayment? // For delete confirmation from edit form
    @State private var showDeleteScheduledAlert = false
    @State private var deleteMode: DeleteMode = .single
    
    // Кэшируемые состояния для оптимизации производительности
    @State private var cachedFilteredTransactions: [Transaction] = []
    @State private var cachedFutureTransactions: [Transaction] = []
    @State private var cachedMissedTransactions: [Transaction] = []
    @State private var cachedGroupedTransactions: [(date: Date, transactions: [Transaction])] = []
    @State private var cachedGroupedFutureTransactions: [(date: Date, transactions: [Transaction])] = []
    @State private var cachedGroupedMissedTransactions: [(date: Date, transactions: [Transaction])] = []
    @State private var cachedCategories: [String] = []
    @State private var lastTransactionCount: Int = 0
    @State private var lastSearchText: String = ""
    @State private var lastSelectedCategory: String? = nil
    @State private var lastSelectedType: TransactionType? = nil
    // Кэш для isScheduledToday флагов (чтобы не вычислять в label)
    @State private var scheduledTodayCache: [UUID: Bool] = [:]
    // Кэш для account names и category icons (чтобы не вычислять в TransactionRow)
    @State private var cachedAccountNames: [UUID: String] = [:]
    @State private var cachedCategoryIcons: [UUID: String] = [:]
    
    private var debounceTask: Task<Void, Never>?
    
    enum DeleteMode {
        case single
        case all
    }
    
    // Computed property теперь использует кэш
    private var categories: [String] {
        cachedCategories
    }
    
    private var upcomingPayments: [PlannedPayment] {
        subscriptionManager.subscriptions.filter { $0.date > Date() && $0.status == .upcoming }
    }
    
    private var missedPayments: [PlannedPayment] {
        subscriptionManager.subscriptions.filter { $0.date <= Date() && $0.status == .past }
    }
    
    // Generate all occurrences (including past dates) for missed transactions
    private func generateAllOccurrences(
        from payment: PlannedPayment,
        endDate: Date
    ) -> [Transaction] {
        guard payment.isRepeating,
              let frequencyString = payment.repetitionFrequency,
              let frequency = RepetitionFrequency(rawValue: frequencyString),
              let interval = payment.repetitionInterval else {
            // Not repeating, return empty
            return []
        }
        
        var occurrences: [Transaction] = []
        let calendar = Calendar.current
        let startDate = payment.date
        let weekdays = payment.selectedWeekdays ?? []
        
        // Get skipped dates and end date
        let skippedDates = payment.skippedDates ?? []
        let paymentEndDate = payment.endDate
        
        // Determine the actual end date (use payment's endDate if set, otherwise use the provided endDate)
        let actualEndDate = paymentEndDate ?? endDate
        let actualEndDateStart = calendar.startOfDay(for: actualEndDate)
        
        // Include first occurrence if it's not skipped and within the endDate range
        let startDateStart = calendar.startOfDay(for: startDate)
        let isStartDateSkipped = skippedDates.contains { skippedDate in
            Calendar.current.isDate(startDateStart, inSameDayAs: skippedDate)
        }
        
        if !isStartDateSkipped && startDateStart <= actualEndDateStart {
            let transaction = Transaction(
                id: UUID(),
                title: payment.title,
                category: payment.category ?? "General",
                amount: payment.amount,
                date: startDate,
                type: payment.isIncome ? .income : .expense,
                accountId: payment.accountId,
                toAccountId: nil,
                currency: settings.currency,
                sourcePlannedPaymentId: payment.id,
                occurrenceDate: startDate
            )
            occurrences.append(transaction)
        }
        
        // Generate subsequent occurrences
        var currentDate = calculateNextOccurrenceDate(
            from: startDate,
            frequency: frequency,
            interval: interval,
            weekdays: Set(weekdays)
        )
        
        var iterationCount = 0
        let maxIterations = 1000
        
        // Generate occurrences until we reach end date (including past dates)
        while currentDate <= actualEndDate && iterationCount < maxIterations {
            iterationCount += 1
            
            // Check if this date is skipped
            let isSkipped = skippedDates.contains { skippedDate in
                Calendar.current.isDate(currentDate, inSameDayAs: skippedDate)
            }
            
            // Include occurrences that are not skipped and within the endDate range
            let currentDateStart = calendar.startOfDay(for: currentDate)
            if !isSkipped && currentDateStart <= actualEndDateStart {
                let transaction = Transaction(
                    id: UUID(),
                    title: payment.title,
                    category: payment.category ?? "General",
                    amount: payment.amount,
                    date: currentDate,
                    type: payment.isIncome ? .income : .expense,
                    accountId: payment.accountId,
                    toAccountId: nil,
                    currency: settings.currency,
                    sourcePlannedPaymentId: payment.id,
                    occurrenceDate: currentDate
                )
                occurrences.append(transaction)
            }
            
            // Calculate next date
            let nextDate = calculateNextOccurrenceDate(
                from: currentDate,
                frequency: frequency,
                interval: interval,
                weekdays: Set(weekdays)
            )
            
            // Stop if next date would exceed endDate or if we can't progress
            if nextDate <= currentDate || nextDate > actualEndDate {
                break
            }
            
            currentDate = nextDate
        }
        
        return occurrences
    }
    
    // Calculate next occurrence date (for generating all occurrences including past dates)
    private func calculateNextOccurrenceDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        
        switch frequency {
        case .day:
            return calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            
        case .week:
            if !weekdays.isEmpty {
                var checkDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                let maxDaysToCheck = 14
                var daysChecked = 0
                
                while daysChecked < maxDaysToCheck {
                    let checkWeekday = calendar.component(.weekday, from: checkDate)
                    let adjustedCheckWeekday = checkWeekday == 1 ? 7 : checkWeekday - 1
                    
                    if weekdays.contains(adjustedCheckWeekday) {
                        if interval > 1 {
                            return calendar.date(byAdding: .weekOfYear, value: interval - 1, to: checkDate) ?? checkDate
                        }
                        return checkDate
                    }
                    
                    checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
                    daysChecked += 1
                }
                
                return calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
            } else {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
            }
            
        case .month:
            return calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
            
        case .year:
            return calendar.date(byAdding: .year, value: interval, to: startDate) ?? startDate
        }
    }
    
    // Missed transactions - transactions that should have been paid but weren't (использует кэш)
    private var missedTransactions: [Transaction] {
        cachedMissedTransactions
    }
    
    // Вычисление missed transactions (вызывается только при необходимости)
    private func calculateMissedTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var missed: [Transaction] = []
        
        // Get all subscriptions with dates in the past
        let pastSubscriptions = subscriptionManager.subscriptions.filter { payment in
            let paymentDate = calendar.startOfDay(for: payment.date)
            return paymentDate <= today
        }
        
        for payment in pastSubscriptions {
            if payment.isRepeating {
                // For repeating payments, check all occurrences that should have been paid
                guard let frequencyString = payment.repetitionFrequency,
                      let _ = RepetitionFrequency(rawValue: frequencyString),
                      let _ = payment.repetitionInterval else {
                    continue
                }
                
                // Generate all occurrences up to today (including past dates)
                let occurrences = generateAllOccurrences(from: payment, endDate: today)
                
                // For each occurrence that should have been paid (date < today, not today)
                // Today's scheduled transactions appear in "Today" tab, not in "Missed"
                for occurrence in occurrences {
                    let occurrenceDate = calendar.startOfDay(for: occurrence.date)
                    // Only show as missed if date is in the past (not today)
                    if occurrenceDate < today {
                        // Check if there's a paid transaction (sourcePlannedPaymentId = nil) for this occurrence
                        // A paid transaction is one that was manually created/paid (sourcePlannedPaymentId = nil)
                        // and matches this payment (same title, amount, account, and date around the occurrence date)
                        let hasPaidTransaction = transactionManager.transactions.contains { transaction in
                            // Only consider transactions that were actually paid (sourcePlannedPaymentId = nil)
                            guard transaction.sourcePlannedPaymentId == nil else { return false }
                            
                            let transactionDate = calendar.startOfDay(for: transaction.date)
                            // Check if it matches this payment (same title, amount, account)
                            // Allow some flexibility in the date (within a few days) to account for late payments
                            let dateDifference = abs(calendar.dateComponents([.day], from: occurrenceDate, to: transactionDate).day ?? 0)
                            
                            return transaction.title == payment.title &&
                                   abs(transaction.amount - payment.amount) < 0.01 &&
                                   transaction.accountId == payment.accountId &&
                                   transaction.type == (payment.isIncome ? .income : .expense) &&
                                   transactionDate <= today &&
                                   dateDifference <= 30 // Allow payments within 30 days of the due date
                        }
                        
                        // If there's no paid transaction, this occurrence is missed
                        // (even if there's a scheduled transaction, it's still missed because it wasn't paid)
                        if !hasPaidTransaction {
                            missed.append(occurrence)
                        }
                    }
                }
            } else {
                // For non-repeating payments, check if there's a paid transaction
                let paymentDate = calendar.startOfDay(for: payment.date)
                // Only show as missed if payment date is in the past (not today)
                if paymentDate < today {
                    // Check if there's a paid transaction (sourcePlannedPaymentId = nil) for this payment
                    let hasPaidTransaction = transactionManager.transactions.contains { transaction in
                        // Only consider transactions that were actually paid (sourcePlannedPaymentId = nil)
                        guard transaction.sourcePlannedPaymentId == nil else { return false }
                        
                        let transactionDate = calendar.startOfDay(for: transaction.date)
                        // Check if it matches this payment (same title, amount, account)
                        // Allow some flexibility in the date (within a few days) to account for late payments
                        let dateDifference = abs(calendar.dateComponents([.day], from: paymentDate, to: transactionDate).day ?? 0)
                        
                        return transaction.title == payment.title &&
                               abs(transaction.amount - payment.amount) < 0.01 &&
                               transaction.accountId == payment.accountId &&
                               transaction.type == (payment.isIncome ? .income : .expense) &&
                               transactionDate <= today &&
                               dateDifference <= 30 // Allow payments within 30 days of the due date
                    }
                    
                    // Check if there's a scheduled transaction that hasn't been paid
                    let _ = transactionManager.transactions.contains { transaction in
                        guard transaction.sourcePlannedPaymentId == payment.id else { return false }
                        let transactionDate = calendar.startOfDay(for: transaction.date)
                        return calendar.isDate(transactionDate, inSameDayAs: paymentDate)
                    }
                    
                    // If no paid transaction exists, create a missed transaction
                    // (even if there's a scheduled transaction, it's still missed because it wasn't paid)
                    if !hasPaidTransaction {
                        let transactionType: TransactionType
                        if payment.toAccountId != nil {
                            transactionType = .transfer
                        } else {
                            transactionType = payment.isIncome ? .income : .expense
                        }
                        
                        let missedTransaction = Transaction(
                            title: payment.title,
                            category: payment.category ?? "General",
                            amount: payment.amount,
                            date: payment.date,
                            type: transactionType,
                            accountId: payment.accountId,
                            toAccountId: payment.toAccountId,
                            currency: settings.currency,
                            sourcePlannedPaymentId: payment.id,
                            occurrenceDate: payment.date
                        )
                        missed.append(missedTransaction)
                    }
                }
            }
        }
        
        // Filter by search, category, and type
        let filtered = missed.filter { transaction in
            let accountName = transaction.accountName(accountManager: accountManager)
            let matchesSearch = searchText.isEmpty ||
            transaction.title.localizedCaseInsensitiveContains(searchText) ||
            transaction.category.localizedCaseInsensitiveContains(searchText) ||
            accountName.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || transaction.category == selectedCategory
            let matchesType = selectedType == nil || transaction.type == selectedType
            return matchesSearch && matchesCategory && matchesType
        }
        .sorted { $0.date < $1.date }
        
        return filtered
    }
    
    // Group missed transactions by day (использует кэш)
    private var groupedMissedTransactions: [(date: Date, transactions: [Transaction])] {
        cachedGroupedMissedTransactions
    }
    
    // Используем кэшированные значения вместо пересчета на каждый рендер
    private var filteredTransactions: [Transaction] {
        cachedFilteredTransactions
    }
    
    private var futureTransactions: [Transaction] {
        cachedFutureTransactions
    }
    
    private var groupedFutureTransactions: [(date: Date, transactions: [Transaction])] {
        cachedGroupedFutureTransactions
    }
    
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        cachedGroupedTransactions
    }
    
    // Функция для обновления кэша с debounce
    private func updateCachedData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let transactions = transactionManager.transactions
        
        // Предварительно вычисляем account names и category icons для всех транзакций (один раз)
        let accountNameCache = Dictionary(
            uniqueKeysWithValues: transactions.map { transaction in
                (transaction.id, transaction.accountName(accountManager: accountManager))
            }
        )
        
        // Предварительно вычисляем category icons для всех транзакций
        let categoryIconCache = Dictionary(
            uniqueKeysWithValues: transactions.map { transaction in
                let iconName: String
                if transaction.type == .transfer {
                    iconName = "arrow.left.arrow.right"
                } else if transaction.category.contains(" > ") {
                    let parts = transaction.category.split(separator: " > ")
                    let categoryName = String(parts[0])
                    let subcategoryName = String(parts[1])
                    
                    if let category = settings.categories.first(where: { $0.name == categoryName }),
                       let subcategory = category.subcategories.first(where: { $0.name == subcategoryName }) {
                        iconName = subcategory.iconName
                    } else if let category = settings.categories.first(where: { $0.name == categoryName }) {
                        iconName = category.iconName
                    } else {
                        iconName = transaction.type.iconName
                    }
                } else {
                    if let category = settings.categories.first(where: { $0.name == transaction.category }) {
                        iconName = category.iconName
                    } else {
                        iconName = transaction.type.iconName
                    }
                }
                return (transaction.id, iconName)
            }
        )
        
        // Сохраняем кэши для использования в TransactionRow
        // (используем @State переменные для хранения кэшей)
        cachedAccountNames = accountNameCache
        cachedCategoryIcons = categoryIconCache
        
        // Базовый фильтр (применяется один раз)
        let baseFiltered = transactions.filter { transaction in
            let accountName = accountNameCache[transaction.id] ?? ""
            let matchesSearch = searchText.isEmpty ||
                transaction.title.localizedCaseInsensitiveContains(searchText) ||
                transaction.category.localizedCaseInsensitiveContains(searchText) ||
                accountName.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || transaction.category == selectedCategory
            let matchesType = selectedType == nil || transaction.type == selectedType
            return matchesSearch && matchesCategory && matchesType
        }
        
        // Разделяем на прошлые и будущие
        let pastTransactions = baseFiltered.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate <= today
        }.sorted { $0.date > $1.date }
        
        let futureTransactionsFiltered = baseFiltered.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate > today
        }.sorted { $0.date < $1.date }
        
        // Обновляем кэш
        cachedFilteredTransactions = pastTransactions
        cachedFutureTransactions = futureTransactionsFiltered
        
        // Группируем
        let groupedPast = Dictionary(grouping: pastTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        // Предварительно вычисляем isScheduledToday для всех транзакций
        let todayStart = calendar.startOfDay(for: today)
        var newScheduledTodayCache: [UUID: Bool] = [:]
        for transaction in pastTransactions {
            let transactionDate = calendar.startOfDay(for: transaction.date)
            let isScheduledToday = transaction.sourcePlannedPaymentId != nil && transactionDate == todayStart
            newScheduledTodayCache[transaction.id] = isScheduledToday
        }
        scheduledTodayCache = newScheduledTodayCache
        
        cachedGroupedTransactions = groupedPast
            .map { (dayDate: Date, transactions: [Transaction]) in
                let sortedTransactions = transactions.sorted { transaction1, transaction2 in
                    if calendar.isDate(dayDate, inSameDayAs: today) {
                        let isScheduled1 = transaction1.sourcePlannedPaymentId != nil
                        let isScheduled2 = transaction2.sourcePlannedPaymentId != nil
                        if isScheduled1 && !isScheduled2 {
                            return true
                        } else if !isScheduled1 && isScheduled2 {
                            return false
                        }
                    }
                    return transaction1.date > transaction2.date
                }
                return (date: dayDate, transactions: sortedTransactions)
            }
            .sorted { $0.date > $1.date }
        
        let groupedFuture = Dictionary(grouping: futureTransactionsFiltered) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        cachedGroupedFutureTransactions = groupedFuture
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
        
        // Категории
        cachedCategories = Array(Set(transactions.map(\.category))).sorted()
        
        // Missed transactions (вычисляем только если нужно)
        cachedMissedTransactions = calculateMissedTransactions()
        let groupedMissed = Dictionary(grouping: cachedMissedTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        cachedGroupedMissedTransactions = groupedMissed
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
        
        // Обновляем последние значения для проверки изменений
        lastTransactionCount = transactions.count
        lastSearchText = searchText
        lastSelectedCategory = selectedCategory
        lastSelectedType = selectedType
    }
    
    // Group planned payments by day
    private var groupedUpcomingPayments: [(date: Date, payments: [PlannedPayment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: upcomingPayments) { payment in
            calendar.startOfDay(for: payment.date)
        }
        return grouped
            .map { (date: $0.key, payments: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
    
    // Group missed payments by day
    private var groupedMissedPayments: [(date: Date, payments: [PlannedPayment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: missedPayments) { payment in
            calendar.startOfDay(for: payment.date)
        }
        return grouped
            .map { (date: $0.key, payments: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
    
    // Scheduled occurrences - future transactions from subscriptions
    private var scheduledOccurrences: [Transaction] {
        futureTransactions
    }
    
    // Grouped scheduled occurrences by day
    private var groupedScheduledOccurrences: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scheduledOccurrences) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        let sortedDays = grouped.keys.sorted()
        return sortedDays.map { (date: $0, transactions: grouped[$0] ?? []) }
    }
    
    // Planned tab content
    private var plannedTabContent: some View {
        Group {
            if groupedScheduledOccurrences.isEmpty {
                emptyPlannedState
                    .padding()
            } else {
                ForEach(Array(groupedScheduledOccurrences.enumerated()), id: \.element.date) { index, dayGroup in
                    VStack(alignment: .leading, spacing: 12) {
                        // Day Header
                        dayHeader(for: dayGroup.date)
                            .padding(.horizontal, 20)
                            .padding(.top, index == 0 ? 8 : 16)
                            .padding(.bottom, 8)
                        
                        // Scheduled transactions for this day
                        ForEach(dayGroup.transactions, id: \.id) { transaction in
                            Button {
                                // Open subscription form for editing (with Pay Now button)
                                selectedOccurrenceDate = transaction.occurrenceDate ?? transaction.date
                                if let sourcePayment = findSourcePlannedPayment(for: transaction) {
                                    selectedPlannedPayment = sourcePayment
                                }
                            } label: {
                                TransactionRow(
                                    transaction: transaction,
                                    accountName: cachedAccountNames[transaction.id] ?? "Unknown",
                                    categoryIconName: cachedCategoryIcons[transaction.id] ?? transaction.type.iconName
                                )
                                .opacity(0.8)
                            }
                            .buttonStyle(.plain)
                            .id(transaction.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    scheduledTransactionToDelete = transaction
                                    // Set selectedPlannedPayment for context in "Delete All" option
                                    if let sourcePayment = findSourcePlannedPayment(for: transaction) {
                                        selectedPlannedPayment = sourcePayment
                                    }
                                    showDeleteScheduledAlert = true
                                } label: {
                                    Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
    
    // Generate scheduled occurrences for a single PlannedPayment
    private func generateScheduledOccurrences(
        from payment: PlannedPayment,
        endDate: Date
    ) -> [Transaction] {
        guard payment.isRepeating,
              let frequencyString = payment.repetitionFrequency,
              let frequency = RepetitionFrequency(rawValue: frequencyString),
              let interval = payment.repetitionInterval else {
            // Not repeating, return empty
            return []
        }
        
        var occurrences: [Transaction] = []
        let calendar = Calendar.current
        let today = Date()
        let startDate = payment.date
        let weekdays = payment.selectedWeekdays ?? []
        
        // Get skipped dates and end date
        let skippedDates = payment.skippedDates ?? []
        let paymentEndDate = payment.endDate
        
        // Determine the actual end date (use payment's endDate if set, otherwise use the provided endDate)
        let actualEndDate = paymentEndDate ?? endDate
        
        // ISSUE 1 FIX: Always include the first occurrence on the selected date (startDate)
        // Check if startDate should be included
        let startDateStart = calendar.startOfDay(for: startDate)
        let todayStart = calendar.startOfDay(for: today)
        let actualEndDateStart = calendar.startOfDay(for: actualEndDate)
        
        // Check if startDate is skipped
        let isStartDateSkipped = skippedDates.contains { skippedDate in
            Calendar.current.isDate(startDateStart, inSameDayAs: skippedDate)
        }
        
        // Include first occurrence if:
        // 1. It's in the future (or today)
        // 2. It's not skipped
        // 3. It's within the endDate range
        // CRITICAL FIX: Use generateOccurrenceId for stable unique IDs
        // This ensures the same occurrence always has the same ID, even after regeneration
        if startDateStart >= todayStart && !isStartDateSkipped && startDateStart <= actualEndDateStart {
            let transaction = Transaction(
                    id: UUID(), // SubscriptionManager removed
                title: payment.title,
                category: payment.category ?? "General",
                amount: payment.amount,
                date: startDate,
                type: payment.isIncome ? .income : .expense,
                accountId: payment.accountId,
                toAccountId: nil,
                currency: settings.currency,
                sourcePlannedPaymentId: payment.id, // ISSUE 2 FIX: Store source payment ID
                occurrenceDate: startDate // ISSUE 2 FIX: Store occurrence date
            )
            occurrences.append(transaction)
        }
        
        // Now generate subsequent occurrences: startDate + interval, startDate + 2×interval, etc.
        // Start from the first occurrence after startDate
        var currentDate = calculateScheduledNextDate(
            from: startDate,
            frequency: frequency,
            interval: interval,
            weekdays: Set(weekdays)
        )
        
        var iterationCount = 0
        let maxIterations = 1000
        
        // Generate occurrences until we reach end date
        // Note: actualEndDate is set to (selectedDate - 1 day) when "Delete All Future" is used
        // This ensures occurrences with date >= selectedDate are excluded
        while currentDate <= actualEndDate && iterationCount < maxIterations {
            iterationCount += 1
            
            // Check if this date is skipped
            let isSkipped = skippedDates.contains { skippedDate in
                Calendar.current.isDate(currentDate, inSameDayAs: skippedDate)
            }
            
            // Only include occurrences that are in the future and not skipped
            // Also ensure currentDate <= actualEndDate (which excludes date >= selectedDate when endDate is set)
            // CRITICAL FIX: Use startOfDay for consistent date comparisons
            let currentDateStart = calendar.startOfDay(for: currentDate)
            if currentDateStart >= todayStart && !isSkipped && currentDateStart <= actualEndDateStart {
                // Create a transaction for this occurrence
                // CRITICAL FIX: Use generateOccurrenceId for stable unique IDs
                // This ensures the same occurrence always has the same ID, even after regeneration
                let transaction = Transaction(
                    id: UUID(), // SubscriptionManager removed
                    title: payment.title,
                    category: payment.category ?? "General",
                    amount: payment.amount,
                    date: currentDate,
                    type: payment.isIncome ? .income : .expense,
                    accountId: payment.accountId,
                    toAccountId: nil,
                    currency: settings.currency,
                    sourcePlannedPaymentId: payment.id, // ISSUE 2 FIX: Store source payment ID
                    occurrenceDate: currentDate // ISSUE 2 FIX: Store occurrence date
                )
                occurrences.append(transaction)
            }
            
            // Calculate next date
                let nextDate = calculateScheduledNextDate(
                    from: currentDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: Set(weekdays)
                )
            
            // Stop if next date would exceed endDate or if we can't progress
            if nextDate <= currentDate || nextDate > actualEndDate {
                break
            }
            
            currentDate = nextDate
        }
        
        return occurrences
    }
    
    // Calculate next scheduled date (similar to calculateNextDate but for PlannedPayments)
    private func calculateScheduledNextDate(
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
                nextDate = calendar.date(byAdding: .day, value: interval, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .week:
            if !weekdays.isEmpty {
                var checkDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                let maxDaysToCheck = 14
                var daysChecked = 0
                
                while daysChecked < maxDaysToCheck {
                    let checkWeekday = calendar.component(.weekday, from: checkDate)
                    let adjustedCheckWeekday = checkWeekday == 1 ? 7 : checkWeekday - 1
                    
                    if weekdays.contains(adjustedCheckWeekday) {
                        var resultDate = checkDate
                        if interval > 1 {
                            resultDate = calendar.date(byAdding: .weekOfYear, value: interval - 1, to: checkDate) ?? checkDate
                        }
                        if resultDate <= today {
                            resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                        }
                        return resultDate
                    }
                    
                    checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
                    daysChecked += 1
                }
                
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                if resultDate <= today {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            } else {
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                if resultDate <= today {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            }
            
        case .month:
            var nextDate = calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
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
    
    // RepetitionFrequency enum for scheduled calculations
    private enum RepetitionFrequency: String {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    private let actionOptions: [ActionMenuOption] = ActionMenuOption.transactions
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Top anchor for scroll reset
                            Color.clear
                                .frame(height: 0)
                                .id("top")
                            
                            // Tab Buttons
                            tabButtons
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 16)
                            
                            // Planned Payments Section (hidden by default, appears when scrolling up from top)
                            // Only show for past tab
                            if selectedTab == .past && !upcomingPayments.isEmpty {
                                plannedPaymentsSection
                                    .opacity(showPlannedPayments ? 1 : 0)
                                    .frame(height: showPlannedPayments ? nil : 0, alignment: .top)
                                    .clipped()
                                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showPlannedPayments)
                            }
                            
                            // Main Content List
                            VStack(spacing: 0) {
                                if selectedCategory != nil {
                                    resetFilterChip
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .padding(.bottom, 8)
                                }
                                
                                // Show different content based on selected tab
                                tabContent
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Only show planned payments section when on past tab
                        guard selectedTab == .past else {
                            if showPlannedPayments {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    showPlannedPayments = false
                                }
                            }
                            return
                        }
                        
                        // Show when scrolling up from top
                        // Positive offset indicates bounce/overscroll at top (scrolling up)
                        // Negative offset means scrolling down
                        let threshold: CGFloat = 12
                        let shouldShow = value > threshold
                        
                        if shouldShow != showPlannedPayments {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showPlannedPayments = shouldShow
                            }
                        }
                        scrollOffset = value
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        // Hide planned payments section when switching away from past tab
                        if newValue != .past && showPlannedPayments {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showPlannedPayments = false
                            }
                        }
                        
                        // CLEANUP: When Planned (Future) tab is selected, clean up old transactions
                        if newValue == .planned {
                            // SubscriptionManager removed
                        }
                    }
                    .onChange(of: transactionManager.transactions) { oldValue, newValue in
                        // Обновляем кэш только если количество транзакций изменилось или изменились сами транзакции
                        if oldValue.count != newValue.count || 
                           !oldValue.elementsEqual(newValue, by: { $0.id == $1.id }) {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
                                updateCachedData()
                            }
                        }
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce для поиска
                            updateCachedData()
                        }
                    }
                    .onChange(of: selectedCategory) { oldValue, newValue in
                        updateCachedData()
                    }
                    .onChange(of: selectedType) { oldValue, newValue in
                        updateCachedData()
                    }
                    .onAppear {
                        // Reset scroll position when view appears
                        proxy.scrollTo("top", anchor: .top)
                        // Инициализируем кэш при первом появлении
                        updateCachedData()
                        // Ensure future transactions are maintained (12 months ahead)
                        subscriptionManager.ensureFutureTransactions()
                    }
                }
                .background(Color.customBackground)
                .navigationTitle(Text("Transactions", comment: "Transactions view title"))
                .searchable(text: $searchText, prompt: Text("Search transactions", comment: "Search transactions placeholder"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if selectedCategory != nil {
                            Button(String(localized: "Reset", comment: "Reset filter button")) {
                                withAnimation(.easeInOut) {
                                    selectedCategory = nil
                                }
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        categoryMenu
                        typeMenu
                    }
                }
                
                floatingActionButton
            }
            .sheet(isPresented: $showTransactionForm) {
                TransactionFormView(
                    draft: $draftTransaction,
                    mode: currentFormMode,
                    categories: categories,
                    accounts: accountManager.accounts,
                    onSave: { draft in
                        handleSave(draft)
                    },
                    onCancel: {
                        showTransactionForm = false
                        pendingEditMode = nil
                    },
                    onDelete: { id in
                        if let transaction = transactionManager.transactions.first(where: { $0.id == id }) {
                            deleteTransaction(transaction)
                        }
                        showTransactionForm = false
                        pendingEditMode = nil
                    }
                )
                .environmentObject(transactionManager)
                .environmentObject(subscriptionManager)
                .id(currentFormMode) // Force recreation when mode changes
            }
            .sheet(item: $selectedPlannedPayment) { subscription in
                AddSubscriptionFormView(
                    existingPayment: subscription,
                    initialIsIncome: subscription.isIncome,
                    occurrenceDate: selectedOccurrenceDate,
                    onSave: { payment in
                        subscriptionManager.updateSubscription(payment)
                        selectedPlannedPayment = nil
                        selectedOccurrenceDate = nil
                    },
                    onCancel: {
                        selectedPlannedPayment = nil
                        selectedOccurrenceDate = nil
                    },
                    onDeleteSingle: { payment, date in
                        // Find the transaction for this specific date
                        if let transaction = transactionManager.transactions.first(where: { transaction in
                            transaction.sourcePlannedPaymentId == payment.id &&
                            Calendar.current.isDate(transaction.date, inSameDayAs: date)
                        }) {
                            subscriptionManager.deleteSingleOccurrence(transaction: transaction)
                        } else {
                            // If exact match not found, find the closest future transaction
                            if let transaction = transactionManager.transactions
                                .filter({ $0.sourcePlannedPaymentId == payment.id })
                                .filter({ $0.date >= date })
                                .sorted(by: { $0.date < $1.date })
                                .first {
                                subscriptionManager.deleteSingleOccurrence(transaction: transaction)
                            }
                        }
                        selectedPlannedPayment = nil
                        selectedOccurrenceDate = nil
                    },
                    onDeleteAll: { payment in
                        subscriptionManager.deleteAllOccurrences(subscriptionId: payment.id)
                        selectedPlannedPayment = nil
                        selectedOccurrenceDate = nil
                    },
                    onPay: { date in
                        // Handle pay action - use subscription from closure capture
                        // Create the paid transaction as a regular transaction (not a subscription)
                        // Use current date for "Pay Now" - this moves it to expenses immediately
                        let paymentDate = Date()
                        
                        if let subscription = selectedPlannedPayment {
                            // First, find and delete the subscription transaction BEFORE creating the new one
                            // This prevents duplicates
                            let calendar = Calendar.current
                            let dateToSearch = selectedOccurrenceDate ?? date
                            let normalizedDate = calendar.startOfDay(for: dateToSearch)
                            
                            // Try to find the subscription transaction in transactionManager
                            if let subscriptionTransaction = transactionManager.transactions.first(where: { txn in
                                txn.sourcePlannedPaymentId == subscription.id &&
                                calendar.isDate(calendar.startOfDay(for: txn.date), inSameDayAs: normalizedDate)
                            }) {
                                subscriptionManager.deleteSingleOccurrence(transaction: subscriptionTransaction)
                            } else {
                                // If transaction not found in transactionManager (e.g., it's a missed transaction),
                                // create a temporary transaction to mark this occurrence as skipped
                                let tempTransaction = Transaction(
                                    title: subscription.title,
                                    category: subscription.category ?? "General",
                                    amount: subscription.amount,
                                    date: normalizedDate,
                                    type: subscription.toAccountId != nil ? .transfer : (subscription.isIncome ? .income : .expense),
                                    accountId: subscription.accountId,
                                    toAccountId: subscription.toAccountId,
                                    currency: settings.currency,
                                    sourcePlannedPaymentId: subscription.id,
                                    occurrenceDate: normalizedDate
                                )
                                subscriptionManager.deleteSingleOccurrence(transaction: tempTransaction)
                            }
                            
                            // Determine transaction type
                            let transactionType: TransactionType
                            if subscription.toAccountId != nil {
                                transactionType = .transfer
                            } else {
                                transactionType = subscription.isIncome ? .income : .expense
                            }
                            
                            // Then create the paid transaction as a regular transaction
                            let transaction = Transaction(
                                title: subscription.title,
                                category: subscription.category ?? "General",
                                amount: subscription.amount,
                                date: paymentDate,
                                type: transactionType,
                                accountId: subscription.accountId,
                                toAccountId: subscription.toAccountId,
                                currency: settings.currency,
                                sourcePlannedPaymentId: nil, // Not a subscription transaction, it's a real payment
                                occurrenceDate: nil
                            )
                            transactionManager.addTransaction(transaction)
                            
                            // Balance is updated automatically by CreateTransactionUseCase
                        }
                        selectedPlannedPayment = nil
                        selectedOccurrenceDate = nil
                    }
                )
                .environmentObject(settings)
                .environmentObject(accountManager)
            }
            .alert(String(localized: "Delete Subscription", comment: "Delete subscription alert title"), isPresented: $showDeleteScheduledAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
                    clearDeletionState()
                }
                Button(String(localized: "Delete Only This", comment: "Delete only this occurrence")) {
                    if let transaction = scheduledTransactionToDelete {
                        subscriptionManager.deleteSingleOccurrence(transaction: transaction)
                    } else if let payment = plannedPaymentToDeleteFromEdit {
                        // For PlannedPayment, delete the first occurrence
                        if let transaction = transactionManager.transactions.first(where: { $0.sourcePlannedPaymentId == payment.id && Calendar.current.isDate($0.date, inSameDayAs: payment.date) }) {
                            subscriptionManager.deleteSingleOccurrence(transaction: transaction)
                        }
                    }
                    clearDeletionState()
                }
                Button(String(localized: "Delete All", comment: "Delete all occurrences"), role: .destructive) {
                    if let transaction = scheduledTransactionToDelete, let subscriptionId = transaction.sourcePlannedPaymentId {
                        subscriptionManager.deleteAllOccurrences(subscriptionId: subscriptionId)
                    } else if let payment = plannedPaymentToDeleteFromEdit ?? selectedPlannedPayment {
                        subscriptionManager.deleteAllOccurrences(subscriptionId: payment.id)
                    }
                    clearDeletionState()
                }
            } message: {
                Text(String(localized: "Do you want to delete only this occurrence or all future occurrences of this subscription?", comment: "Delete subscription alert message"))
            }
            .onChange(of: showTransactionForm) { oldValue, newValue in
                // When sheet closes, check if we have a pending edit mode
                if !newValue, let pendingMode = pendingEditMode {
                    // Sheet just closed, now set the mode and reopen
                    currentFormMode = pendingMode
                    pendingEditMode = nil
                    // Use a small delay to ensure sheet fully closes before reopening
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showTransactionForm = true
                    }
                }
            }
        }
    }
    
    // Tab content based on selected tab
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .past:
                pastTabContent
            case .planned:
                plannedTabContent
            case .missed:
                missedTabContent
            }
        }
    }
    
    // Past tab content
    private var pastTabContent: some View {
        Group {
            if filteredTransactions.isEmpty {
                emptyTransactionsState
                    .padding()
            } else {
                ForEach(Array(groupedTransactions.enumerated()), id: \.element.date) { index, dayGroup in
                    VStack(alignment: .leading, spacing: 12) {
                        dayHeader(for: dayGroup.date)
                            .padding(.horizontal, 20)
                            .padding(.top, index == 0 ? 8 : 16)
                            .padding(.bottom, 8)
                        
                        ForEach(dayGroup.transactions) { transaction in
                            // Вычисляем isScheduledToday один раз, используя кэш
                            let isScheduledToday = scheduledTodayCache[transaction.id] ?? false
                            
                            Button {
                                if isScheduledToday {
                                    // Open subscription form for scheduled transaction (with Pay Now button)
                                    selectedOccurrenceDate = transaction.occurrenceDate ?? transaction.date
                                    if let sourcePayment = findSourcePlannedPayment(for: transaction) {
                                        selectedPlannedPayment = sourcePayment
                                    }
                                } else {
                                    // Regular transaction - open edit form
                                    startEditing(transaction)
                                }
                            } label: {
                                TransactionRow(
                                    transaction: transaction,
                                    accountName: cachedAccountNames[transaction.id] ?? "Unknown",
                                    categoryIconName: cachedCategoryIcons[transaction.id] ?? transaction.type.iconName
                                )
                                .opacity(isScheduledToday ? 0.6 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .id(transaction.id)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
    
    // Missed tab content
    private var missedTabContent: some View {
        Group {
            if missedTransactions.isEmpty {
                emptyMissedState
                    .padding()
            } else {
                ForEach(Array(groupedMissedTransactions.enumerated()), id: \.element.date) { index, dayGroup in
                    VStack(alignment: .leading, spacing: 12) {
                        dayHeader(for: dayGroup.date)
                            .padding(.horizontal, 20)
                            .padding(.top, index == 0 ? 8 : 16)
                            .padding(.bottom, 8)
                        
                        ForEach(dayGroup.transactions) { transaction in
                            Button {
                                // Check if this is a scheduled transaction (has sourcePlannedPaymentId)
                                if transaction.sourcePlannedPaymentId != nil {
                                    // Open subscription form for missed scheduled transaction (with Pay Now button)
                                    selectedOccurrenceDate = transaction.occurrenceDate ?? transaction.date
                                    if let sourcePayment = findSourcePlannedPayment(for: transaction) {
                                        selectedPlannedPayment = sourcePayment
                                    }
                                } else {
                                    // Regular missed transaction - open edit form
                                    startEditing(transaction)
                                }
                            } label: {
                                TransactionRow(
                                    transaction: transaction,
                                    accountName: cachedAccountNames[transaction.id] ?? "Unknown",
                                    categoryIconName: cachedCategoryIcons[transaction.id] ?? transaction.type.iconName
                                )
                                .opacity(0.8)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
    
    private var tabButtons: some View {
        HStack(spacing: 8) {
            // Past/Today Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .past
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                    Text("Today", comment: "Today tab")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(selectedTab == .past ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selectedTab == .past ? Color.accentColor : Color.customCardBackground
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selectedTab == .past ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Missed Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .missed
                }
            } label: {
                Text("Missed", comment: "Missed tab")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(selectedTab == .missed ? .white : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        selectedTab == .missed ? Color.orange : Color.customCardBackground
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == .missed ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            // Future Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .planned
                }
            } label: {
                Text("Future", comment: "Future tab")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(selectedTab == .planned ? .white : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        selectedTab == .planned ? Color.blue : Color.customCardBackground
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == .planned ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    private var plannedPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Upcoming Payments", comment: "Upcoming payments header")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(upcomingPayments.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.customSecondaryBackground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Planned Payments List
            VStack(spacing: 12) {
                ForEach(upcomingPayments) { payment in
                    PlannedPaymentRow(payment: payment)
                }
            }
            .padding(.bottom, 20)
            
            // Separator
            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .background(Color.customBackground)
    }
    
    private var categoryMenu: some View {
        Menu {
            Button(String(localized: "All Categories", comment: "All categories filter")) {
                selectedCategory = nil
            }
            Divider()
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                }
            }
        } label: {
            Label(selectedCategory ?? String(localized: "Categories", comment: "Categories menu label"), systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private var typeMenu: some View {
        Menu {
            Button(String(localized: "All Types", comment: "All types filter")) {
                selectedType = nil
            }
            Divider()
            ForEach(TransactionType.allCases) { type in
                Button(type.title) {
                    selectedType = type
                }
            }
        } label: {
            Label(selectedType?.title ?? String(localized: "Types", comment: "Types menu label"), systemImage: "slider.horizontal.3")
        }
    }
    
    
    private var resetFilterChip: some View {
        Button {
            withAnimation(.spring) {
                selectedCategory = nil
            }
        } label: {
            HStack {
                Text("\(String(localized: "Category:", comment: "Category filter prefix")) \(selectedCategory ?? "")")
                Spacer()
                Image(systemName: "xmark.circle.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // Minimalist Floating Action Button with Action Menu
    private var floatingActionButton: some View {
        ZStack {
            // Action Menu Overlay with Blur
            if showActionMenu {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .blur(radius: 0)
                    
                    // Blur effect for background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .opacity(0.7)
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showActionMenu = false
                    }
                }
                .transition(.opacity)
            }
            
            // Action Menu Items and Main Button (always rendered)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 20) {
                        // Menu items (top to bottom: Expense, Income, Transfer, Debt)
                        ForEach(Array(actionOptions.reversed().enumerated()), id: \.element.id) { index, option in
                            actionMenuItem(option: option, index: index)
                        }
                        
                        // Main button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showActionMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                )
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 110)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func actionMenuItem(option: ActionMenuOption, index: Int) -> some View {
        Button {
            showActionMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAddingTransaction(for: option.type)
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(option.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 120, alignment: .trailing)
                
                Circle()
                    .fill(option.tint)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: option.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    )
            }
        }
        .buttonStyle(.plain)
        .opacity(showActionMenu ? 1 : 0)
    }
    
    private var emptyTransactionsState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No results", comment: "No results empty state")
                .font(.headline)
            Text("Try changing your search or filters.", comment: "No results suggestion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
    
    private var emptyPlannedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.blue.opacity(0.6))
            Text("No upcoming payments", comment: "No upcoming payments empty state")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("You don't have any planned payments scheduled.", comment: "No planned payments message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyMissedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))
            Text("No missed payments", comment: "No missed payments empty state")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("All your payments are up to date.", comment: "All payments up to date message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func dayHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isYesterday = calendar.isDateInYesterday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)
        
        let dateString: String
        if isToday {
            dateString = String(localized: "Today", comment: "Today date header")
        } else if isYesterday {
            dateString = String(localized: "Yesterday", comment: "Yesterday date header")
        } else if isTomorrow {
            dateString = String(localized: "Tomorrow", comment: "Tomorrow date header")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            dateString = formatter.string(from: date)
        }
        
        return HStack {
            Text(dateString)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private func startAddingTransaction(for type: TransactionType) {
        currentFormMode = .add(type)
        let firstAccountId = accountManager.accounts.first?.id ?? UUID()
        draftTransaction = TransactionDraft(type: type, currency: settings.currency, accountId: firstAccountId)
        showTransactionForm = true
    }
    
    private func startEditing(_ transaction: Transaction) {
        // Store the transaction being edited (important for scheduled transactions that may not exist in transactionManager)
        editingTransaction = transaction
        
        // If sheet is already open, store the pending mode and close the sheet
        if showTransactionForm {
            pendingEditMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = false
        } else {
            // Sheet is closed, set mode and open immediately
            currentFormMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = true
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        let oldTransaction: Transaction?
        
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactionManager.addTransaction(newTransaction)
            oldTransaction = nil
        case .edit(let id):
            // First try to find transaction in transactionManager
            var foundTransaction = transactionManager.transactions.first(where: { $0.id == id })
            
            // If not found, try to find by sourcePlannedPaymentId and date (for scheduled transactions)
            if foundTransaction == nil, let editingTxn = editingTransaction, editingTxn.sourcePlannedPaymentId != nil {
                let calendar = Calendar.current
                let editingDate = calendar.startOfDay(for: editingTxn.date)
                foundTransaction = transactionManager.transactions.first(where: { txn in
                    txn.sourcePlannedPaymentId == editingTxn.sourcePlannedPaymentId &&
                    calendar.isDate(calendar.startOfDay(for: txn.date), inSameDayAs: editingDate)
                })
            }
            
            oldTransaction = foundTransaction
            
            // Use editingTransaction if still not found (for dynamically generated scheduled transactions)
            let transactionToUse = oldTransaction ?? editingTransaction
            
            // If editing a scheduled transaction (has sourcePlannedPaymentId), 
            // we need to delete the scheduled occurrence and create a new regular transaction
            if let oldTxn = transactionToUse, oldTxn.sourcePlannedPaymentId != nil {
                // Delete the scheduled occurrence
                // If transaction exists in manager, use deleteSingleOccurrence
                if let existingTxn = oldTransaction {
                    subscriptionManager.deleteSingleOccurrence(transaction: existingTxn)
                } else if let editingTxn = editingTransaction {
                    // Transaction doesn't exist in manager yet, skip this occurrence manually
                    if let sourcePayment = findSourcePlannedPayment(for: editingTxn) {
                        let calendar = Calendar.current
                        let occurrenceDate = calendar.startOfDay(for: editingTxn.date)
                        
                        // Get current subscription and add date to skippedDates
                        var skippedDates = sourcePayment.skippedDates ?? []
                        if !skippedDates.contains(where: { calendar.isDate($0, inSameDayAs: occurrenceDate) }) {
                            skippedDates.append(occurrenceDate)
                            
                            // Update subscription with skipped date
                            let updatedSubscription = PlannedPayment(
                                id: sourcePayment.id,
                                title: sourcePayment.title,
                                amount: sourcePayment.amount,
                                date: sourcePayment.date,
                                status: sourcePayment.status,
                                accountId: sourcePayment.accountId,
                                toAccountId: sourcePayment.toAccountId,
                                category: sourcePayment.category,
                                type: sourcePayment.type,
                                isIncome: sourcePayment.isIncome,
                                totalLoanAmount: sourcePayment.totalLoanAmount,
                                remainingBalance: sourcePayment.remainingBalance,
                                startDate: sourcePayment.startDate,
                                interestRate: sourcePayment.interestRate,
                                linkedCreditId: sourcePayment.linkedCreditId,
                                isRepeating: sourcePayment.isRepeating,
                                repetitionFrequency: sourcePayment.repetitionFrequency,
                                repetitionInterval: sourcePayment.repetitionInterval,
                                selectedWeekdays: sourcePayment.selectedWeekdays,
                                skippedDates: skippedDates,
                                endDate: sourcePayment.endDate
                            )
                            subscriptionManager.updateSubscription(updatedSubscription)
                        }
                    }
                }
                
                // Create a new regular transaction (without sourcePlannedPaymentId) with edited data
                let newTransaction = draft.toTransaction(existingId: nil)
                transactionManager.addTransaction(newTransaction)
            } else {
                // Regular transaction editing - just update it
                if oldTransaction != nil {
                    let updated = draft.toTransaction(existingId: id)
                    transactionManager.updateTransaction(updated)
                } else {
                    // Transaction not found - create new one
                    let newTransaction = draft.toTransaction(existingId: nil)
                    transactionManager.addTransaction(newTransaction)
                }
            }
        }
        
        // Balance is updated automatically by UpdateTransactionUseCase or CreateTransactionUseCase
        
        showTransactionForm = false
        pendingEditMode = nil
        editingTransaction = nil
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        // If it's a scheduled transaction (has sourcePlannedPaymentId), delete it via SubscriptionManager
        if transaction.sourcePlannedPaymentId != nil {
            subscriptionManager.deleteSingleOccurrence(transaction: transaction)
            // Scheduled transactions don't affect balance, so no need to revert balance changes
            return
        }
        
        // If it's a debt transaction, also delete the corresponding DebtTransaction
        if transaction.type == .debt {
            if let debtTransaction = debtManager.transactions.first(where: { $0.id == transaction.id }) {
                // Balance is reverted automatically by DeleteTransactionUseCase
                debtManager.deleteTransaction(debtTransaction)
            }
        }
        
        transactionManager.deleteTransaction(transaction)
        // Balance is reverted automatically by DeleteTransactionUseCase
    }
    
    // CLEAN: Check if a transaction is a scheduled occurrence
    // All transactions in upcomingTransactions are scheduled
    private func isScheduledTransaction(_ transaction: Transaction) -> Bool {
        // If it has sourcePlannedPaymentId, it's scheduled
        if transaction.sourcePlannedPaymentId != nil {
            return true
        }
        
        // If it's in upcomingTransactions, it's scheduled
        return false // SubscriptionManager removed
    }
    
    // MARK: - Deletion Handlers - COMPLETELY REWRITTEN FROM SCRATCH
    
    /// Delete a single transaction occurrence
    /// SubscriptionManager removed - function disabled
    private func handleDeleteOnlyThisScheduled(_ transaction: Transaction) {
        // SubscriptionManager removed - deletion not available
        cleanupOldTransaction(transactionId: transaction.id)
        clearDeletionState()
    }
    
    /// Delete this transaction and all future ones
    /// SubscriptionManager removed - function disabled
    private func handleDeleteAllFuture(_ transaction: Transaction) {
        // SubscriptionManager removed - deletion not available
        if let subscriptionId = transaction.sourcePlannedPaymentId {
            let calendar = Calendar.current
            let dateToDelete = calendar.startOfDay(for: transaction.date)
            cleanupOldTransactions(subscriptionId: subscriptionId, fromDate: dateToDelete)
        }
        clearDeletionState()
    }
    
    /// Delete all future for a PlannedPayment directly
    /// SubscriptionManager removed - function disabled
    private func handleDeleteAllFutureForPayment(_ payment: PlannedPayment) {
        // SubscriptionManager removed - deletion not available
        clearDeletionState()
    }
    
    /// Delete only this occurrence for a PlannedPayment directly
    /// SubscriptionManager removed - function disabled
    private func handleDeleteOnlyThisPlannedPayment(_ payment: PlannedPayment) {
        // SubscriptionManager removed - deletion not available
        clearDeletionState()
    }
    
    // Helper to clear deletion state
    private func clearDeletionState() {
        scheduledTransactionToDelete = nil
        plannedPaymentToDeleteFromEdit = nil
        // Don't clear selectedPlannedPayment here - it's used for editing
        // It will be cleared when user cancels/saves editing or closes the sheet
    }
    
    // Helper to clean up old transaction by ID
    private func cleanupOldTransaction(transactionId: UUID) {
        if let existingTransaction = transactionManager.transactions.first(where: { $0.id == transactionId }) {
            transactionManager.deleteTransaction(existingTransaction)
        }
    }
    
    // Helper to clean up old transactions for a subscription from a date forward
    private func cleanupOldTransactions(subscriptionId: UUID, fromDate: Date) {
        let calendar = Calendar.current
        let matchingTransactions = transactionManager.transactions.filter { txn in
            if let sourceId = txn.sourcePlannedPaymentId, sourceId == subscriptionId {
                let txnDate = calendar.startOfDay(for: txn.date)
                return txnDate >= fromDate
            }
            return false
        }
        
        for matchingTransaction in matchingTransactions {
            transactionManager.deleteTransaction(matchingTransaction)
        }
    }
    
    // Check if there are future occurrences after the selected transaction
    private func hasFutureOccurrences(after transaction: Transaction) -> Bool {
        guard let sourcePayment = findSourcePlannedPayment(for: transaction) else {
            return false
        }
        
        let calendar = Calendar.current
        let transactionDate = calendar.startOfDay(for: transaction.date)
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        
        // Generate occurrences and check if any are after the transaction date
        let occurrences = generateScheduledOccurrences(from: sourcePayment, endDate: endDate)
        return occurrences.contains { occurrence in
            let occurrenceDate = calendar.startOfDay(for: occurrence.date)
            return occurrenceDate > transactionDate
        }
    }
    
    // Check if there are future occurrences for a PlannedPayment
    private func hasFutureOccurrencesForPayment(_ payment: PlannedPayment) -> Bool {
        guard payment.isRepeating else {
            return false
        }
        
        let calendar = Calendar.current
        let paymentDate = calendar.startOfDay(for: payment.date)
        let today = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        
        // Generate occurrences and check if any are after the payment's start date
        let occurrences = generateScheduledOccurrences(from: payment, endDate: endDate)
        return occurrences.contains { occurrence in
            let occurrenceDate = calendar.startOfDay(for: occurrence.date)
            return occurrenceDate > paymentDate
        }
    }
    
    // Find the source PlannedPayment for a scheduled transaction
    // ISSUE 2 FIX: Use sourcePlannedPaymentId for direct, reliable lookup
    // Improved to handle old subscriptions that might not match perfectly
    private func findSourcePlannedPayment(for transaction: Transaction) -> PlannedPayment? {
        // Use sourcePlannedPaymentId for direct lookup via SubscriptionManager
        if let sourceId = transaction.sourcePlannedPaymentId {
            return subscriptionManager.getSubscription(id: sourceId)
        }
        
        // Fallback: Legacy matching for transactions created before this fix
        // Check all repeating planned payments
        let repeatingPayments = subscriptionManager.subscriptions.filter { $0.isRepeating }
        
        // Try exact match first
        for payment in repeatingPayments {
            // Check if transaction matches this payment's details
            if transaction.title == payment.title &&
               abs(transaction.amount - payment.amount) < 0.01 && // Use tolerance for floating point
               transaction.accountId == payment.accountId &&
               transaction.type == (payment.isIncome ? .income : .expense) {
                
                // Check if the transaction date matches the repetition pattern
                guard let frequencyString = payment.repetitionFrequency,
                      let frequency = RepetitionFrequency(rawValue: frequencyString),
                      let interval = payment.repetitionInterval else {
                    continue
                }
                
                let weekdays = Set(payment.selectedWeekdays ?? [])
                let startDate = payment.date
                let transactionDate = transaction.date
                let calendar = Calendar.current
                let transactionDateStart = calendar.startOfDay(for: transactionDate)
                
                // Check if this date is skipped
                let skippedDates = payment.skippedDates ?? []
                let isSkipped = skippedDates.contains { skippedDate in
                    calendar.isDate(transactionDateStart, inSameDayAs: skippedDate)
                }
                
                // Check if transaction date is after endDate
                if let endDate = payment.endDate {
                    let endDateStart = calendar.startOfDay(for: endDate)
                    if transactionDateStart > endDateStart {
                        continue // Transaction is after the end date
                    }
                }
                
                // Check if startDate matches (first occurrence)
                let startDateStart = calendar.startOfDay(for: startDate)
                let isStartDateSkipped = skippedDates.contains { skippedDate in
                    calendar.isDate(startDateStart, inSameDayAs: skippedDate)
                }
                
                if calendar.isDate(startDateStart, inSameDayAs: transactionDateStart) && !isStartDateSkipped {
                    return payment
                }
                
                // Check if this date matches the repetition pattern and is not skipped
                if !isSkipped && matchesRepetitionPattern(
                    date: transactionDate,
                    startDate: startDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays
                ) {
                    return payment
                }
            }
        }
        
        // If exact match fails, try a more lenient match for old subscriptions
        // Match by title and account only (for cases where amount might have changed)
        for payment in repeatingPayments {
            if transaction.title == payment.title &&
               transaction.accountId == payment.accountId &&
               transaction.type == (payment.isIncome ? .income : .expense) {
                // If it's in the future and matches basic criteria, allow deletion
                let calendar = Calendar.current
                let transactionDateStart = calendar.startOfDay(for: transaction.date)
                let today = calendar.startOfDay(for: Date())
                
                // Only match future transactions to avoid false positives
                if transactionDateStart >= today {
                    // Check if it's not after endDate
                    if let endDate = payment.endDate {
                        let endDateStart = calendar.startOfDay(for: endDate)
                        if transactionDateStart > endDateStart {
                            continue
                        }
                    }
                    // Return the payment if basic match and it's a future date
                    return payment
                }
            }
        }
        
        return nil
    }
    
    // Check if a date matches the repetition pattern
    private func matchesRepetitionPattern(
        date: Date,
        startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>
    ) -> Bool {
        let calendar = Calendar.current
        
        switch frequency {
        case .day:
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
            return daysSinceStart >= 0 && daysSinceStart % interval == 0
            
        case .week:
            if !weekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: date)
                let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
                if !weekdays.contains(adjustedWeekday) {
                    return false
                }
            }
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startDate, to: date).weekOfYear ?? 0
            return weeksSinceStart >= 0 && weeksSinceStart % interval == 0
            
        case .month:
            let monthsSinceStart = calendar.dateComponents([.month], from: startDate, to: date).month ?? 0
            if monthsSinceStart < 0 || monthsSinceStart % interval != 0 {
                return false
            }
            // Also check that the day of month matches (e.g., 10th of each month)
            let startDay = calendar.component(.day, from: startDate)
            let checkDay = calendar.component(.day, from: date)
            return startDay == checkDay
            
        case .year:
            let yearsSinceStart = calendar.dateComponents([.year], from: startDate, to: date).year ?? 0
            if yearsSinceStart < 0 || yearsSinceStart % interval != 0 {
                return false
            }
            // Check that month and day match
            let startComponents = calendar.dateComponents([.month, .day], from: startDate)
            let checkComponents = calendar.dateComponents([.month, .day], from: date)
            return startComponents.month == checkComponents.month &&
                   startComponents.day == checkComponents.day
        }
    }
    
    // Removed: updateAccountBalances - balance is now updated only by UseCases
}

struct TransactionRow: View {
    let transaction: Transaction
    let accountName: String // Precomputed account name (передаётся извне)
    let categoryIconName: String // Precomputed category icon (передаётся извне)
    
    // A/B TEST: Body call counter for FPS measurement
    #if DEBUG
    private static var bodyCallCount: Int = 0
    private static var lastLogTime: Date = Date()
    #endif
    
    private var categoryColor: Color {
        // Strict color coding based on transaction type (priority over category color)
        switch transaction.type {
        case .transfer:
            return .blue
        case .income:
            return .green
        case .expense:
            return .red
        case .debt:
            return .orange
        }
    }
    
    var body: some View {
        #if DEBUG
        let _ = {
            TransactionRow.bodyCallCount += 1
            let now = Date()
            if now.timeIntervalSince(TransactionRow.lastLogTime) >= 1.0 {
                print("📊 [GPU TEST] TransactionRow.body called \(TransactionRow.bodyCallCount) times in last second")
                TransactionRow.bodyCallCount = 0
                TransactionRow.lastLogTime = now
            }
        }()
        #endif
        
        let rowContent = HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIconName)
                    .font(.headline)
                    .foregroundStyle(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category)
                    .font(.subheadline.weight(.semibold))
                Text(transaction.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(transaction.date.formatted(.dateTime.day().month(.abbreviated))) • \(accountName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.displayAmount())
                .font(.headline)
                .foregroundStyle(transaction.type.color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        
        // STEP 0: A/B TEST - Conditionally apply GPU-heavy effects
        if TransactionsView.USE_FAST_ROW_STYLE {
            // Fast style: Only background, no clipShape/overlay
            return AnyView(rowContent.background(Color.customCardBackground))
        } else {
            // Original style: Full card with clipShape and overlay stroke
            return AnyView(
                rowContent
                    .background(Color.customCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

struct PlannedPaymentRow: View {
    let payment: PlannedPayment
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManagerAdapter
    
    private var categoryIcon: String {
        if let categoryName = payment.category,
           let category = settings.categories.first(where: { $0.name == categoryName }) {
            return category.iconName
        }
        return "calendar"
    }
    
    private var iconColor: Color {
        if let categoryName = payment.category,
           let category = settings.categories.first(where: { $0.name == categoryName }) {
            return category.color
        }
        return payment.status == .past || payment.date < Date() ? .orange : .blue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.category ?? "General")
                    .font(.subheadline.weight(.semibold))
                Text(payment.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(payment.date.formatted(.dateTime.day().month(.abbreviated))) • \(payment.accountName(accountManager: accountManager))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(currencyString(payment.amount, code: settings.currency))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(payment.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TransactionFormView: View {
    @Binding var draft: TransactionDraft
    let mode: TransactionFormMode
    let categories: [String]
    let accounts: [Account]
    let onSave: (TransactionDraft) -> Void
    let onCancel: () -> Void
    let onDelete: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var debtManager: DebtManager
    // SubscriptionManager removed
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showToAccountPicker = false
    @State private var showContactPicker = false
    @State private var selectedContact: Contact?
    @State private var debtTransactionType: DebtTransactionType = .lent
    @State private var isDebtReturn: Bool = false
    @State private var amountText: String = ""
    @State private var saveToPlannedPayments: Bool = false
    @State private var showDeleteAlert = false
    
    // Repetition settings
    @State private var isRepeating: Bool = false
    @State private var repetitionFrequency: RepetitionFrequency = .month
    @State private var repetitionInterval: Int = 1
    @State private var selectedWeekdays: Set<Int> = [] // 0 = Sunday, 1 = Monday, etc.
    
    @FocusState private var isAmountFocused: Bool
    
    // Computed property to check if we're in edit mode
    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }
    
    // MARK: - Dismiss Keyboard Helper
    private func dismissKeyboard() {
        isAmountFocused = false
        // Also dismiss any other first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    enum RepetitionFrequency: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var localizedTitle: String {
            switch self {
            case .day:
                return String(localized: "Day", comment: "Day frequency")
            case .week:
                return String(localized: "Week", comment: "Week frequency")
            case .month:
                return String(localized: "Month", comment: "Month frequency")
            case .year:
                return String(localized: "Year", comment: "Year frequency")
            }
        }
        
        var localizedUnit: String {
            switch self {
            case .day:
                return String(localized: "day", comment: "day unit")
            case .week:
                return String(localized: "week", comment: "week unit")
            case .month:
                return String(localized: "month", comment: "month unit")
            case .year:
                return String(localized: "year", comment: "year unit")
            }
        }
    }
    
    private var availableCategories: [Category] {
        // Use settings categories, fallback to defaults if empty
        var filtered = settings.categories.isEmpty ? Category.defaultCategories : settings.categories
        
        // Filter by category type based on transaction type
        switch draft.type {
        case .income:
            filtered = filtered.filter { $0.type == .income }
        case .expense:
            filtered = filtered.filter { $0.type == .expense }
        case .transfer, .debt:
            // For transfers and debt, show all categories or none
            break
        }
        
        // Don't filter by the categories parameter - show all available categories from settings
        // The categories parameter is just for reference, not for filtering the picker
        
        return filtered
    }
    
    private var selectedAccount: Account? {
        return accountManager.getAccount(id: draft.accountId) ?? accounts.first
    }
    
    private var selectedToAccount: Account? {
        guard let toAccountId = draft.toAccountId else { return nil }
        return accountManager.getAccount(id: toAccountId)
    }
    
    private var selectedCategory: Category? {
        // Handle subcategory format: "Category > Subcategory"
        let categoryName: String
        if draft.category.contains(" > ") {
            categoryName = String(draft.category.split(separator: " > ").first ?? "")
        } else {
            categoryName = draft.category
        }
        return settings.categories.first { $0.name == categoryName }
    }
    
    // MARK: - Theme Color
    private var themeColor: Color {
        switch draft.type {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        case .debt:
            return .orange
        }
    }
    
    // MARK: - Sign Symbol
    private var signSymbol: String {
        switch draft.type {
        case .expense:
            return "-"
        case .income:
            return "+"
        case .transfer:
            return "↔"
        case .debt:
            return ""
        }
    }
    
    // MARK: - Transfer Icon
    private var transferIcon: String {
        return "arrow.left.arrow.right"
    }
    
    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 24) {
            // Segmented Control at Top
            typeSegmentedControl
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Hero Amount Input (Center)
            heroAmountField
                .padding(.horizontal)
            
            // Input Fields
            inputFieldsSection
            
            // Repetition Section (for all transaction types)
            repetitionSection
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Input Fields Section
    private var inputFieldsSection: some View {
        VStack(spacing: 16) {
            // Note/Title Field
            TransactionFormRow(
                icon: "text.alignleft",
                title: "Note",
                value: $draft.title,
                placeholder: "Transaction note"
            )
            
            // Category Field (Hidden for transfers and debt)
            if draft.type != .transfer && draft.type != .debt {
                TransactionCategoryRow(
                    icon: "tag",
                    title: String(localized: "Category", comment: "Category field label"),
                    category: selectedCategory,
                    categoryName: draft.category.isEmpty ? "" : draft.category,
                    placeholder: String(localized: "Select Category", comment: "Category placeholder"),
                    onTap: {
                        dismissKeyboard()
                        showCategoryPicker = true
                    }
                )
            }
            
            // Contact Field (Only for debt)
            if draft.type == .debt {
                TransactionContactRow(
                    icon: "person.fill",
                    title: String(localized: "Contact", comment: "Contact field label"),
                    contact: selectedContact,
                    placeholder: String(localized: "Select Contact", comment: "Select contact placeholder"),
                    onTap: {
                        dismissKeyboard()
                        showContactPicker = true
                    }
                )
                
                // Debt Direction Picker (Lent vs Borrowed)
                HStack(spacing: 0) {
                    ForEach([DebtTransactionType.lent, DebtTransactionType.borrowed]) { type in
                        Button {
                            dismissKeyboard()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                debtTransactionType = isDebtReturn ? (type == .lent ? .lentReturn : .borrowedReturn) : type
                            }
                        } label: {
                            Text(type == .lent ? String(localized: "I lent / I returned debt", comment: "I lent or returned") : String(localized: "They lent / They returned debt", comment: "They lent or returned"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(debtTransactionType.baseType == type ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(debtTransactionType.baseType == type ? type.direction.color : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color.customCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: debtTransactionType) { oldValue, newValue in
                    dismissKeyboard()
                    isDebtReturn = newValue.isReturn
                }
                
                // Return Toggle
                Toggle(isOn: $isDebtReturn) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(isDebtReturn ? (debtTransactionType.direction.color) : .secondary)
                        Text(String(localized: "Return debt", comment: "Return debt toggle"))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: debtTransactionType.direction.color))
                .onChange(of: isDebtReturn) { oldValue, newValue in
                    dismissKeyboard()
                    // Update debtTransactionType based on isDebtReturn state
                    if newValue {
                        debtTransactionType = debtTransactionType == .lent ? .lentReturn : .borrowedReturn
                    } else {
                        debtTransactionType = debtTransactionType == .lentReturn ? .lent : .borrowed
                    }
                }
            }
            
            // Date Field
            TransactionDateRow(
                icon: "calendar",
                title: String(localized: "Date", comment: "Date field label"),
                date: $draft.date
            )
            
            // Account Field(s)
            accountFieldsSection
            
            // Currency Field
            TransactionCurrencyRow(
                icon: "dollarsign.circle",
                title: String(localized: "Currency", comment: "Currency field label"),
                currency: $draft.currency
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Account Fields Section
    private var accountFieldsSection: some View {
        Group {
            if draft.type == .transfer {
                // Transfer: From and To accounts
                TransactionAccountRow(
                    icon: "arrow.up.circle.fill",
                    title: String(localized: "From Account", comment: "From account field label"),
                    account: selectedAccount,
                    placeholder: String(localized: "Select From Account", comment: "From account placeholder"),
                    onTap: {
                        dismissKeyboard()
                        showAccountPicker = true
                    }
                )
                
                // Transfer Arrow
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    Spacer()
                }
                
                TransactionAccountRow(
                    icon: "arrow.down.circle.fill",
                    title: String(localized: "To Account", comment: "To account field label"),
                    account: selectedToAccount,
                    placeholder: String(localized: "Select To Account", comment: "To account placeholder"),
                    onTap: {
                        dismissKeyboard()
                        showToAccountPicker = true
                    }
                )
            } else {
                // Regular transaction: Single account
                TransactionAccountRow(
                    icon: "creditcard",
                    title: String(localized: "Account", comment: "Account field label"),
                    account: selectedAccount,
                    placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                    onTap: {
                        dismissKeyboard()
                        showAccountPicker = true
                    }
                )
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    @ViewBuilder
    private var trailingToolbarButtons: some View {
        if isEditMode && onDelete != nil {
            HStack(spacing: 8) {
                saveButtonView
                separatorView
                deleteButtonView
            }
        } else {
            saveButtonView
        }
    }
    
    private var saveButtonView: some View {
        Button {
            handleSave()
        } label: {
            Label(String(localized: "Save", comment: "Save button"), systemImage: "checkmark")
        }
        .disabled(!draft.isValid)
    }
    
    private var separatorView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
    }
    
    private var deleteButtonView: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Handle Save
    private func handleSave() {
        dismissKeyboard()
        // Handle debt transactions separately
        if draft.type == .debt {
            handleDebtSave()
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let transactionDate = calendar.startOfDay(for: draft.date)
            let isFutureDate = transactionDate > today
            
            // When repetition is enabled, create a subscription instead of a regular transaction
            if isRepeating {
                // Determine default title
                let defaultTitle: String
                switch draft.type {
                case .income:
                    defaultTitle = "Recurring Income"
                case .expense:
                    defaultTitle = "Recurring Expense"
                case .transfer:
                    defaultTitle = "Recurring Transfer"
                case .debt:
                    defaultTitle = "Recurring Debt"
                }
                
                // Create subscription - SubscriptionManager will generate all occurrences
                let subscription = PlannedPayment(
                    title: draft.title.isEmpty ? defaultTitle : draft.title,
                    amount: draft.amount,
                    date: draft.date,
                    status: .upcoming,
                    accountId: draft.accountId,
                    toAccountId: draft.type == .transfer ? draft.toAccountId : nil,
                    category: draft.type == .transfer ? nil : (draft.category.isEmpty ? nil : draft.category),
                    type: .subscription,
                    isIncome: draft.type == .income,
                    isRepeating: true,
                    repetitionFrequency: repetitionFrequency.rawValue,
                    repetitionInterval: repetitionInterval,
                    selectedWeekdays: (repetitionFrequency == .week && !selectedWeekdays.isEmpty) ? Array(selectedWeekdays) : nil,
                    skippedDates: nil,
                    endDate: nil
                )
                subscriptionManager.addSubscription(subscription)
                // Balance is updated automatically when subscription transactions are generated/paid through UseCases
                // Don't call onSave - subscription is created, not a regular transaction
            } else if isFutureDate {
                // For future one-time transactions, create a PlannedPayment (not repeating)
                // This allows them to be shown in "Planned" tab and moved to "Missed" if not paid
                let defaultTitle: String
                switch draft.type {
                case .income:
                    defaultTitle = "Planned Income"
                case .expense:
                    defaultTitle = "Planned Expense"
                case .transfer:
                    defaultTitle = "Planned Transfer"
                case .debt:
                    defaultTitle = "Planned Debt"
                }
                
                let plannedPayment = PlannedPayment(
                    title: draft.title.isEmpty ? defaultTitle : draft.title,
                    amount: draft.amount,
                    date: draft.date,
                    status: .upcoming,
                    accountId: draft.accountId,
                    toAccountId: draft.type == .transfer ? draft.toAccountId : nil,
                    category: draft.type == .transfer ? nil : (draft.category.isEmpty ? nil : draft.category),
                    type: .subscription,
                    isIncome: draft.type == .income,
                    isRepeating: false,
                    repetitionFrequency: nil,
                    repetitionInterval: nil,
                    selectedWeekdays: nil,
                    skippedDates: nil,
                    endDate: nil
                )
                subscriptionManager.addSubscription(plannedPayment)
                // Don't update balance - it will be updated when transaction is paid
                // Don't call onSave - planned payment is created, not a regular transaction
            } else {
                // For non-repeating transactions in the past or today, save normally
                // These transactions affect balance immediately
                onSave(draft)
            }
        }
        dismiss()
    }
    
    // Removed: updateAccountBalanceForSubscription, updateTransferBalances, updateSingleAccountBalance
    // Balance is now updated only by UseCases
    
    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            Color.customBackground.ignoresSafeArea()
            
            ScrollView {
                formContent
            }
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    dismissKeyboard()
                }
            )
        }
    }
    
    // MARK: - Navigation Configuration
    private var navigationConfig: some View {
        mainContent
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                onCancel()
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarButtons
        }
    }
    
    // MARK: - Sheets
    private var contentWithSheets: some View {
        navigationConfig
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet(isFromAccount: true)
            }
            .sheet(isPresented: $showToAccountPicker) {
                accountPickerSheet(isFromAccount: false)
            }
            .sheet(isPresented: $showContactPicker) {
                contactPickerSheet
            }
    }
    
    var body: some View {
        NavigationStack {
            contentWithSheets
            .alert(String(localized: "Delete Transaction", comment: "Delete transaction alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    if case .edit(let id) = mode {
                        onDelete?(id)
                        dismiss()
                    }
                }
            } message: {
                Text(String(localized: "Are you sure you want to delete this transaction? This action cannot be undone.", comment: "Delete transaction confirmation"))
            }
            .onAppear {
                // Initialize amount text from draft
                if draft.amount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(draft.amount)
                }
                // Initialize currency from settings for new transactions
                if case .add = mode {
                    draft.currency = settings.currency
                    // Use default account if available, otherwise use first account
                    if let defaultId = accountManager.getDefaultAccountId() {
                        draft.accountId = defaultId
                    } else if let firstId = accounts.first?.id {
                        draft.accountId = firstId
                    }
                }
                // Validate account ID - if it doesn't exist, use default or first available account
                if accountManager.getAccount(id: draft.accountId) == nil {
                    if let defaultId = accountManager.getDefaultAccountId() {
                        draft.accountId = defaultId
                    } else if let firstId = accounts.first?.id {
                        draft.accountId = firstId
                    }
                }
                // Validate toAccountId for transfers
                if draft.type == .transfer, let toAccountId = draft.toAccountId {
                    if accountManager.getAccount(id: toAccountId) == nil {
                        draft.toAccountId = accounts.first?.id
                    }
                }
                
                // Auto-set selectedContact when editing a debt transaction
                if isEditMode, draft.type == .debt {
                    if case .edit(let transactionId) = mode,
                       let debtTransaction = debtManager.transactions.first(where: { $0.id == transactionId }),
                       let contact = debtManager.contacts.first(where: { $0.id == debtTransaction.contactId }) {
                        selectedContact = contact
                        debtTransactionType = debtTransaction.type
                    }
                }
                
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
            .onChange(of: draft.amount) { oldValue, newValue in
                // Sync amountText when draft.amount changes externally (e.g., from segmented control)
                if newValue == 0 {
                    amountText = ""
                } else if amountText.isEmpty || abs(newValue - (Double(amountText) ?? 0)) > 0.01 {
                    // Only update if there's a significant difference to avoid conflicts
                    amountText = formatAmount(newValue)
                }
            }
            .onAppear {
                // Auto-set selectedContact when editing a debt transaction
                if isEditMode, draft.type == .debt {
                    if let transactionId = mode.transactionId,
                       let debtTransaction = debtManager.transactions.first(where: { $0.id == transactionId }),
                       let contact = debtManager.contacts.first(where: { $0.id == debtTransaction.contactId }) {
                        selectedContact = contact
                        debtTransactionType = debtTransaction.type
                    }
                }
            }
            .onChange(of: draft.type) { oldValue, newValue in
                // Reset transfer-specific fields when changing type
                if newValue != .transfer {
                    draft.toAccountId = nil
                } else if oldValue != .transfer {
                    // When switching to transfer, ensure we have a valid setup
                    if draft.toAccountId == nil && accounts.count > 1 {
                        if let fromAccount = selectedAccount,
                           let toAccount = accounts.first(where: { $0.id != fromAccount.id }) {
                            draft.toAccountId = toAccount.id
                        }
                    }
                }
                
                // Clear category if it doesn't match the new transaction type
                if newValue != .transfer && newValue != .debt {
                    if let currentCategory = selectedCategory {
                        let expectedType: CategoryType = (newValue == .income) ? .income : .expense
                        if currentCategory.type != expectedType {
                            draft.category = ""
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Is Credit Repayment
    private var isCreditRepayment: Bool {
        guard draft.type == .transfer,
              let toAccountId = draft.toAccountId else {
            return false
        }
        return accountManager.getAccount(id: toAccountId)?.accountType == .credit
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        Picker("Transaction Type", selection: $draft.type) {
            Text(String(localized: "Expense", comment: "Expense transaction type")).tag(TransactionType.expense)
            Text(String(localized: "Income", comment: "Income transaction type")).tag(TransactionType.income)
            Text(String(localized: "Transfer", comment: "Transfer transaction type")).tag(TransactionType.transfer)
            // Debt removed from picker - debt transactions should be created only through debt flow (DebtsView)
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Hero Amount Field
    private var heroAmountField: some View {
        VStack(spacing: 8) {
            Text("Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Spacer()
                
                // Small, subtle icon for transaction type (always shown, colored only)
                        if draft.type == .transfer {
                    Image(systemName: transferIcon)
                        .font(.title2)
                        .foregroundStyle(themeColor)
                } else if draft.type == .debt {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(themeColor)
                } else if !signSymbol.isEmpty {
                    Text(signSymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(themeColor)
                }
                
                TextField("0", text: $amountText)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isAmountFocused)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 120)
                    .onChange(of: amountText) { oldValue, newValue in
                        handleAmountInput(newValue)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Amount Input Handler
    private func handleAmountInput(_ newValue: String) {
        // Normalize input to accept both dots and commas
        var cleaned = newValue.replacingOccurrences(of: ",", with: ".")
        cleaned = cleaned.filter { $0.isNumber || $0 == "." }
        let components = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        if components.count > 2 {
            let firstPart = String(components[0])
            let rest = components.dropFirst().joined(separator: "")
            cleaned = firstPart + "." + rest
        }
        
        // Handle leading zero replacement: if current amount is 0 and user types a digit, replace 0
        if draft.amount == 0 && !cleaned.isEmpty {
            // If the cleaned value starts with a non-zero digit, replace the zero
            if let firstChar = cleaned.first, firstChar.isNumber, firstChar != "0" {
                // Keep the cleaned value as-is (it already replaces the zero)
                amountText = cleaned
                if let value = Double(cleaned) {
                    draft.amount = value
                }
                return
            }
        }
        
        // Update the text
        amountText = cleaned
        
        // Convert to double and update draft
        if cleaned.isEmpty {
            draft.amount = 0
        } else if let value = Double(cleaned) {
            draft.amount = value
        } else {
            // If conversion fails, keep the text but don't update amount
            // This handles cases like "5." (incomplete decimal)
        }
    }
    
    // MARK: - Format Amount
    private func formatAmount(_ amount: Double) -> String {
        // Format without trailing zeros
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            let formatted = String(format: "%.2f", amount)
            // Remove trailing zeros
            return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
    
    // MARK: - Normalize Decimal Input
    private func normalizeDecimalInput(_ input: String) -> String {
        return input.replacingOccurrences(of: ",", with: ".")
    }
    
    // MARK: - Repetition Section
    private var repetitionSection: some View {
        VStack(spacing: 20) {
            // Repeat Operation Toggle
            HStack {
                Text(String(localized: "Repeat operation", comment: "Repeat operation toggle"))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $isRepeating)
                    .labelsHidden()
            }
            .padding(16)
        .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
            .onChange(of: isRepeating) { _, _ in
                dismissKeyboard()
            }
            
            if isRepeating {
                VStack(spacing: 16) {
                    // Frequency Label
                    Text(String(localized: "Repetition frequency", comment: "Repetition frequency label"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Frequency Selector (Day, Week, Month, Year)
                    HStack(spacing: 0) {
                        ForEach(RepetitionFrequency.allCases, id: \.self) { frequency in
                            Button {
                                dismissKeyboard()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    repetitionFrequency = frequency
                                    // Clear weekdays when switching away from week
                                    if frequency != .week {
                                        selectedWeekdays.removeAll()
                                    }
                                }
                            } label: {
                                Text(frequency.localizedTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(repetitionFrequency == frequency ? Color.white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(repetitionFrequency == frequency ? Color.blue : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
            }
        }
                    .padding(4)
                    .background(Color.customCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    
                    // Day of Week Selection (only for Week frequency)
                    if repetitionFrequency == .week {
                        HStack(spacing: 8) {
                            ForEach(weekdayOptions, id: \.value) { weekday in
        Button {
                                    dismissKeyboard()
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        if selectedWeekdays.contains(weekday.value) {
                                            selectedWeekdays.remove(weekday.value)
                                        } else {
                                            selectedWeekdays.insert(weekday.value)
                    }
                                    }
                                } label: {
                                    Text(weekday.shortName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(selectedWeekdays.contains(weekday.value) ? Color.white : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selectedWeekdays.contains(weekday.value) ? Color.blue : Color.customCardBackground)
                                        )
                                }
                                .buttonStyle(.plain)
                    }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Repeat Every Label and Number Picker
                    VStack(spacing: 12) {
                        HStack {
                            Text(String(localized: "Repeat every", comment: "Repeat every label"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.red)
                Spacer()
                            Text("\(repetitionInterval) \(repetitionFrequency.localizedUnit)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 4)
                        
                        // Number Picker (Wheel Style)
                        Picker("", selection: $repetitionInterval) {
                            ForEach(1...30, id: \.self) { number in
                                Text("\(number)")
                                    .tag(number)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.customCardBackground.opacity(0.5))
                        )
                        .onChange(of: repetitionInterval) { _, _ in
                            dismissKeyboard()
                        }
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
                .padding(16)
                .background(Color.customCardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
    }
        }
    }
    
    // MARK: - Weekday Options
    private struct WeekdayOption: Identifiable {
        let id: Int
        let value: Int
        let shortName: String
        let fullName: String
    }
    
    private var weekdayOptions: [WeekdayOption] {
        let weekdays = [
            WeekdayOption(id: 1, value: 1, shortName: String(localized: "Mon", comment: "Monday"), fullName: String(localized: "Monday", comment: "Monday full")),
            WeekdayOption(id: 2, value: 2, shortName: String(localized: "Tue", comment: "Tuesday"), fullName: String(localized: "Tuesday", comment: "Tuesday full")),
            WeekdayOption(id: 3, value: 3, shortName: String(localized: "Wed", comment: "Wednesday"), fullName: String(localized: "Wednesday", comment: "Wednesday full")),
            WeekdayOption(id: 4, value: 4, shortName: String(localized: "Thu", comment: "Thursday"), fullName: String(localized: "Thursday", comment: "Thursday full")),
            WeekdayOption(id: 5, value: 5, shortName: String(localized: "Fri", comment: "Friday"), fullName: String(localized: "Friday", comment: "Friday full")),
            WeekdayOption(id: 6, value: 6, shortName: String(localized: "Sat", comment: "Saturday"), fullName: String(localized: "Saturday", comment: "Saturday full")),
            WeekdayOption(id: 0, value: 0, shortName: String(localized: "Sun", comment: "Sunday"), fullName: String(localized: "Sunday", comment: "Sunday full"))
        ]
        
        // Reorder based on calendar's first weekday
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        if firstWeekday == 1 {
            // Sunday first
            return weekdays.sorted { (a: WeekdayOption, b: WeekdayOption) in
                let aValue = a.value == 0 ? 7 : a.value
                let bValue = b.value == 0 ? 7 : b.value
                return aValue < bValue
                    }
        } else {
            // Monday first
            return weekdays.sorted { (a: WeekdayOption, b: WeekdayOption) in
                let aValue = a.value == 0 ? 7 : a.value
                let bValue = b.value == 0 ? 7 : b.value
                return aValue < bValue
            }
        }
    }
    
    // MARK: - Generate Future Transactions
    private func generateFutureTransactions(from baseDraft: TransactionDraft) -> [TransactionDraft] {
        var futureDrafts: [TransactionDraft] = []
        let calendar = Calendar.current
        let today = Date()
        let startDate = baseDraft.date
        // Generate up to 1 year from TODAY, not from start date
        let endDate = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        
        // BUG FIX: Extract original day of month to preserve it across months
        // This prevents date drift (e.g., 30th -> 28th -> 28th should be 30th -> 28th -> 30th)
        let originalDay = calendar.component(.day, from: startDate)
        
        // Start from the first occurrence AFTER the start date
        var currentDate = calculateNextDate(
            from: startDate,
            frequency: repetitionFrequency,
            interval: repetitionInterval,
            weekdays: selectedWeekdays,
            originalDay: originalDay
        )
        
        // Ensure the first date is in the future (at least tomorrow)
        if currentDate <= today {
            // If the calculated date is today or in the past, calculate the next one
            currentDate = calculateNextDate(
                from: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                frequency: repetitionFrequency,
                interval: repetitionInterval,
                weekdays: selectedWeekdays,
                originalDay: originalDay
            )
        }
        
        var iterationCount = 0
        let maxIterations = 1000 // Safety limit to prevent infinite loops
        
        // Generate transactions until we reach the end date
        while currentDate <= endDate && iterationCount < maxIterations {
            iterationCount += 1
            
            // Only add transactions that are in the future
            if currentDate > today {
                // Create a new draft for this future date with a new ID
                let futureDraft = TransactionDraft(
                    id: UUID(),
                    title: baseDraft.title,
                    category: baseDraft.category,
                    amount: baseDraft.amount,
                    date: currentDate,
                    type: baseDraft.type,
                    accountId: baseDraft.accountId,
                    toAccountId: baseDraft.toAccountId,
                    currency: baseDraft.currency
                )
                futureDrafts.append(futureDraft)
            }
            
            // Calculate next date based on frequency - preserve originalDay to prevent date drift
            let nextDate = calculateNextDate(
                from: currentDate,
                frequency: repetitionFrequency,
                interval: repetitionInterval,
                weekdays: selectedWeekdays,
                originalDay: originalDay
            )
            
            // If next date hasn't advanced or is beyond end date, stop
            if nextDate <= currentDate || nextDate > endDate {
                break
            }
            
            currentDate = nextDate
        }
        
        return futureDrafts
    }
    
    // MARK: - Calculate Next Date
    private func calculateNextDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>,
        originalDay: Int? = nil
    ) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        switch frequency {
        case .day:
            // Add interval days
            var nextDate = calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            // Ensure it's in the future
            if nextDate <= today {
                // If the result is today or in the past, add one more interval
                nextDate = calendar.date(byAdding: .day, value: interval, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .week:
            if !weekdays.isEmpty {
                // Find the next matching weekday(s) after startDate
                var checkDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                let maxDaysToCheck = 14 // Check up to 2 weeks ahead
                var daysChecked = 0
                
                while daysChecked < maxDaysToCheck {
                    let checkWeekday = calendar.component(.weekday, from: checkDate)
                    let adjustedCheckWeekday = checkWeekday == 1 ? 7 : checkWeekday - 1
                    
                    if weekdays.contains(adjustedCheckWeekday) {
                        // Found a matching weekday
                        var resultDate = checkDate
                        // If interval > 1, we need to add (interval - 1) weeks because we already found the first occurrence
                        if interval > 1 {
                            resultDate = calendar.date(byAdding: .weekOfYear, value: interval - 1, to: checkDate) ?? checkDate
                        }
                        // Ensure it's in the future
                        if resultDate <= today {
                            // If still in past, find the next occurrence
                            resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                        }
                        return resultDate
                    }
                    
                    checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
                    daysChecked += 1
            }
            
                // If no matching weekday found in 2 weeks, fall back to adding interval weeks from start
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                // Ensure it's in the future
                if resultDate <= today {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            } else {
                // No weekdays selected, just add interval weeks
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                // Ensure it's in the future
                if resultDate <= today {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            }
            
        case .month:
            // BUG FIX: Preserve the original day of month to prevent date drift (e.g., 30th -> 28th -> 28th should be 30th -> 28th -> 30th)
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
            
        case .year:
            // BUG FIX: Preserve the original day of month to handle leap years correctly
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
        }
    }
    
    // MARK: - Category Picker Sheet
    @State private var expandedCategories: Set<UUID> = []
    
    private var categoryPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if availableCategories.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No categories available")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .padding(.top, 100)
                } else {
                        ForEach(availableCategories) { category in
                        VStack(spacing: 0) {
                            // Category itself (can be selected) - make entire row tappable to expand if has subcategories
                            Button {
                                if !category.subcategories.isEmpty {
                                    // Toggle expansion
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if expandedCategories.contains(category.id) {
                                            expandedCategories.remove(category.id)
                                        } else {
                                            expandedCategories.insert(category.id)
                                        }
                                    }
                                } else {
                                    // No subcategories, select directly
                                    draft.category = category.name
                                    showCategoryPicker = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    // Category icon
                    ZStack {
                        Circle()
                                            .fill(category.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                                        Image(systemName: category.iconName)
                                            .font(.title3)
                                            .foregroundStyle(category.color)
                    }
                                    
                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        
                                        if !category.subcategories.isEmpty {
                                            Text("\(category.subcategories.count) \(category.subcategories.count == 1 ? "subcategory" : "subcategories")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                                    
                Spacer()
                                    
                                    if !category.subcategories.isEmpty {
                                        // Show chevron for categories with subcategories
                                        Image(systemName: expandedCategories.contains(category.id) ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    } else if draft.category == category.name || draft.category.hasPrefix("\(category.name) >") {
                                        // Show checkmark if selected (category or any subcategory)
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(category.color)
                                            .font(.title3)
                                    }
            }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
            .background(Color.customCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
                            
                            // Subcategories (shown when expanded) - beautiful nested design
                            if expandedCategories.contains(category.id) && !category.subcategories.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(category.subcategories) { subcategory in
                                        Button {
                                            draft.category = "\(category.name) > \(subcategory.name)"
                                            showCategoryPicker = false
                                        } label: {
                                            HStack(spacing: 12) {
                                                // Subcategory icon - larger and more prominent
                                                ZStack {
                                                    Circle()
                                                        .fill(category.color.opacity(0.15))
                                                        .frame(width: 36, height: 36)
                                                    Image(systemName: subcategory.iconName)
                                                        .font(.subheadline)
                                                        .foregroundStyle(category.color)
                                                }
                                                
                                                Text(subcategory.name)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                
                                                Spacer()
                                                
                                                if draft.category == "\(category.name) > \(subcategory.name)" {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(category.color)
                                                        .font(.title3)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.customSecondaryBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.leading, 20)
                            }
                        }
                        .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .background(Color.customBackground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showCategoryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .environmentObject(settings)
    }
    
    private func accountPickerSheet(isFromAccount: Bool) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accounts) { account in
                        accountPickerItem(account: account, isFromAccount: isFromAccount)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(isFromAccount ? "Select From Account" : "Select To Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if isFromAccount {
                            showAccountPicker = false
                        } else {
                            showToAccountPicker = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func handleDebtSave() {
        guard let contact = selectedContact else { return }
        
        // Check if contact exists, if not add it
        if !debtManager.contacts.contains(where: { $0.id == contact.id }) {
            debtManager.addContact(contact)
        }
        
        let debtTransaction = DebtTransaction(
            id: UUID(),
            contactId: contact.id,
            amount: draft.amount,
            type: debtTransactionType,
            date: draft.date,
            note: draft.title.isEmpty ? nil : draft.title,
            accountId: draft.accountId,
            currency: draft.currency,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Update account balance based on debt type
        // Симметричная логика:
        // 1. Мне дали в долг (.borrowed) - деньги приходят на счёт (+)
        // 2. Мне вернули долг (.borrowedReturn) - деньги приходят на счёт (+)
        // Balance is updated automatically by CreateTransactionUseCase when transaction is created
        
        debtManager.addTransaction(debtTransaction)
        
        // Create corresponding Transaction (to avoid duplication, check if it already exists)
        let transactionTitle: String
        if draft.title.isEmpty {
            switch debtTransactionType {
            case .lent:
                transactionTitle = "Lent to \(contact.name)"
            case .lentReturn:
                transactionTitle = "Returned debt from \(contact.name)"
            case .borrowed:
                transactionTitle = "Borrowed from \(contact.name)"
            case .borrowedReturn:
                transactionTitle = "Returned debt to \(contact.name)"
            }
        } else {
            transactionTitle = draft.title
        }
        // Map debt transaction type to transaction type for balance updates
        // "Мне дали в долг" и "Мне вернули долг" → income (деньги приходят)
        // "Я дал в долг" и "Я вернул долг" → expense (деньги уходят)
        let regularTransactionType: TransactionType
        switch debtTransactionType {
        case .borrowed, .borrowedReturn:
            regularTransactionType = .income
        case .lent, .lentReturn:
            regularTransactionType = .expense
        }
        
        let regularTransaction = Transaction(
            id: debtTransaction.id, // Use same ID to link them
            title: transactionTitle,
            category: "Debt",
            amount: draft.amount,
            date: draft.date,
            type: regularTransactionType,
            accountId: draft.accountId,
            toAccountId: nil,
            currency: draft.currency
        )
        
        // Only create if it doesn't already exist
        if transactionManager.getTransaction(id: debtTransaction.id) == nil {
            transactionManager.addTransaction(regularTransaction)
        }
        
        dismiss()
    }
    
    private var contactPickerSheet: some View {
        NavigationStack {
            ScrollView {
                contactPickerList
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
    
    private var contactPickerList: some View {
        VStack(spacing: 8) {
            ForEach(debtManager.contacts) { contact in
                contactPickerItem(contact: contact)
            }
        }
        .padding()
    }
    
    private func contactPickerItem(contact: Contact) -> some View {
        Button {
            selectedContact = contact
            showContactPicker = false
        } label: {
            HStack {
                Circle()
                    .fill(contact.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.initials)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if selectedContact?.id == contact.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(selectedContact?.id == contact.id ? Color.blue.opacity(0.1) : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func accountPickerItem(account: Account, isFromAccount: Bool) -> some View {
        Button {
            if isFromAccount {
                draft.accountId = account.id
                showAccountPicker = false
            } else {
                draft.toAccountId = account.id
                showToAccountPicker = false
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: account.iconName)
                        .font(.title3)
                        .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(currencyString(account.balance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let isSelected = isFromAccount ? (draft.accountId == account.id) : (draft.toAccountId == account.id)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background({
                let isSelected = isFromAccount ? (draft.accountId == account.id) : (draft.toAccountId == account.id)
                return isSelected ? Color.accentColor.opacity(0.1) : Color.customCardBackground
            }())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke({
                        let isSelected = isFromAccount ? (draft.accountId == account.id) : (draft.toAccountId == account.id)
                        return isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08)
                    }(), lineWidth: {
                        let isSelected = isFromAccount ? (draft.accountId == account.id) : (draft.toAccountId == account.id)
                        return isSelected ? 1.5 : 1
                    }())
            )
        }
        .buttonStyle(.plain)
    }
    
    
}

struct AccountFormView: View {
    let account: Account?
    let onSave: (Account) -> Void
    let onCancel: () -> Void
    let onDelete: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var accountType: AccountType
    @State private var currency: String
    @State private var balance: Double
    @State private var includedInTotal: Bool
    @State private var isPinned: Bool
    @State private var isSavings: Bool
    @State private var selectedIcon: String
    @State private var showIconPicker = false
    @State private var showDeleteAlert = false
    
    init(account: Account?, onSave: @escaping (Account) -> Void, onCancel: @escaping () -> Void, onDelete: ((UUID) -> Void)? = nil) {
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        _name = State(initialValue: account?.name ?? "")
        _accountType = State(initialValue: account?.accountType ?? .card)
        _currency = State(initialValue: account?.currency ?? "USD")
        _balance = State(initialValue: account?.balance ?? 0)
        _includedInTotal = State(initialValue: account?.includedInTotal ?? true)
        _isPinned = State(initialValue: account?.isPinned ?? false)
        _isSavings = State(initialValue: account?.isSavings ?? false)
        _selectedIcon = State(initialValue: account?.iconName ?? CategoryIconLibrary.iconName(for: account?.accountType ?? .card))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.title)
                            }
                            .tag(type)
                        }
                    }
                    .onChange(of: accountType) { oldValue, newType in
                        // Update icon to default for new type if not custom
                        if selectedIcon == CategoryIconLibrary.iconName(for: oldValue) {
                            selectedIcon = CategoryIconLibrary.iconName(for: newType)
                        }
                    }
                    
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: selectedIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(["USD", "EUR", "PLN", "GBP"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    TextField("Current Balance", value: $balance, format: .number)
                        .keyboardType(.decimalPad)
                }
                
                Section("Settings") {
                    Toggle("Include in total balance", isOn: $includedInTotal)
                    Toggle("Pin account", isOn: $isPinned)
                    Toggle("Savings account", isOn: $isSavings)
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(account == nil ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                // Delete button (only when editing)
                if account != nil, onDelete != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedAccount = Account(
                            id: account?.id ?? UUID(),
                            name: name,
                            balance: balance,
                            includedInTotal: includedInTotal,
                            accountType: accountType,
                            currency: currency,
                            isPinned: isPinned,
                            isSavings: isSavings,
                            iconName: selectedIcon
                        )
                        onSave(updatedAccount)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(String(localized: "Delete Account", comment: "Delete account alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    if let accountId = account?.id {
                        onDelete?(accountId)
                        dismiss()
                    }
                }
            } message: {
                Text(String(localized: "Are you sure you want to delete this account? All associated transactions will also be deleted. This action cannot be undone.", comment: "Delete account confirmation"))
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    icons: CategoryIconLibrary.accountIcons,
                    selectedIcon: $selectedIcon,
                    title: String(localized: "Select Account Icon", comment: "Select account icon title")
                )
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Transaction Form Components

struct TransactionCategoryChip: View {
    let category: Category
    let isSelected: Bool
    let typeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color.opacity(0.2) : category.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.iconName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? category.color : category.color.opacity(0.7))
                }
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? category.color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TransactionFormRow: View {
    let icon: String
    let title: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            TextField(placeholder, text: $value)
                .font(.body)
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct TransactionDateRow: View {
    let icon: String
    let title: String
    @Binding var date: Date
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct TransactionContactRow: View {
    let icon: String
    let title: String
    let contact: Contact?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let contact = contact {
                    Circle()
                        .fill(contact.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(contact.initials)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        )
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(contact.name)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TransactionCategoryRow: View {
    let icon: String
    let title: String
    let category: Category?
    let categoryName: String // Full category name including subcategory
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let category = category {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: category.iconName)
                            .font(.subheadline)
                            .foregroundStyle(category.color)
                    }
                    .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(categoryName.isEmpty ? category.name : categoryName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TransactionAccountRow: View {
    let icon: String
    let title: String
    let account: Account?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let account = account {
                    ZStack {
                        Circle()
                            .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
                    }
                    .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(account.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TransactionCurrencyRow: View {
    let icon: String
    let title: String
    @Binding var currency: String
    
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "INR", "PLN", "RUB", "BRL", "MXN", "KRW", "SGD", "HKD", "NZD", "SEK", "NOK", "DKK"]
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Picker("", selection: $currency) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AccountDetailsView: View {
    let account: Account
    @State private var showAccountForm = false
    @State private var showBalanceEditor = false
    @State private var editedBalance: Double
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    @State private var pendingEditMode: TransactionFormMode?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var creditManager: CreditManager
    @EnvironmentObject var debtManager: DebtManager
    
    private var currentAccount: Account? {
        accountManager.accounts.first { $0.id == account.id }
    }
    
    init(account: Account) {
        self.account = account
        _editedBalance = State(initialValue: account.balance)
    }
    
    private var accountTransactions: [Transaction] {
        let today = Date()
        
        return transactionManager.transactions
            .filter { transaction in
                // Filter by account ID (from account or to account for transfers)
                let matchesAccount = transaction.accountId == account.id || transaction.toAccountId == account.id
                
                if !matchesAccount {
                    return false
                }
                
                // Only show actual (executed) transactions, not future scheduled ones
                // Show transactions that have already occurred (date <= today)
                return transaction.date <= today
            }
            .sorted { $0.date > $1.date } // Sort by date descending (newest first)
    }
    
    private func deleteAccount(_ accountId: UUID) {
        // Delete all transactions associated with this account
        transactionManager.transactions.removeAll { transaction in
            transaction.accountId == account.id || transaction.toAccountId == account.id
        }
        // Delete the account
        accountManager.deleteAccount(accountId)
        // Dismiss the view
        dismiss()
    }
    
    private func deleteTransactionFromAccount(_ transaction: Transaction) {
        // If it's a debt transaction, also delete the corresponding DebtTransaction
        if transaction.type == .debt {
            if let debtTransaction = debtManager.transactions.first(where: { $0.id == transaction.id }) {
                // Balance is reverted automatically by DeleteTransactionUseCase
                debtManager.deleteTransaction(debtTransaction)
            }
        }
        
        transactionManager.deleteTransaction(transaction)
        // Balance is reverted automatically by DeleteTransactionUseCase
    }
    
    private var totalIncome: Double {
        accountTransactions
            .filter { $0.type == .income }
            .map(\.amount)
            .reduce(0, +)
    }
    
    private var totalExpense: Double {
        accountTransactions
            .filter { $0.type == .expense }
            .map(\.amount)
            .reduce(0, +)
    }
    
    private var categories: [String] {
        Array(Set(transactionManager.transactions.map(\.category))).sorted()
    }
    
    private func startEditing(_ transaction: Transaction) {
        // If sheet is already open, store the pending mode and close the sheet
        if showTransactionForm {
            pendingEditMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = false
        } else {
            // Sheet is closed, set mode and open immediately
            currentFormMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = true
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactionManager.addTransaction(newTransaction)
        case .edit(let id):
            let updated = draft.toTransaction(existingId: id)
            transactionManager.updateTransaction(updated)
        }
        
        // Balance is updated automatically by UpdateTransactionUseCase or CreateTransactionUseCase
        
        showTransactionForm = false
        pendingEditMode = nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with balance
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(currentAccount?.name ?? account.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            showAccountForm = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                    }
                    Text(currentAccount?.accountType.title ?? account.accountType.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Balance card with quick edit
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Current Balance", comment: "Current balance label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(currencyString(currentAccount?.balance ?? account.balance, code: settings.currency))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            editedBalance = currentAccount?.balance ?? account.balance
                            showBalanceEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Color.customSecondaryBackground)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(Color.customCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
                
                // Stats
                HStack(spacing: 12) {
                    statCard(title: "Income", value: currencyString(totalIncome, code: settings.currency), color: .green)
                    statCard(title: "Expense", value: currencyString(totalExpense, code: settings.currency), color: .red)
                }
                
                // Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transactions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    if accountTransactions.isEmpty {
                        VStack(spacing: 8) {
                            Text(String(localized: "No transactions yet", comment: "No transactions message"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                            ForEach(accountTransactions) { transaction in
                            Button {
                                startEditing(transaction)
                            } label: {
                                // Вычисляем accountName и categoryIconName на месте для AccountDetailsView
                                let accountName = transaction.accountName(accountManager: accountManager)
                                let categoryIconName: String = {
                                    if transaction.type == .transfer {
                                        return "arrow.left.arrow.right"
                                    } else if transaction.category.contains(" > ") {
                                        let parts = transaction.category.split(separator: " > ")
                                        let categoryName = String(parts[0])
                                        let subcategoryName = String(parts[1])
                                        
                                        if let category = settings.categories.first(where: { $0.name == categoryName }),
                                           let subcategory = category.subcategories.first(where: { $0.name == subcategoryName }) {
                                            return subcategory.iconName
                                        } else if let category = settings.categories.first(where: { $0.name == categoryName }) {
                                            return category.iconName
                                        } else {
                                            return transaction.type.iconName
                                        }
                                    } else {
                                        if let category = settings.categories.first(where: { $0.name == transaction.category }) {
                                            return category.iconName
                                        } else {
                                            return transaction.type.iconName
                                        }
                                    }
                                }()
                                
                                TransactionRow(
                                    transaction: transaction,
                                    accountName: accountName,
                                    categoryIconName: categoryIconName
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransactionFromAccount(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .id(transaction.id)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.customBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAccountForm) {
            AccountFormView(
                account: currentAccount ?? account,
                onSave: { updatedAccount in
                    // Update account with transaction manager to sync transaction names
                    accountManager.updateAccount(updatedAccount, transactionManager: transactionManager)
                    showAccountForm = false
                },
                onCancel: {
                    showAccountForm = false
                },
                onDelete: { accountId in
                    deleteAccount(accountId)
                    showAccountForm = false
                }
            )
        }
        .sheet(isPresented: $showBalanceEditor) {
            NavigationStack {
                Form {
                    Section("Balance") {
                        TextField("Balance", value: $editedBalance, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                .background(Color.customBackground)
                .scrollContentBackground(.hidden)
                .navigationTitle("Edit Balance")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editedBalance = currentAccount?.balance ?? account.balance
                            showBalanceEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if var updatedAccount = accountManager.getAccount(id: account.id) {
                                updatedAccount.balance = editedBalance
                                accountManager.updateAccount(updatedAccount)
                            }
                            showBalanceEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showTransactionForm) {
            TransactionFormView(
                draft: $draftTransaction,
                mode: currentFormMode,
                categories: categories,
                accounts: accountManager.accounts,
                onSave: { draft in
                    handleSave(draft)
                },
                onCancel: {
                    showTransactionForm = false
                    pendingEditMode = nil
                },
                onDelete: { id in
                    if let transaction = transactionManager.transactions.first(where: { $0.id == id }) {
                        deleteTransactionFromAccount(transaction)
                    }
                    showTransactionForm = false
                    pendingEditMode = nil
                }
            )
            .environmentObject(transactionManager)
            .id(currentFormMode) // Force recreation when mode changes
        }
        .onChange(of: showTransactionForm) { oldValue, newValue in
            // When sheet closes, check if we have a pending edit mode
            if !newValue, let pendingMode = pendingEditMode {
                // Sheet just closed, now set the mode and reopen
                currentFormMode = pendingMode
                pendingEditMode = nil
                // Use a small delay to ensure sheet fully closes before reopening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showTransactionForm = true
                }
            }
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

