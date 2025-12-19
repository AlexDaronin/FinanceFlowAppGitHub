//
//  SubscriptionsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 03/12/2025.
//

import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var creditManager: CreditManager
    
    @State private var selectedType: SubscriptionType = .expense
    @State private var showAddSubscription = false
    @State private var selectedSubscription: PlannedPayment? = nil
    @State private var selectedOccurrenceDate: Date? = nil
    
    enum SubscriptionType {
        case expense
        case income
        case transfer
    }
    
    // Get subscription transactions (generated from subscriptions)
    private var subscriptionTransactions: [Transaction] {
        let subscriptionIds = Set(subscriptionManager.subscriptions.map { $0.id })
        return transactionManager.transactions
            .filter { transaction in
                if let sourceId = transaction.sourcePlannedPaymentId {
                    return subscriptionIds.contains(sourceId)
                }
                return false
            }
            .filter { transaction in
                switch selectedType {
                case .expense:
                    return transaction.type == .expense
                case .income:
                    return transaction.type == .income
                case .transfer:
                    return transaction.type == .transfer
                }
            }
            .filter { $0.date > Date() } // Only future transactions
            .sorted { $0.date < $1.date }
    }
    
    // Group subscription transactions by month
    private var groupedSubscriptions: [(month: String, items: [Transaction])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: subscriptionTransactions) { transaction in
            dateFormatter.string(from: transaction.date)
        }
        
        return grouped.map { (month: $0.key, items: $0.value) }
            .sorted { dateFormatter.date(from: $0.month) ?? Date() < dateFormatter.date(from: $1.month) ?? Date() }
    }
    
    // Calculate monthly total - only transactions within current period (based on startDay)
    // For transfers, don't sum amounts (they don't change total balance)
    private var monthlyTotal: Double {
        let period = DateRangeHelper.currentPeriod(for: settings.startDay)
        
        return subscriptionTransactions
            .filter { transaction in
                transaction.date >= period.start && transaction.date < period.end
            }
            .filter { $0.type != .transfer } // Exclude transfers from total
            .reduce(0) { $0 + $1.amount }
    }
    
    private var isEmpty: Bool {
        subscriptionTransactions.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with type selector
                    headerSection
                    
                    // Monthly summary card
                    monthlySummaryCard
                    
                    // Content area
                    subscriptionsList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                floatingActionButton
            }
            .sheet(isPresented: $showAddSubscription) {
                AddSubscriptionFormView(
                    existingPayment: nil,
                    initialIsIncome: {
                        switch selectedType {
                        case .expense:
                            return false
                        case .income:
                            return true
                        case .transfer:
                            return false // Transfer is not income
                        }
                    }(),
                    occurrenceDate: nil,
                    onSave: { payment in
                        subscriptionManager.addSubscription(payment)
                        // Balance is updated automatically by CreateTransactionUseCase when transaction is created
                        
                        showAddSubscription = false
                    },
                    onCancel: {
                        showAddSubscription = false
                    },
                    onDeleteSingle: nil,
                    onDeleteAll: { payment in
                        subscriptionManager.deleteAllOccurrences(subscriptionId: payment.id)
                        showAddSubscription = false
                    },
                    onPay: { date in
                        // Handle pay action - mark as paid
                        if let subscription = selectedSubscription {
                            let transaction = Transaction(
                                title: subscription.title,
                                category: subscription.category ?? "General",
                                amount: subscription.amount,
                                date: date,
                                type: subscription.isIncome ? .income : .expense,
                                accountId: subscription.accountId,
                                currency: settings.currency
                            )
                            transactionManager.addTransaction(transaction)
                        }
                    }
                )
                .environmentObject(settings)
                .environmentObject(accountManager)
            }
            .sheet(item: $selectedSubscription) { subscription in
                AddSubscriptionFormView(
                    existingPayment: subscription,
                    initialIsIncome: subscription.isIncome,
                    occurrenceDate: selectedOccurrenceDate,
                    onSave: { payment in
                        subscriptionManager.updateSubscription(payment)
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    },
                    onCancel: {
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    },
                    onDeleteSingle: { payment, date in
                        // Find the transaction for this specific date
                        // Try to find exact match first
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
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    },
                    onDeleteAll: { payment in
                        subscriptionManager.deleteAllOccurrences(subscriptionId: payment.id)
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    },
                    onPay: { date in
                        // Handle pay action - use subscription from closure capture
                        // Create the paid transaction as a regular transaction (not a subscription)
                        // Use current date for "Pay Now" - this moves it to expenses immediately
                        let paymentDate = Date()
                        
                        // First, find and delete the subscription transaction BEFORE creating the new one
                        // This prevents duplicates
                        let calendar = Calendar.current
                        let dateToSearch = selectedOccurrenceDate ?? date
                        let normalizedDate = calendar.startOfDay(for: dateToSearch)
                        
                        if let subscriptionTransaction = transactionManager.transactions.first(where: { txn in
                            txn.sourcePlannedPaymentId == subscription.id &&
                            calendar.isDate(calendar.startOfDay(for: txn.date), inSameDayAs: normalizedDate)
                        }) {
                            subscriptionManager.deleteSingleOccurrence(transaction: subscriptionTransaction)
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
                        
                        selectedSubscription = nil
                        selectedOccurrenceDate = nil
                    }
                )
                .environmentObject(settings)
                .environmentObject(accountManager)
            }
            .onAppear {
                // Ensure future transactions are maintained (12 months ahead)
                subscriptionManager.ensureFutureTransactions()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Subscriptions", comment: "Subscriptions view title"))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            
            // Type selector - segmented control with light gray background for selected
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedType = .expense
                    }
                } label: {
                    Text(String(localized: "Expenses", comment: "Expenses"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedType == .expense ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedType == .expense {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.gray.opacity(0.2))
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedType = .income
                    }
                } label: {
                    Text(String(localized: "Income", comment: "Income"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedType == .income ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedType == .income {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.gray.opacity(0.2))
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedType = .transfer
                    }
                } label: {
                    Text(String(localized: "Transfer", comment: "Transfer"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedType == .transfer ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedType == .transfer {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.gray.opacity(0.2))
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Monthly Summary Card
    private var monthlySummaryTitle: String {
        switch selectedType {
        case .expense:
            return String(localized: "Monthly expense", comment: "Monthly expense")
        case .income:
            return String(localized: "Monthly income", comment: "Monthly income")
        case .transfer:
            return String(localized: "Monthly transfers", comment: "Monthly transfers")
        }
    }
    
    private var monthlySummaryColor: Color {
        switch selectedType {
        case .expense:
            return Color.red
        case .income:
            return Color.green
        case .transfer:
            return Color.blue
        }
    }
    
    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthlySummaryTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(currencyString(monthlyTotal, code: settings.currency))
                .font(.title.weight(.bold))
                .foregroundStyle(monthlySummaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // MARK: - Subscriptions List
    private var subscriptionsList: some View {
        ScrollView {
            if isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No subscriptions", comment: "No subscriptions message"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Add a subscription to get started", comment: "Add subscription hint"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groupedSubscriptions, id: \.month) { group in
                        SubscriptionMonthGroup(
                            monthTitle: group.month,
                            subscriptions: group.items,
                            currency: settings.currency,
                            selectedSubscription: $selectedSubscription,
                            selectedOccurrenceDate: $selectedOccurrenceDate
                        )
                        .environmentObject(subscriptionManager)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button {
                    showAddSubscription = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.purple)
                        )
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 110)
        }
        .ignoresSafeArea()
    }
    
}

// MARK: - Subscription Month Group

struct SubscriptionMonthGroup: View {
    let monthTitle: String
    let subscriptions: [Transaction]
    let currency: String
    @Binding var selectedSubscription: PlannedPayment?
    @Binding var selectedOccurrenceDate: Date?
    
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var isExpanded = true
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
    
    private var groupedByDate: [(date: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: subscriptions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.map { (date: $0.key, items: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(formatMonthTitle(monthTitle))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(groupedByDate, id: \.date) { dateGroup in
                    // Date header
                    Text(dateFormatter.string(from: dateGroup.date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    
                    // Subscription items
                    ForEach(dateGroup.items) { transaction in
                        SubscriptionRow(transaction: transaction, currency: currency)
                            .padding(.horizontal)
                            .padding(.vertical, 3)
                            .onTapGesture {
                                if let subscriptionId = transaction.sourcePlannedPaymentId,
                                   let subscription = subscriptionManager.getSubscription(id: subscriptionId) {
                                    selectedSubscription = subscription
                                    selectedOccurrenceDate = transaction.date
                                }
                            }
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }
    
    private func formatMonthTitle(_ title: String) -> String {
        // Format "Next Month" or month name
        if title.lowercased().contains("next") {
            return String(localized: "Next Month", comment: "Next month")
        }
        return title
    }
}

// MARK: - Subscription Row

struct SubscriptionRow: View {
    let transaction: Transaction
    let currency: String
    
    @EnvironmentObject var accountManager: AccountManagerAdapter
    
    private var categoryColor: Color {
        switch transaction.type {
        case .income:
            return Color.green
        case .expense:
            return Color.red
        case .transfer:
            return Color.blue
        case .debt:
            return Color.orange
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconForCategory(transaction.category))
                    .font(.headline)
                    .foregroundStyle(categoryColor)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(transaction.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(formatDate(transaction.date)) • \(transaction.accountName(accountManager: accountManager))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(currencyString(transaction.amount, code: currency))
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
    
    private func formatDate(_ date: Date) -> String {
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "shopping":
            return "bag.fill"
        case "health":
            return "heart.fill"
        case "entertainment":
            return "tv.fill"
        default:
            return "repeat.circle.fill"
        }
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AppSettings())
        .environmentObject(TransactionManager())
        .environmentObject(AccountManager())
}
