//
//  SubscriptionsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Combine

enum SubscriptionMode: String, CaseIterable {
    case expenses = "Expenses"
    case income = "Income"
    
    var localizedTitle: String {
        switch self {
        case .expenses:
            return String(localized: "Expenses", comment: "Expenses mode")
        case .income:
            return String(localized: "Income", comment: "Income mode")
        }
    }
}

struct SubscriptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var manager: SubscriptionManager
    @EnvironmentObject var accountManager: AccountManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var creditManager: CreditManager
    @State private var showAddSheet = false
    @State private var selectedSubscription: PlannedPayment?
    @State private var selectedOccurrenceDate: Date? // The specific occurrence date when paying early
    @State private var selectedMode: SubscriptionMode = .expenses
    @State private var expandedMonths: Set<String> = [] // Track which months are expanded
    @State private var scheduledTransactionToDelete: Transaction? // For delete confirmation
    @State private var plannedPaymentToDelete: PlannedPayment? // For delete confirmation
    @State private var showDeleteScheduledAlert = false
    
    // Filtered subscriptions based on selected mode
    private var filteredSubscriptions: [PlannedPayment] {
        let calendar = Calendar.current
        let subscriptions = manager.subscriptions(isIncome: selectedMode == .income)
        
        // Filter out PlannedPayments that have been terminated via "Delete All Future"
        // When endDate is set to (selectedDate - 1 day), we exclude payments where payment.date >= selectedDate
        // This means we exclude payments where payment.date > endDate
        return subscriptions.filter { payment in
            guard let endDate = payment.endDate else {
                // No endDate set, include the payment
                return true
            }
            // Exclude if payment's date is > endDate (meaning it was deleted via "Delete All Future")
            // Since endDate = selectedDate - 1 day, this excludes date >= selectedDate
            let paymentDate = calendar.startOfDay(for: payment.date)
            let endDateStart = calendar.startOfDay(for: endDate)
            return paymentDate <= endDateStart
        }
    }
    
    // CLEAN: Scheduled occurrences - SAME as Future tab
    // Use ONLY SubscriptionManager.upcomingTransactions (single source of truth)
    private var scheduledOccurrences: [Transaction] {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        let ninetyDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -90, to: today) ?? today)
        
        // Use ONLY upcomingTransactions - this is the single source of truth
        return manager.upcomingTransactions
            .filter { transaction in
                // Filter by income/expense mode
                let matchesMode = (selectedMode == .income && transaction.type == .income) ||
                                 (selectedMode == .expenses && transaction.type == .expense)
                
                // Include if: matches mode AND (within last 90 days OR today/future)
                let transactionDateStart = calendar.startOfDay(for: transaction.date)
                let isRecentOrFuture = transactionDateStart >= ninetyDaysAgo || transactionDateStart >= todayStart
                
                return matchesMode && isRecentOrFuture
            }
            .sorted { $0.date < $1.date }
    }
    
    // Group subscriptions and scheduled occurrences by month
    // CRITICAL: This shows the SAME data as the Future tab - they are synchronized
    private var groupedByMonth: [(monthKey: String, monthStart: Date, items: [Any])] {
        let calendar = Calendar.current
        var allItems: [(date: Date, item: Any)] = []
        
        // CRITICAL FIX: Track transaction IDs to prevent duplicates
        var seenTransactionIds: Set<UUID> = []
        var seenPlannedPaymentIds: Set<UUID> = []
        
        // Add scheduled occurrences (future transactions from repeating payments)
        // This is the SAME data shown in Transactions > Future tab
        // CRITICAL: For repeating subscriptions, we only show the generated Transaction occurrences
        // NOT the original PlannedPayment (which would cause duplicates)
        for transaction in scheduledOccurrences {
            // Skip if we've already seen this transaction ID
            if seenTransactionIds.contains(transaction.id) {
                continue
            }
            seenTransactionIds.insert(transaction.id)
            
            let date = calendar.startOfDay(for: transaction.date)
            allItems.append((date: date, item: transaction))
        }
        
        // Add ONLY non-repeating PlannedPayments (repeating ones are shown via scheduledOccurrences above)
        // This prevents duplicates: repeating subscriptions show as Transactions, non-repeating show as PlannedPayments
        for subscription in filteredSubscriptions {
            // Only add if it's NOT repeating (repeating ones are already shown as Transactions)
            if !subscription.isRepeating {
                // Skip if we've already seen this PlannedPayment ID
                if seenPlannedPaymentIds.contains(subscription.id) {
                    continue
                }
                seenPlannedPaymentIds.insert(subscription.id)
                
                let date = calendar.startOfDay(for: subscription.date)
                allItems.append((date: date, item: subscription))
            }
        }
        
        // Group by month
        let grouped = Dictionary(grouping: allItems) { item in
            let date = item.date
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: monthStart)
        }
        
        return grouped
            .map { (monthKey: $0.key, monthStart: calendar.date(from: calendar.dateComponents([.year, .month], from: $0.value.first?.date ?? Date())) ?? Date(), items: $0.value.map { $0.item }.sorted { item1, item2 in
                // Items can be Transactions (scheduled occurrences) or PlannedPayments
                let date1: Date = (item1 as? Transaction)?.date ?? (item1 as? PlannedPayment)?.date ?? Date()
                let date2: Date = (item2 as? Transaction)?.date ?? (item2 as? PlannedPayment)?.date ?? Date()
                return date1 < date2
            }) }
            .sorted { $0.monthStart < $1.monthStart }
    }
    
    // Initialize expanded months (current month and next month)
    private func initializeExpandedMonths() {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        expandedMonths.insert(formatter.string(from: currentMonth))
        expandedMonths.insert(formatter.string(from: nextMonth))
    }
    
    // Toggle month expansion
    private func toggleMonth(_ monthKey: String) {
        if expandedMonths.contains(monthKey) {
            expandedMonths.remove(monthKey)
        } else {
            expandedMonths.insert(monthKey)
        }
    }
    
    // Check if month is expanded
    private func isMonthExpanded(_ monthKey: String) -> Bool {
        expandedMonths.contains(monthKey)
    }
    
    // Format month header
    private func monthHeader(for monthStart: Date) -> String {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? today
        
        if calendar.isDate(monthStart, equalTo: currentMonth, toGranularity: .month) {
            return String(localized: "This Month", comment: "This month header")
        } else if calendar.isDate(monthStart, equalTo: nextMonth, toGranularity: .month) {
            return String(localized: "Next Month", comment: "Next month header")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: monthStart)
        }
    }
    
    // Helper function to format date header (matching TransactionsView)
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
    
    // MARK: - Subscriptions List Content
    private var subscriptionsListContent: some View {
        Group {
            if groupedByMonth.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text(selectedMode == .expenses ? String(localized: "No active expenses", comment: "No active expenses") : String(localized: "No active income", comment: "No active income"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                subscriptionsListGrouped
            }
        }
    }
    
    // MARK: - Subscriptions List Grouped
    private var subscriptionsListGrouped: some View {
        ForEach(Array(groupedByMonth.enumerated()), id: \.element.monthKey) { index, monthGroup in
            monthGroupView(index: index, monthGroup: monthGroup)
        }
    }
    
    // MARK: - Month Group View
    private func monthGroupView(index: Int, monthGroup: (monthKey: String, monthStart: Date, items: [Any])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month Header with Expand/Collapse
            Button {
                toggleMonth(monthGroup.monthKey)
            } label: {
                HStack {
                    Text(monthHeader(for: monthGroup.monthStart))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isMonthExpanded(monthGroup.monthKey) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, index == 0 ? 8 : 16)
            .padding(.bottom, 8)
            
            // Items for this month (only show if expanded)
            if isMonthExpanded(monthGroup.monthKey) {
                monthItemsView(items: monthGroup.items)
            }
        }
    }
    
    // MARK: - Month Items View
    private func monthItemsView(items: [Any]) -> some View {
        let calendar = Calendar.current
        let dayGrouped = Dictionary(grouping: items) { item -> Date in
            // Handle both Transactions and PlannedPayments
            if let transaction = item as? Transaction {
                return calendar.startOfDay(for: transaction.date)
            } else if let payment = item as? PlannedPayment {
                return calendar.startOfDay(for: payment.date)
            } else {
                return Date()
            }
        }
        
        let sortedDays = dayGrouped.keys.sorted()
        
        return ForEach(Array(sortedDays.enumerated()), id: \.element) { dayIndex, day in
            dayGroupView(dayIndex: dayIndex, day: day, items: dayGrouped[day] ?? [])
        }
    }
    
    // MARK: - Day Group View
    private func dayGroupView(dayIndex: Int, day: Date, items: [Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day Header
            dayHeader(for: day)
                .padding(.horizontal, 20)
                .padding(.top, dayIndex == 0 ? 0 : 12)
                .padding(.bottom, 4)
            
            // Items for this day
            ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                dayItemView(item: item)
            }
        }
    }
    
    // MARK: - Day Item View
    @ViewBuilder
    private func dayItemView(item: Any) -> some View {
        if let transaction = item as? Transaction {
            // Scheduled transaction
            Button {
                let occurrenceDate = transaction.occurrenceDate ?? transaction.date
                if let sourcePayment = findSourcePlannedPayment(for: transaction) {
                    selectedOccurrenceDate = occurrenceDate
                    selectedSubscription = sourcePayment
                }
            } label: {
                TransactionRow(transaction: transaction)
                    .opacity(0.8)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    scheduledTransactionToDelete = transaction
                    showDeleteScheduledAlert = true
                } label: {
                    Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
                }
            }
            .padding(.bottom, 8)
        } else if let subscription = item as? PlannedPayment {
            // Original PlannedPayment
            Button {
                selectedOccurrenceDate = subscription.date
                selectedSubscription = subscription
            } label: {
                SubscriptionRow(subscription: subscription)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    if subscription.isRepeating {
                        plannedPaymentToDelete = subscription
                        showDeleteScheduledAlert = true
                    } else {
                        manager.deleteSubscription(subscription)
                    }
                } label: {
                    Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
                }
            }
            .id(subscription.id)
            .padding(.bottom, 8)
        }
    }
    
    var body: some View {
        ZStack {
            // Bottom Layer: Background
            Color.customBackground.ignoresSafeArea()
            
            // Middle Layer: Scrollable Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Top anchor for scroll reset
                        Color.clear
                            .frame(height: 0)
                            .id("top")
                        
                        // Segmented Control (Expenses/Income)
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(SubscriptionMode.allCases, id: \.self) { mode in
                                Text(mode.localizedTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Monthly Burn Rate Summary Card
                    VStack(alignment: .leading, spacing: 8) {
                            Text(selectedMode == .expenses ? String(localized: "Monthly Burn Rate", comment: "Monthly burn rate label") : String(localized: "Monthly Projected Income", comment: "Monthly projected income label"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(currencyString(
                            selectedMode == .expenses ? manager.monthlyBurnRate : manager.monthlyProjectedIncome,
                            code: settings.currency
                        ))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(selectedMode == .expenses ? .red : .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.customCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                    
                    // Item 3: Subscriptions List (Grouped by Date - matching TransactionsView)
                    subscriptionsListContent
                    }
                    .padding(.bottom, 100) // Space for FAB button
                }
                .onAppear {
                    // Initialize expanded months (current and next month)
                    if expandedMonths.isEmpty {
                        initializeExpandedMonths()
                    }
                    // Reset scroll position when view appears
                    proxy.scrollTo("top", anchor: .top)
                    // Clean up old transactions and regenerate
                    manager.cleanupOldTransactions(in: transactionManager)
                    manager.generateUpcomingTransactions()
                }
            }
            
            // Standardized Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // --- BUTTON ---
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56) // Fixed standard size
                            .background(
                                Circle()
                                    .fill(Color.purple) // <--- Change this per view
                                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 6)
                            )
                    }
                    // ----------------
                }
                .padding(.trailing, 20) // Fixed right margin
                .padding(.bottom, 110)   // Fixed bottom margin (optimized for thumb reach)
            }
            .ignoresSafeArea() // CRITICAL: Pins button relative to screen edge, ignoring layout differences
        }
        .navigationTitle(Text("Subscriptions", comment: "Subscriptions view title"))
        .sheet(isPresented: $showAddSheet) {
            CustomSubscriptionFormView(
                paymentType: .subscription,
                existingPayment: nil,
                initialIsIncome: selectedMode == .income,
                onSave: { newSubscription in
                    manager.addSubscription(newSubscription)
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
            .environmentObject(settings)
            .environmentObject(accountManager)
        }
        .sheet(item: $selectedSubscription) { subscription in
            CustomSubscriptionFormView(
                paymentType: .subscription,
                existingPayment: subscription,
                initialIsIncome: subscription.isIncome,
                occurrenceDate: selectedOccurrenceDate,
                onSave: { updatedSubscription in
                    manager.updateSubscription(updatedSubscription)
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                },
                onCancel: {
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                },
                onDelete: { paymentToDelete in
                    // If it's a repeating payment, show confirmation modal
                    if paymentToDelete.isRepeating {
                        plannedPaymentToDelete = paymentToDelete
                        showDeleteScheduledAlert = true
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    } else {
                        // Non-repeating, delete directly
                        manager.deleteSubscription(paymentToDelete)
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    }
                },
                onPay: { occurrenceDate in
                    // Pay early: create transaction and skip the occurrence
                    manager.payEarly(subscription: subscription, occurrenceDate: occurrenceDate, transactionManager: transactionManager, creditManager: creditManager, accountManager: accountManager, currency: settings.currency)
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                }
            )
            .environmentObject(settings)
            .environmentObject(accountManager)
        }
        .alert(String(localized: "Delete scheduled transaction?", comment: "Delete scheduled transaction alert title"), isPresented: $showDeleteScheduledAlert) {
            Button(String(localized: "Delete Only This", comment: "Delete only this occurrence")) {
                if let transaction = scheduledTransactionToDelete {
                    handleDeleteOnlyThisScheduled(transaction)
                } else if let payment = plannedPaymentToDelete {
                    handleDeleteOnlyThisPlannedPayment(payment)
                }
            }
            
            // Only show "Delete All Future" if there are future occurrences
            if let transaction = scheduledTransactionToDelete, hasFutureOccurrences(after: transaction) {
                Button(String(localized: "Delete All Future", comment: "Delete all future occurrences")) {
                    handleDeleteAllFuture(transaction)
                }
            } else if let payment = plannedPaymentToDelete, hasFutureOccurrencesForPayment(payment) {
                Button(String(localized: "Delete All Future", comment: "Delete all future occurrences")) {
                    handleDeleteAllFutureForPayment(payment)
                }
            }
            
            Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
                scheduledTransactionToDelete = nil
                plannedPaymentToDelete = nil
            }
        } message: {
            Text(String(localized: "Delete only this occurrence or the entire chain of future repeats?", comment: "Delete scheduled transaction confirmation message"))
        }
    }
    
    // MARK: - Delete Handlers
    
    // MARK: - Unified Deletion Handlers (REQUIREMENT D & E)
    // These use the shared SubscriptionManager functions for consistent behavior
    
    // Handle delete all future scheduled payments (terminate chain from this date forward)
    private func handleDeleteAllFuture(_ transaction: Transaction) {
        // Use unified deletion function (REQUIREMENT D)
        var subscriptionId: UUID?
        var transactionDate: Date?
        
        if let id = transaction.sourcePlannedPaymentId {
            subscriptionId = id
            let calendar = Calendar.current
            transactionDate = calendar.startOfDay(for: transaction.date)
        } else if let sourcePayment = findSourcePlannedPayment(for: transaction) {
            // Fallback for legacy transactions
            subscriptionId = sourcePayment.id
            let calendar = Calendar.current
            transactionDate = calendar.startOfDay(for: transaction.date)
        }
        
        if let id = subscriptionId, let date = transactionDate {
            // REQUIREMENT E.2: Delete all occurrences with date >= transactionDate
            manager.deleteAllFuture(subscriptionId: id, fromDate: date)
            // Force UI refresh in both Planned and Future tabs
            manager.objectWillChange.send()
            // Regenerate to ensure both tabs see the update immediately
            manager.generateUpcomingTransactions()
            
            // CRITICAL: Also remove all matching transactions from TransactionManager
            // This handles old subscription transactions that were saved before the refactoring
            let calendar = Calendar.current
            let transactionDateStart = calendar.startOfDay(for: transaction.date)
            let matchingTransactions = transactionManager.transactions.filter { txn in
                // Check if this transaction matches the subscription pattern
                if let sourceId = txn.sourcePlannedPaymentId, sourceId == id {
                    let txnDateStart = calendar.startOfDay(for: txn.date)
                    return txnDateStart >= transactionDateStart
                } else if let sourcePayment = findSourcePlannedPayment(for: txn), sourcePayment.id == id {
                    let txnDateStart = calendar.startOfDay(for: txn.date)
                    return txnDateStart >= transactionDateStart
                }
                return false
            }
            
            for matchingTransaction in matchingTransactions {
                transactionManager.deleteTransaction(matchingTransaction)
            }
        }
        
        scheduledTransactionToDelete = nil
        plannedPaymentToDelete = nil
    }
    
    // Handle delete all future for a PlannedPayment directly (terminate chain from payment's date forward)
    private func handleDeleteAllFutureForPayment(_ payment: PlannedPayment) {
        // Use unified deletion function (REQUIREMENT D)
        let calendar = Calendar.current
        let paymentDate = calendar.startOfDay(for: payment.date)
        let today = calendar.startOfDay(for: Date())
        
        // If payment date is in the past, terminate from today to preserve past transactions
        let fromDate = paymentDate >= today ? paymentDate : today
        manager.deleteAllFuture(subscriptionId: payment.id, fromDate: fromDate)
        // Force UI refresh in both Planned and Future tabs
        manager.objectWillChange.send()
        // Regenerate to ensure both tabs see the update immediately
        manager.generateUpcomingTransactions()
        
        scheduledTransactionToDelete = nil
        plannedPaymentToDelete = nil
    }
    
    // Handle delete only this occurrence
    private func handleDeleteOnlyThisScheduled(_ transaction: Transaction) {
        // Use unified deletion function (REQUIREMENT D)
        var subscriptionId: UUID?
        let calendar = Calendar.current
        
        // CRITICAL FIX: Always use the transaction's date
        let transactionDate = calendar.startOfDay(for: transaction.date)
        
        // Try to find subscription ID
        if let id = transaction.sourcePlannedPaymentId {
            // Direct lookup - most reliable
            subscriptionId = id
        } else if let sourcePayment = findSourcePlannedPayment(for: transaction) {
            // Fallback for legacy transactions
            subscriptionId = sourcePayment.id
        } else {
            // Last resort: Try to find by matching transaction details
            if let matchingSubscription = manager.subscriptions.first(where: { sub in
                sub.isRepeating &&
                transaction.title == sub.title &&
                abs(transaction.amount - sub.amount) < 0.01 &&
                transaction.accountName == sub.accountName &&
                transaction.type == (sub.isIncome ? .income : .expense)
            }) {
                subscriptionId = matchingSubscription.id
            }
        }
        
        // CRITICAL FIX: Always attempt deletion - we always have a date
        // This ensures subsequent deletions work even after the first deletion
        let date = transactionDate
        
        if let id = subscriptionId {
            // Normal path: delete via SubscriptionManager
            manager.deleteOccurrence(subscriptionId: id, occurrenceDate: date)
            manager.objectWillChange.send()
            manager.generateUpcomingTransactions()
        } else {
            // Fallback: If we can't find the subscription, try to find it by matching details
            if let matchingSubscription = manager.subscriptions.first(where: { sub in
                sub.isRepeating &&
                transaction.title == sub.title &&
                abs(transaction.amount - sub.amount) < 0.01 &&
                transaction.accountName == sub.accountName &&
                transaction.type == (sub.isIncome ? .income : .expense)
            }) {
                manager.deleteOccurrence(subscriptionId: matchingSubscription.id, occurrenceDate: date)
                manager.objectWillChange.send()
                manager.generateUpcomingTransactions()
            } else {
                // Last resort: At least remove from TransactionManager and regenerate
                if transactionManager.transactions.contains(where: { $0.id == transaction.id }) {
                    transactionManager.deleteTransaction(transaction)
                }
                manager.generateUpcomingTransactions()
            }
        }
        
        // CRITICAL: Also remove the transaction from TransactionManager if it exists there
        // This handles old subscription transactions that were saved before the refactoring
        if transactionManager.transactions.contains(where: { $0.id == transaction.id }) {
            transactionManager.deleteTransaction(transaction)
        }
        
        scheduledTransactionToDelete = nil
        plannedPaymentToDelete = nil
    }
    
    // Handle delete only this occurrence for a PlannedPayment directly
    private func handleDeleteOnlyThisPlannedPayment(_ payment: PlannedPayment) {
        // Use unified deletion function (REQUIREMENT D)
        let calendar = Calendar.current
        let paymentDate = calendar.startOfDay(for: payment.date)
        manager.deleteOccurrence(subscriptionId: payment.id, occurrenceDate: paymentDate)
        // Force UI refresh in both Planned and Future tabs
        manager.objectWillChange.send()
        // Regenerate to ensure both tabs see the update immediately
        manager.generateUpcomingTransactions()
        
        scheduledTransactionToDelete = nil
        plannedPaymentToDelete = nil
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
    
    // MARK: - Helper Functions for Scheduled Occurrences
    
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
        let weekdays = payment.selectedWeekdays.map { Set($0) } ?? []
        
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
            calendar.isDate(startDateStart, inSameDayAs: skippedDate)
        }
        
        // Include first occurrence if:
        // 1. It's in the future (or today)
        // 2. It's not skipped
        // 3. It's within the endDate range
        // CRITICAL FIX: Use generateOccurrenceId for deterministic IDs
        if startDateStart >= todayStart && !isStartDateSkipped && startDateStart <= actualEndDateStart {
            let transaction = Transaction(
                id: SubscriptionManager.generateOccurrenceId(subscriptionId: payment.id, occurrenceDate: startDate),
                title: payment.title,
                category: payment.category ?? "General",
                amount: payment.amount,
                date: startDate,
                type: payment.isIncome ? .income : .expense,
                accountName: payment.accountName,
                toAccountName: nil,
                currency: settings.currency,
                sourcePlannedPaymentId: payment.id,
                occurrenceDate: startDate
            )
            occurrences.append(transaction)
        }
        
        // Now generate subsequent occurrences: startDate + interval, startDate + 2×interval, etc.
        // Start from the first occurrence after startDate
        var currentDate = calculateScheduledNextDate(
            from: startDate,
            frequency: frequency,
            interval: interval,
            weekdays: weekdays
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
                calendar.isDate(currentDate, inSameDayAs: skippedDate)
            }
            
            // Only include occurrences that are in the future and not skipped
            // Also ensure currentDate <= actualEndDate (which excludes date >= selectedDate when endDate is set)
            // CRITICAL FIX: Use startOfDay for consistent date comparisons
            let currentDateStart = calendar.startOfDay(for: currentDate)
            if currentDateStart >= todayStart && !isSkipped && currentDateStart <= actualEndDateStart {
                // Create a transaction for this occurrence
                // CRITICAL FIX: Use generateOccurrenceId for deterministic IDs
                let transaction = Transaction(
                    id: SubscriptionManager.generateOccurrenceId(subscriptionId: payment.id, occurrenceDate: currentDate),
                    title: payment.title,
                    category: payment.category ?? "General",
                    amount: payment.amount,
                    date: currentDate,
                    type: payment.isIncome ? .income : .expense,
                    accountName: payment.accountName,
                    toAccountName: nil,
                    currency: settings.currency,
                    sourcePlannedPaymentId: payment.id,
                    occurrenceDate: currentDate
                )
                occurrences.append(transaction)
            }
            
            // Calculate next date
            let nextDate = calculateScheduledNextDate(
                from: currentDate,
                frequency: frequency,
                interval: interval,
                weekdays: weekdays
            )
            
            // Stop if next date would exceed endDate or if we can't progress
            if nextDate <= currentDate || nextDate > actualEndDate {
                break
            }
            
            currentDate = nextDate
        }
        
        return occurrences
    }
    
    // Calculate next scheduled date
    // CRITICAL FIX: Use startOfDay for consistent date comparisons to match SubscriptionManager logic
    private func calculateScheduledNextDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        switch frequency {
        case .day:
            var nextDate = calendar.date(byAdding: .day, value: interval, to: startDate) ?? startDate
            let nextDateStart = calendar.startOfDay(for: nextDate)
            // CRITICAL FIX: Use < (exclusive) to ensure today is included
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
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                let resultDateStart = calendar.startOfDay(for: resultDate)
                // CRITICAL FIX: Use < (exclusive) to ensure today is included
                if resultDateStart < todayStart {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            } else {
                var resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                let resultDateStart = calendar.startOfDay(for: resultDate)
                // CRITICAL FIX: Use < (exclusive) to ensure today is included
                if resultDateStart < todayStart {
                    resultDate = calendar.date(byAdding: .weekOfYear, value: interval, to: resultDate) ?? resultDate
                }
                return resultDate
            }
            
        case .month:
            // CRITICAL FIX: Preserve original day to prevent date drift (e.g., 31st -> 28th -> 31st)
            let originalDay = calendar.component(.day, from: startDate)
            let targetDate = calendar.date(byAdding: .month, value: interval, to: startDate) ?? startDate
            
            // Get the target month/year
            let targetComponents = calendar.dateComponents([.year, .month], from: targetDate)
            
            // Try to set the original day
            var components = targetComponents
            components.day = originalDay
            
            // Check if the target month has enough days
            if let daysInMonth = calendar.range(of: .day, in: .month, for: targetDate)?.count {
                components.day = min(originalDay, daysInMonth)
            }
            
            var nextDate = calendar.date(from: components) ?? targetDate
            let nextDateStart = calendar.startOfDay(for: nextDate)
            
            // CRITICAL FIX: Use < (exclusive) to ensure today is included
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
            // CRITICAL FIX: Preserve original day to handle leap years correctly
            let originalDay = calendar.component(.day, from: startDate)
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
            let nextDateStart = calendar.startOfDay(for: nextDate)
            
            // CRITICAL FIX: Use < (exclusive) to ensure today is included
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
    
    // Find the source PlannedPayment for a scheduled transaction
    // ISSUE 2 FIX: Use sourcePlannedPaymentId for direct, reliable lookup
    private func findSourcePlannedPayment(for transaction: Transaction) -> PlannedPayment? {
        // First, try direct lookup using sourcePlannedPaymentId (most reliable)
        if let sourceId = transaction.sourcePlannedPaymentId {
            return manager.subscriptions.first { $0.id == sourceId }
        }
        
        // Fallback: Legacy matching for transactions created before this fix
        // Check all repeating planned payments
        let repeatingPayments = manager.subscriptions.filter { $0.isRepeating }
        
        for payment in repeatingPayments {
            // Check if transaction matches this payment's details
            if transaction.title == payment.title &&
               transaction.category == (payment.category ?? "General") &&
               transaction.accountName == payment.accountName &&
               abs(transaction.amount - payment.amount) < 0.01 {
                // Check if the date matches the repetition pattern
                guard let frequencyString = payment.repetitionFrequency,
                      let frequency = RepetitionFrequency(rawValue: frequencyString),
                      let interval = payment.repetitionInterval else {
                    continue
                }
                
                let weekdays = payment.selectedWeekdays.map { Set($0) } ?? []
                let calendar = Calendar.current
                let startDate = payment.date
                let skippedDates = payment.skippedDates ?? []
                let paymentEndDate = payment.endDate
                
                // Generate occurrences and check if this transaction's date matches
                let maxEndDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                let actualEndDate = paymentEndDate ?? maxEndDate
                
                // Check if startDate matches (first occurrence)
                let startDateStart = calendar.startOfDay(for: startDate)
                let transactionDateStart = calendar.startOfDay(for: transaction.date)
                let isStartDateSkipped = skippedDates.contains { skippedDate in
                    calendar.isDate(startDateStart, inSameDayAs: skippedDate)
                }
                
                if calendar.isDate(startDateStart, inSameDayAs: transactionDateStart) && !isStartDateSkipped {
                    return payment
                }
                
                var currentDate = calculateScheduledNextDate(
                    from: startDate,
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays
                )
                
                var iterationCount = 0
                let maxIterations = 1000
                
                while currentDate <= actualEndDate && iterationCount < maxIterations {
                    iterationCount += 1
                    
                    // Check if this date is skipped
                    let isSkipped = skippedDates.contains { skippedDate in
                        calendar.isDate(currentDate, inSameDayAs: skippedDate)
                    }
                    
                    // If the transaction date matches and is not skipped, this is the source payment
                    if calendar.isDate(currentDate, inSameDayAs: transaction.date) && !isSkipped {
                        return payment
                    }
                    
                    let nextDate = calculateScheduledNextDate(
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
        }
        
        return nil
    }
    
    // RepetitionFrequency enum for scheduled calculations
    private enum RepetitionFrequency: String {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
}

// MARK: - SubscriptionRow (Matching TransactionRow Design Exactly)

struct SubscriptionRow: View {
    let subscription: PlannedPayment
    @EnvironmentObject var settings: AppSettings
    
    private var categoryIcon: String {
        if let category = subscription.category {
            // Match category icons from settings
            if let categoryObj = settings.categories.first(where: { $0.name == category }) {
                return categoryObj.iconName
            }
            // Fallback icons based on category name
            switch category.lowercased() {
            case "entertainment":
                return "tv.fill"
            case "utilities":
                return "bolt.fill"
            case "housing":
                return "house.fill"
            case "income":
                return "arrow.down.circle.fill"
            default:
                return "arrow.triangle.2.circlepath"
            }
        }
        return subscription.isIncome ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    private var categoryColor: Color {
        // Use green for income, blue/red for expenses
        return subscription.isIncome ? .green : .blue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle Icon (matching TransactionRow)
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .foregroundStyle(categoryColor)
            }
            
            // Title, Category, Date (matching TransactionRow)
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.title)
                    .font(.subheadline.weight(.semibold))
                if let category = subscription.category {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(subscription.date.formatted(.dateTime.day().month(.abbreviated))) • \(subscription.accountName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right-aligned Amount (matching TransactionRow)
            Text(currencyString(subscription.amount, code: settings.currency))
                .font(.headline)
                .foregroundStyle(categoryColor)
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

// MARK: - CustomSubscriptionFormView (Transaction-Style Form)

struct CustomSubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManager
    @EnvironmentObject var creditManager: CreditManager
    
    let paymentType: PlannedPaymentType
    let existingPayment: PlannedPayment?
    let initialIsIncome: Bool
    let occurrenceDate: Date? // The specific occurrence date being paid (if paying early)
    let onSave: (PlannedPayment) -> Void
    let onCancel: () -> Void
    let onDelete: ((PlannedPayment) -> Void)?
    let onPay: ((Date) -> Void)? // Callback for paying early
    
    @State private var title: String = ""
    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var accountName: String = "Main Card"
    @State private var selectedCategory: Category? = nil
    @State private var selectedCategoryName: String = "" // Store the full category name (may include "Parent > Child")
    @State private var isIncome: Bool = false
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var expandedCategories: Set<UUID> = [] // Track expanded categories for subcategory picker
    
    // Repetition settings
    @State private var isRepeating: Bool = false
    @State private var repetitionFrequency: RepetitionFrequency = .month
    @State private var repetitionInterval: Int = 1
    @State private var selectedWeekdays: Set<Int> = [] // 0 = Sunday, 1 = Monday, etc.
    
    @FocusState private var isAmountFocused: Bool
    
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
        let filtered = settings.categories.isEmpty ? Category.defaultCategories : settings.categories
        return filtered.filter { $0.type == (isIncome ? .income : .expense) }
    }
    
    private var accounts: [Account] {
        accountManager.accounts.isEmpty ? [Account(name: "Main Card", balance: 0, iconName: "creditcard")] : accountManager.accounts
    }
    
    private var selectedAccount: Account? {
        accounts.first(where: { $0.name == accountName }) ?? accounts.first
    }
    
    private var themeColor: Color {
        isIncome ? .green : .red
    }
    
    private var signSymbol: String {
        isIncome ? "+" : "-"
    }
    
    init(
        paymentType: PlannedPaymentType,
        existingPayment: PlannedPayment? = nil,
        initialIsIncome: Bool = false,
        occurrenceDate: Date? = nil,
        onSave: @escaping (PlannedPayment) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: ((PlannedPayment) -> Void)? = nil,
        onPay: ((Date) -> Void)? = nil
    ) {
        self.paymentType = paymentType
        self.existingPayment = existingPayment
        self.initialIsIncome = initialIsIncome
        self.occurrenceDate = occurrenceDate
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onPay = onPay
        
        if let existing = existingPayment {
            _title = State(initialValue: existing.title)
            _amount = State(initialValue: existing.amount)
            _date = State(initialValue: existing.date)
            _accountName = State(initialValue: existing.accountName)
            _isIncome = State(initialValue: existing.isIncome)
            _isRepeating = State(initialValue: existing.isRepeating)
            if let freq = existing.repetitionFrequency {
                _repetitionFrequency = State(initialValue: RepetitionFrequency(rawValue: freq) ?? .month)
            }
            _repetitionInterval = State(initialValue: existing.repetitionInterval ?? 1)
            if let weekdays = existing.selectedWeekdays {
                _selectedWeekdays = State(initialValue: Set(weekdays))
            }
        } else {
            _isIncome = State(initialValue: initialIsIncome)
        }
    }
    
    private var isValid: Bool {
        // CRITICAL FIX: Only require amount, title is optional
        amount > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Segmented Control at Top
                        typeSegmentedControl
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Pay Now Button - show if onPay callback is provided
                        // This allows paying early when editing an existing subscription
                        if let onPay = onPay {
                            // Use occurrenceDate if set (paying a specific occurrence), otherwise use the form's date
                            let paymentDate = occurrenceDate ?? date
                            
                            Button {
                                onPay(paymentDate)
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                    Text("\(String(localized: "Pay Now", comment: "Pay now button")) \(currencyString(amount, code: settings.currency))")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        // Hero Amount Input (Center)
                        heroAmountField
                            .padding(.horizontal)
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            // Note/Title Field
                            TransactionFormRow(
                                icon: "text.alignleft",
                                title: String(localized: "Name", comment: "Name field label"),
                                value: $title,
                                placeholder: isIncome ? String(localized: "Income source name", comment: "Income source placeholder") : String(localized: "Subscription name", comment: "Subscription name placeholder")
                            )
                            
                            // Category Field
                            TransactionCategoryRow(
                                icon: "tag",
                                title: String(localized: "Category", comment: "Category field label"),
                                category: selectedCategory,
                                categoryName: selectedCategoryName.isEmpty ? (selectedCategory?.name ?? "") : selectedCategoryName,
                                placeholder: String(localized: "Select Category", comment: "Category placeholder"),
                                onTap: { showCategoryPicker = true }
                            )
                            
                            // Date Field
                            TransactionDateRow(
                                icon: "calendar",
                                title: String(localized: "Next Payment Date", comment: "Next payment date label"),
                                date: $date
                            )
                            
                            // Account Field
                            TransactionAccountRow(
                                icon: "creditcard",
                                title: String(localized: "Account", comment: "Account field label"),
                                account: selectedAccount,
                                placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                                onTap: { showAccountPicker = true }
                            )
                        }
                        .padding(.horizontal)
                        
                        // Repetition Section
                        repetitionSection
                            .padding(.horizontal)
                        
                        // Save Button
                        Button {
                            // Calculate next payment date based on repetition settings
                            var nextDate = date
                            if isRepeating {
                                nextDate = calculateNextPaymentDate(
                                    from: date,
                                    frequency: repetitionFrequency,
                                    interval: repetitionInterval,
                                    weekdays: selectedWeekdays
                                )
                            }
                            
                            // CRITICAL FIX: Use default title if empty
                            let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty 
                                ? (selectedCategory?.name ?? String(localized: "Subscription", comment: "Default subscription title"))
                                : title.trimmingCharacters(in: .whitespaces)
                            
                            let payment = PlannedPayment(
                                id: existingPayment?.id ?? UUID(),
                                title: finalTitle,
                                amount: amount,
                                date: nextDate,
                                status: existingPayment?.status ?? .upcoming,
                                accountName: accountName,
                                toAccountName: existingPayment?.toAccountName,
                                category: selectedCategoryName.isEmpty ? selectedCategory?.name : selectedCategoryName,
                                type: paymentType,
                                isIncome: isIncome,
                                totalLoanAmount: existingPayment?.totalLoanAmount,
                                remainingBalance: existingPayment?.remainingBalance,
                                startDate: existingPayment?.startDate,
                                interestRate: existingPayment?.interestRate,
                                linkedCreditId: existingPayment?.linkedCreditId,
                                isRepeating: isRepeating,
                                repetitionFrequency: isRepeating ? repetitionFrequency.rawValue : nil,
                                repetitionInterval: isRepeating ? repetitionInterval : nil,
                                selectedWeekdays: (isRepeating && repetitionFrequency == .week && !selectedWeekdays.isEmpty) ? Array(selectedWeekdays) : nil,
                                skippedDates: existingPayment?.skippedDates,
                                endDate: existingPayment?.endDate
                            )
                            onSave(payment)
                        } label: {
                            Text("Save", comment: "Save button")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? themeColor : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!isValid)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(existingPayment != nil ? (isIncome ? String(localized: "Edit Income", comment: "Edit income title") : String(localized: "Edit Subscription", comment: "Edit subscription title")) : (isIncome ? String(localized: "Add Income", comment: "Add income title") : String(localized: "Add Subscription", comment: "Add subscription title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        onCancel()
                    }
                }
                
                // Delete Button in Top-Right (only when editing)
                if let existingPayment = existingPayment, let onDelete = onDelete {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onDelete(existingPayment)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet
            }
            .onAppear {
                // Initialize amount text
                if amount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(amount)
                }
                // Initialize account
                if accountName.isEmpty || !accounts.contains(where: { $0.name == accountName }) {
                    accountName = accounts.first?.name ?? "Main Card"
                }
                // Initialize category
                if let categoryName = existingPayment?.category {
                    selectedCategoryName = categoryName
                    // Check if it's a subcategory (contains " > ")
                    if categoryName.contains(" > ") {
                        let parentName = String(categoryName.split(separator: " > ").first ?? "")
                        if let category = availableCategories.first(where: { $0.name == parentName }) {
                            selectedCategory = category
                        }
                    } else {
                        // Regular category
                        if let category = availableCategories.first(where: { $0.name == categoryName }) {
                            selectedCategory = category
                        }
                    }
                }
                // Initialize repetition settings
                if let existing = existingPayment {
                    isRepeating = existing.isRepeating
                    if let freq = existing.repetitionFrequency {
                        repetitionFrequency = RepetitionFrequency(rawValue: freq) ?? .month
                    }
                    repetitionInterval = existing.repetitionInterval ?? 1
                    if let weekdays = existing.selectedWeekdays {
                        selectedWeekdays = Set(weekdays)
                    }
                }
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
            .onChange(of: amount) { oldValue, newValue in
                if newValue == 0 {
                    amountText = ""
                } else if amountText.isEmpty || abs(newValue - (Double(amountText) ?? 0)) > 0.01 {
                    amountText = formatAmount(newValue)
                }
            }
            .onChange(of: isIncome) { oldValue, newValue in
                // Clear category when switching type
                selectedCategory = nil
                selectedCategoryName = ""
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isIncome = false
                }
            } label: {
                Text(String(localized: "Expense", comment: "Expense type"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isIncome ? .primary : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isIncome ? Color.clear : Color.red)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isIncome = true
                }
            } label: {
                Text(String(localized: "Income", comment: "Income type"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isIncome ? Color.white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isIncome ? Color.green : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Hero Amount Field
    private var heroAmountField: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Amount", comment: "Amount field label"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Spacer()
                
                if !signSymbol.isEmpty {
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
        let cleaned = normalizeDecimalInput(newValue)
        
        if amount == 0 && !cleaned.isEmpty {
            if let firstChar = cleaned.first, firstChar.isNumber, firstChar != "0" {
                amountText = cleaned
                if let value = Double(cleaned) {
                    amount = value
                }
                return
            }
        }
        
        amountText = cleaned
        
        if cleaned.isEmpty {
            amount = 0
        } else if let value = Double(cleaned) {
            amount = value
        }
    }
    
    // MARK: - Format Amount
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            let formatted = String(format: "%.2f", amount)
            return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
    
    // MARK: - Normalize Decimal Input
    private func normalizeDecimalInput(_ input: String) -> String {
        // Replace comma with dot for decimal separator
        return input.replacingOccurrences(of: ",", with: ".")
    }
    
    // MARK: - Calculate Next Payment Date
    private func calculateNextPaymentDate(
        from startDate: Date,
        frequency: RepetitionFrequency,
        interval: Int,
        weekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        let startDateStart = calendar.startOfDay(for: startDate)
        var nextDate = startDate
        
        // CRITICAL FIX: Only advance if the start date is strictly BEFORE today (yesterday or earlier)
        // Do NOT advance if startDate is today - use startDate as-is
        if startDateStart < todayStart {
            switch frequency {
            case .day:
                // Add interval days
                var nextDateStart = calendar.startOfDay(for: nextDate)
                while nextDateStart < todayStart {
                    nextDate = calendar.date(byAdding: .day, value: interval, to: nextDate) ?? nextDate
                    nextDateStart = calendar.startOfDay(for: nextDate)
                }
                
            case .week:
                // Find next matching weekday
                if !weekdays.isEmpty {
                    // Find the next matching weekday
                    var found = false
                    for weekOffset in 0..<(interval * 7) {
                        let checkDate = calendar.date(byAdding: .day, value: weekOffset, to: today) ?? today
                        let checkDateStart = calendar.startOfDay(for: checkDate)
                        let checkWeekday = calendar.component(.weekday, from: checkDate)
                        let adjustedCheckWeekday = checkWeekday == 1 ? 7 : checkWeekday - 1
                        
                        if weekdays.contains(adjustedCheckWeekday) && checkDateStart >= startDateStart {
                            nextDate = checkDate
                            found = true
                            break
                        }
                    }
                    
                    if !found {
                        // If no matching weekday found in reasonable range, use interval weeks from start
                        nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                        var nextDateStart = calendar.startOfDay(for: nextDate)
                        while nextDateStart < todayStart {
                            nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: nextDate) ?? nextDate
                            nextDateStart = calendar.startOfDay(for: nextDate)
                        }
                    }
                } else {
                    // No weekdays selected, just add interval weeks
                    nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate) ?? startDate
                    var nextDateStart = calendar.startOfDay(for: nextDate)
                    while nextDateStart < todayStart {
                        nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: nextDate) ?? nextDate
                        nextDateStart = calendar.startOfDay(for: nextDate)
                    }
                }
                
            case .month:
                // Add interval months, keeping the same day of month
                var nextDateStart = calendar.startOfDay(for: nextDate)
                while nextDateStart < todayStart {
                    nextDate = calendar.date(byAdding: .month, value: interval, to: nextDate) ?? nextDate
                    nextDateStart = calendar.startOfDay(for: nextDate)
                }
                
            case .year:
                // Add interval years
                var nextDateStart = calendar.startOfDay(for: nextDate)
                while nextDateStart < todayStart {
                    nextDate = calendar.date(byAdding: .year, value: interval, to: nextDate) ?? nextDate
                    nextDateStart = calendar.startOfDay(for: nextDate)
                }
            }
        }
        
        return nextDate
    }
    
    // MARK: - Category Picker Sheet
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
                        .padding(.top, 60)
                    } else {
                        ForEach(availableCategories) { category in
                            VStack(spacing: 0) {
                                // Parent Category Row
                                Button {
                                    if !category.subcategories.isEmpty {
                                        // Toggle expansion for categories with subcategories
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if expandedCategories.contains(category.id) {
                                                expandedCategories.remove(category.id)
                                            } else {
                                                expandedCategories.insert(category.id)
                                            }
                                        }
                                    } else {
                                        // No subcategories, select the category directly
                                        selectedCategory = category
                                        selectedCategoryName = category.name
                                        showCategoryPicker = false
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(category.color.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: category.iconName)
                                                .font(.headline)
                                                .foregroundStyle(category.color)
                                        }
                                        
                                        Text(category.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        if !category.subcategories.isEmpty {
                                            // Show chevron for categories with subcategories
                                            Image(systemName: expandedCategories.contains(category.id) ? "chevron.down" : "chevron.right")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                        } else if selectedCategoryName == category.name || (selectedCategory?.id == category.id && selectedCategoryName.isEmpty) {
                                            // Show checkmark if selected (category only, no subcategory)
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.customCardBackground)
                                }
                                .buttonStyle(.plain)
                                
                                // Subcategories (shown when expanded)
                                if expandedCategories.contains(category.id) && !category.subcategories.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(category.subcategories) { subcategory in
                                            Divider()
                                                .padding(.leading, 64)
                                            
                                            Button {
                                                // Select subcategory: save combined name but use parent category for icon/color
                                                selectedCategory = category
                                                selectedCategoryName = "\(category.name) > \(subcategory.name)"
                                                showCategoryPicker = false
                                            } label: {
                                                HStack(spacing: 12) {
                                                    // Subcategory icon
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
                                                    
                                                    if selectedCategoryName == "\(category.name) > \(subcategory.name)" {
                                                        Image(systemName: "checkmark")
                                                            .foregroundStyle(.blue)
                                                    }
                                                }
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(Color.customSecondaryBackground)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Select Category", comment: "Select category sheet title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Account Picker Sheet
    private var accountPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accounts) { account in
                        accountPickerItem(account: account)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "Select Account", comment: "Select account sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        showAccountPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func accountPickerItem(account: Account) -> some View {
        Button {
            accountName = account.name
            showAccountPicker = false
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
                let isSelected = accountName == account.name
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background({
                let isSelected = accountName == account.name
                return isSelected ? Color.accentColor.opacity(0.1) : Color.customCardBackground
            }())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke({
                        let isSelected = accountName == account.name
                        return isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08)
                    }(), lineWidth: {
                        let isSelected = accountName == account.name
                        return isSelected ? 1.5 : 1
                    }())
            )
        }
        .buttonStyle(.plain)
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
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday // Usually 1 (Sunday) or 2 (Monday)
        
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
        if firstWeekday == 1 {
            // Sunday first
            return weekdays.sorted { (a: WeekdayOption, b: WeekdayOption) in
                a.value < b.value
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
}

