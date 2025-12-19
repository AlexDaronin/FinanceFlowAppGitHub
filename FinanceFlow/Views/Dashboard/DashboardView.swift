//
//  DashboardView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var debtManager: DebtManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedAccountId: UUID = UUID()
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    @State private var showAccountForm = false
    @State private var editingAccount: Account?
    @State private var otherAccountsExpanded = false
    @State private var showAllAccounts = false
    @State private var savingsExpanded = false
    @State private var showNonPinnedAccounts = false
    @State private var showNonPinnedSavings = false
    @State private var draggingAccountId: UUID?
    
    private let timelinePoints = TimelinePoint.sample
    @EnvironmentObject var creditManager: CreditManager
    
    private var selectedAccount: Account? {
        accountManager.accounts.first { $0.id == selectedAccountId }
    }
    
    private var totalIncludedBalance: Double {
        accountManager.accounts
            .filter { $0.includedInTotal && $0.accountType != .credit }
            .map(\.balance)
            .reduce(0, +)
    }
    
    // Кэшируемые состояния для оптимизации производительности
    @State private var cachedQuickStats: QuickStats = QuickStats(totalIncome: 0, totalSpent: 0)
    @State private var cachedCategories: [String] = []
    @State private var cachedUpcomingPlannedAmount: Double = 0
    @State private var lastStatsTransactionCount: Int = 0
    @State private var lastStatsPeriodStart: Date = Date()
    
    private var quickStats: QuickStats {
        cachedQuickStats
    }
    
    private var remainingBudget: Double {
        max(quickStats.totalIncome - quickStats.totalSpent, 0)
    }
    
    private var periodStart: Date {
        DateRangeHelper.periodStart(for: settings.startDay)
    }
    
    private var periodEnd: Date {
        DateRangeHelper.periodEnd(for: settings.startDay)
    }
    
    private var filteredTimelinePoints: [TimelinePoint] {
        timelinePoints
            .filter { $0.date >= periodStart && $0.date < periodEnd }
            .sorted { $0.date < $1.date }
    }
    
    private var highlightedTransfers: [TimelinePoint] {
        filteredTimelinePoints.filter { $0.note != nil }
    }
    
    private var periodDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDisplay = Calendar.current.date(byAdding: .day, value: -1, to: periodEnd) ?? periodEnd
        return "\(formatter.string(from: periodStart)) – \(formatter.string(from: endDisplay))"
    }
    
    private var activePlannedCount: Int {
        0
    }
    
    private var upcomingPlannedAmount: Double {
        cachedUpcomingPlannedAmount
    }
    
    private var totalSavings: Double {
        accountManager.accounts
            .filter { $0.isSavings }
            .map(\.balance)
            .reduce(0, +)
    }
    
    private var hasSavingsAccounts: Bool {
        accountManager.accounts.contains { $0.isSavings }
    }
    
    // Calculate total debts from DebtManager (money I owe to people)
    // This uses the same calculation logic as DebtsView for consistency
    private var totalDebts: Double {
        debtManager.getTotalToPay()
    }
    
    private var categories: [String] {
        cachedCategories
    }
    
    // Функция для обновления кэша DashboardView
    private func updateDashboardCache() {
        let today = Date()
        let period = DateRangeHelper.currentPeriod(for: settings.startDay)
        let transactions = transactionManager.transactions
        
        // Обновляем только если изменились транзакции или период
        let periodChanged = lastStatsPeriodStart != period.start
        let transactionsChanged = lastStatsTransactionCount != transactions.count
        
        guard periodChanged || transactionsChanged else { return }
        
        // Вычисляем quickStats один раз
        let income = transactions
            .filter { transaction in
                transaction.type == .income &&
                transaction.date >= period.start &&
                transaction.date < period.end &&
                transaction.date <= today
            }
            .map(\.amount)
            .reduce(0, +)
        
        let spent = transactions
            .filter { transaction in
                transaction.type == .expense &&
                transaction.date >= period.start &&
                transaction.date < period.end &&
                transaction.date <= today
            }
            .map(\.amount)
            .reduce(0, +)
        
        cachedQuickStats = QuickStats(totalIncome: income, totalSpent: spent)
        
        // Категории
        cachedCategories = Array(Set(transactions.map(\.category))).sorted()
        
        // Upcoming planned amount
        let subscriptionIds = Set(subscriptionManager.subscriptions.map { $0.id })
        cachedUpcomingPlannedAmount = transactions
            .filter { transaction in
                if let sourceId = transaction.sourcePlannedPaymentId {
                    return subscriptionIds.contains(sourceId)
                }
                return false
            }
            .filter { transaction in
                transaction.date >= period.start && transaction.date < period.end && transaction.type == .expense
            }
            .map { $0.amount }
            .reduce(0, +)
        
        lastStatsTransactionCount = transactions.count
        lastStatsPeriodStart = period.start
    }
    
    private let actionOptions: [ActionMenuOption] = ActionMenuOption.transactions
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                            // Top anchor for scroll reset
                            Color.clear
                                .frame(height: 0)
                                .id("top")
                            
                        summaryCard
                        quickStatsSection
                        
                        // Accounts and Savings grouped together with reduced spacing
                        VStack(alignment: .leading, spacing: 12) {
                            accountsSection
                            
                            // Savings section (if there are savings accounts)
                            if hasSavingsAccounts {
                                savingsSection
                            }
                        }
                        
                        // Visual separator before financial overview
                        Divider()
                            .padding(.vertical, 8)
                        
                        financialOverviewSection
                        // Spending Projection Chart
                        SpendingProjectionChart(transactions: transactionManager.transactions)
                            .environmentObject(settings)
                            .environmentObject(debtManager)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 120)
                    }
                    .onAppear {
                        // Reset scroll position when view appears
                        proxy.scrollTo("top", anchor: .top)
                        // Инициализируем кэш при первом появлении
                        updateDashboardCache()
                    }
                    .onChange(of: transactionManager.transactions) { oldValue, newValue in
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
                            updateDashboardCache()
                        }
                    }
                    .onChange(of: settings.startDay) { oldValue, newValue in
                        updateDashboardCache()
                    }
                }
            .background(Color.customBackground)
            .navigationTitle(Text("Dashboard"))
                
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
                    },
                    onDelete: { id in
                        if let transaction = transactionManager.transactions.first(where: { $0.id == id }) {
                            deleteTransaction(transaction)
                        }
                        showTransactionForm = false
                    }
                )
                .environmentObject(settings)
                .environmentObject(debtManager)
                .id(currentFormMode) // Force recreation when mode changes
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Balance", comment: "Dashboard total balance label")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currencyString(totalIncludedBalance, code: settings.currency))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            if let selectedAccount {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 4, height: 4)
                    Text("\(selectedAccount.name) • \(currencyString(selectedAccount.balance, code: settings.currency))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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
    
    private var quickStatsSection: some View {
        HStack(spacing: 8) {
            quickStatTile(
                title: String(localized: "Income", comment: "Income stat label"),
                value: currencyString(quickStats.totalIncome, code: settings.currency),
                color: .green
            )
            quickStatTile(
                title: String(localized: "Spent", comment: "Spent stat label"),
                value: currencyString(quickStats.totalSpent, code: settings.currency),
                color: .red
            )
            quickStatTile(
                title: String(localized: "Remaining", comment: "Remaining budget label"),
                value: currencyString(remainingBudget, code: settings.currency),
                color: .blue
            )
        }
    }
    
    private func quickStatTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    private var financialOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Debts (tappable) - shows total amount I owe to people
            NavigationLink(destination: DebtsView().environmentObject(settings).environmentObject(debtManager)) {
                financialOverviewRow(
                    title: String(localized: "Debts", comment: "Debts section title"),
                    amount: totalDebts,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    showNegative: totalDebts > 0
                )
            }
            .buttonStyle(.plain)
            
            // Subscriptions (tappable)
            NavigationLink(destination: SubscriptionsView()
                .environmentObject(settings)
                .environmentObject(transactionManager)
                .environmentObject(accountManager)
                .environmentObject(subscriptionManager)) {
                financialOverviewRow(
                    title: String(localized: "Subscriptions", comment: "Subscriptions section title"),
                    amount: upcomingPlannedAmount,
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    showNegative: false
                )
            }
            .buttonStyle(.plain)
            
            // Credits (tappable)
            NavigationLink(destination: CreditsView()
                .environmentObject(settings)
                .environmentObject(creditManager)
                .environmentObject(accountManager)
                .environmentObject(transactionManager)) {
                financialOverviewRow(
                    title: String(localized: "Credits", comment: "Credits section title"),
                    amount: creditManager.totalRemaining,
                    icon: "creditcard.fill",
                    color: .red,
                    subtitle: creditManager.nextDueDate.map { "\(String(localized: "Due", comment: "Due date prefix")) \(shortDate($0))" },
                    showNegative: true
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var savingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Savings", comment: "Savings section title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    editingAccount = nil
                    showAccountForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 6) {
                // Show savings accounts
                let savingsAccounts = accountManager.accounts.filter { $0.isSavings && $0.accountType != .credit }
                let pinnedSavings = savingsAccounts.filter { $0.isPinned }
                let nonPinnedSavings = savingsAccounts.filter { !$0.isPinned }
                
                if savingsAccounts.isEmpty {
                    Text("No savings accounts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    // Show pinned savings accounts
                    ForEach(pinnedSavings) { account in
                        NavigationLink(destination: AccountDetailsView(account: account)
                            .environmentObject(settings)
                            .environmentObject(transactionManager)
                            .environmentObject(accountManager)) {
                            AccountRow(
                                account: account,
                                isSelected: account.id == selectedAccountId,
                                includedBinding: binding(for: account)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Show expand/collapse button for non-pinned savings (always visible, fixed position)
                    if !nonPinnedSavings.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showNonPinnedSavings.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showNonPinnedSavings ? "Show less" : "Show more savings")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                                Image(systemName: showNonPinnedSavings ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.primary.opacity(0.7))
                                    .rotationEffect(.degrees(showNonPinnedSavings ? 180 : 0))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Show non-pinned savings accounts if expanded (animated content below button)
                        if showNonPinnedSavings {
                            ForEach(nonPinnedSavings) { account in
                                NavigationLink(destination: AccountDetailsView(account: account)
                                    .environmentObject(settings)
                                    .environmentObject(transactionManager)
                                    .environmentObject(accountManager)) {
                                    AccountRow(
                                        account: account,
                                        isSelected: account.id == selectedAccountId,
                                        includedBinding: binding(for: account)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }
    
    private func financialOverviewRow(
        title: String,
        amount: Double,
        icon: String,
        color: Color,
        subtitle: String? = nil,
        showNegative: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            
            // Title
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Amount and subtitle
            VStack(alignment: .trailing, spacing: 2) {
                Text(showNegative ? "-\(currencyString(amount, code: settings.currency))" : currencyString(amount, code: settings.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(showNegative ? .red : .primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
    }
    
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Accounts", comment: "Accounts section title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    editingAccount = nil
                    showAccountForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 6) {
                // Filter out savings accounts - only show regular accounts
                let regularAccounts = accountManager.accounts.filter { !$0.isSavings && $0.accountType != .credit }
                let pinnedAccounts = regularAccounts.filter { $0.isPinned }
                let nonPinnedAccounts = regularAccounts.filter { !$0.isPinned }
                
                if regularAccounts.isEmpty {
                    Text(String(localized: "No accounts", comment: "No accounts message"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    // Show pinned accounts
                    ForEach(pinnedAccounts) { account in
                        NavigationLink(destination: AccountDetailsView(account: account)
                            .environmentObject(settings)
                            .environmentObject(transactionManager)
                            .environmentObject(accountManager)) {
                            AccountRow(
                                account: account,
                                isSelected: account.id == selectedAccountId,
                                includedBinding: binding(for: account)
                            )
                        }
                        .buttonStyle(.plain)
                        .onDrag {
                            draggingAccountId = account.id
                            return NSItemProvider(object: account.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], isTargeted: nil) { _, _ in
                            guard let sourceId = draggingAccountId else { return false }
                            reorderAccount(sourceId: sourceId, targetId: account.id)
                            return true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteAccount(account.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Show expand/collapse button for non-pinned accounts (always visible, fixed position)
                    if !nonPinnedAccounts.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showNonPinnedAccounts.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showNonPinnedAccounts ? "Show less" : "Show more accounts")
                                    .font(.caption)
                                    .foregroundStyle(.primary.opacity(0.7))
                                Image(systemName: showNonPinnedAccounts ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.primary.opacity(0.7))
                                    .rotationEffect(.degrees(showNonPinnedAccounts ? 180 : 0))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Show non-pinned accounts if expanded (animated content below button)
                        if showNonPinnedAccounts {
                            ForEach(nonPinnedAccounts) { account in
                                NavigationLink(destination: AccountDetailsView(account: account)
                                    .environmentObject(settings)
                                    .environmentObject(transactionManager)
                                    .environmentObject(accountManager)) {
                                    AccountRow(
                                        account: account,
                                        isSelected: account.id == selectedAccountId,
                                        includedBinding: binding(for: account)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrag {
                                    draggingAccountId = account.id
                                    return NSItemProvider(object: account.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], isTargeted: nil) { _, _ in
                                    guard let sourceId = draggingAccountId else { return false }
                                    reorderAccount(sourceId: sourceId, targetId: account.id)
                                    return true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteAccount(account.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAccountForm) {
            AccountFormView(
                account: editingAccount,
                onSave: { account in
                    if editingAccount != nil {
                        // Update account with transaction manager to sync transaction names
                        accountManager.updateAccount(account, transactionManager: transactionManager)
                    } else {
                        accountManager.addAccount(account)
                    }
                    showAccountForm = false
                    editingAccount = nil
                },
                onCancel: {
                    showAccountForm = false
                    editingAccount = nil
                },
                onDelete: { accountId in
                    deleteAccount(accountId)
                    showAccountForm = false
                    editingAccount = nil
                }
            )
                }
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
    
    private func startAddingTransaction(for type: TransactionType) {
        currentFormMode = .add(type)
        let firstAccountId = accountManager.accounts.first?.id ?? UUID()
        draftTransaction = TransactionDraft(type: type, currency: settings.currency, accountId: firstAccountId)
        showTransactionForm = true
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        let oldTransaction: Transaction?
        
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactionManager.addTransaction(newTransaction)
            oldTransaction = nil
        case .edit(let id):
            oldTransaction = transactionManager.transactions.first(where: { $0.id == id })
            let updated = draft.toTransaction(existingId: id)
            transactionManager.updateTransaction(updated)
        }
        
        // Balance is updated automatically by UpdateTransactionUseCase or CreateTransactionUseCase
        
        showTransactionForm = false
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        transactionManager.deleteTransaction(transaction)
        // Balance is reverted automatically by DeleteTransactionUseCase
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func reorderAccount(sourceId: UUID, targetId: UUID) {
        guard let sourceIndex = accountManager.accounts.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = accountManager.accounts.firstIndex(where: { $0.id == targetId }) else { return }
        
        let sourcePinned = accountManager.accounts[sourceIndex].isPinned
        let targetPinned = accountManager.accounts[targetIndex].isPinned
        
        // Respect pinned/non-pinned separation
        guard sourcePinned == targetPinned else { return }
        
        accountManager.reorder(from: sourceIndex, to: targetIndex)
    }
    
    private func deleteAccount(_ accountId: UUID) {
        guard let account = accountManager.getAccount(id: accountId) else { return }
        
        // Delete all transactions associated with this account
        transactionManager.transactions.removeAll { transaction in
            transaction.accountId == account.id || transaction.toAccountId == account.id
        }
        
        // Delete the account
        accountManager.deleteAccount(accountId)
        
        // Reset selected account if it was deleted
        if selectedAccountId == accountId {
            selectedAccountId = accountManager.accounts.first?.id ?? UUID()
        }
    }
    
    private func binding(for account: Account) -> Binding<Bool> {
        Binding {
            accountManager.accounts.first { $0.id == account.id }?.includedInTotal ?? true
        } set: { newValue in
            guard var updatedAccount = accountManager.getAccount(id: account.id) else { return }
            updatedAccount.includedInTotal = newValue
            accountManager.updateAccount(updatedAccount)
        }
    }
}

struct AccountRow: View {
    @EnvironmentObject var settings: AppSettings
    let account: Account
    let isSelected: Bool
    let includedBinding: Binding<Bool>
    
    var body: some View {
        HStack(spacing: 8) {
            // Account type icon
            ZStack {
                Circle()
                    .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: account.iconName)
                    .font(.subheadline)
                    .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
            }
            
            // Account info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(account.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    if account.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if account.isSavings {
                        Image(systemName: "banknote")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(currencyString(account.balance, code: settings.currency))
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Included toggle
            Toggle("", isOn: includedBinding)
                .labelsHidden()
                .tint(.accentColor)
                .scaleEffect(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.customCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}
