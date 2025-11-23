//
//  DashboardView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var debtManager: DebtManager
    @State private var accounts = Account.sample
    @State private var selectedAccountId: UUID = Account.sample.first?.id ?? UUID()
    @State private var plannedPayments = PlannedPayment.sample
    @State private var transactions = Transaction.sample
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty
    @State private var showAccountForm = false
    @State private var editingAccount: Account?
    @State private var otherAccountsExpanded = false
    @State private var showAllAccounts = false
    @State private var savingsExpanded = false
    @State private var showNonPinnedAccounts = false
    @State private var showNonPinnedSavings = false
    
    private let timelinePoints = TimelinePoint.sample
    private let creditSummary = CreditSummary.sample
    
    private var selectedAccount: Account? {
        accounts.first { $0.id == selectedAccountId }
    }
    
    private var totalIncludedBalance: Double {
        accounts
            .filter { $0.includedInTotal }
            .map(\.balance)
            .reduce(0, +)
    }
    
    private var quickStats: QuickStats {
        let income = transactions
            .filter { $0.type == .income }
            .map(\.amount)
            .reduce(0, +)
        let spent = transactions
            .filter { $0.type == .expense }
            .map(\.amount)
            .reduce(0, +)
        return QuickStats(totalIncome: income, totalSpent: spent)
    }
    
    private var remainingBudget: Double {
        max(quickStats.totalIncome - quickStats.totalSpent, 0)
    }
    
    private var periodStart: Date {
        let calendar = Calendar.current
        let today = Date()
        let todayDay = calendar.component(.day, from: today)
        let base = todayDay < settings.startDay
            ? calendar.date(byAdding: .month, value: -1, to: today) ?? today
            : today
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = settings.startDay
        return calendar.date(from: components) ?? today
    }
    
    private var periodEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
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
        plannedPayments.filter { $0.status == .upcoming }.count
    }
    
    private var upcomingPlannedAmount: Double {
        plannedPayments
            .filter { $0.status == .upcoming }
            .map(\.amount)
            .reduce(0, +)
    }
    
    private var totalSavings: Double {
        accounts
            .filter { $0.isSavings }
            .map(\.balance)
            .reduce(0, +)
    }
    
    // Calculate total debts from DebtManager (money I owe to people)
    // This uses the same calculation logic as DebtsView for consistency
    private var totalDebts: Double {
        debtManager.getTotalToPay()
    }
    
    private var categories: [String] {
        Array(Set(transactions.map(\.category))).sorted()
    }
    
    private let actionOptions: [ActionMenuOption] = ActionMenuOption.transactions
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryCard
                        quickStatsSection
                        
                        // Accounts and Savings grouped together with reduced spacing
                        VStack(alignment: .leading, spacing: 12) {
                            accountsSection
                            
                            // Savings section (if there are savings accounts)
                            if totalSavings > 0 {
                                savingsSection
                            }
                        }
                        
                        // Visual separator before financial overview
                        Divider()
                            .padding(.vertical, 8)
                        
                        financialOverviewSection
                        NavigationLink {
                            PlansView(transactions: transactions, plannedPayments: plannedPayments, accounts: accounts)
                                .environmentObject(settings)
                        } label: {
                            plannedVsActualPreview
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 120)
                }
            .background(Color.customBackground)
            .navigationTitle("FinanceFlow")
                
                floatingActionButton
            }
            .sheet(isPresented: $showTransactionForm) {
                TransactionFormView(
                    draft: $draftTransaction,
                    mode: currentFormMode,
                    categories: categories,
                    accounts: accounts,
                    onSave: { draft in
                        handleSave(draft)
                    },
                    onCancel: {
                        showTransactionForm = false
                    }
                )
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Balance")
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
                title: "Income",
                value: currencyString(quickStats.totalIncome, code: settings.currency),
                color: .green
            )
            quickStatTile(
                title: "Spent",
                value: currencyString(quickStats.totalSpent, code: settings.currency),
                color: .red
            )
            quickStatTile(
                title: "Remaining",
                value: currencyString(remainingBudget, code: settings.currency),
                color: .blue
            )
        }
    }
    
    private func quickStatTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var financialOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Debts (tappable) - shows total amount I owe to people
            NavigationLink(destination: DebtsView().environmentObject(settings).environmentObject(debtManager)) {
                financialOverviewRow(
                    title: "Debts",
                    amount: totalDebts,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    showNegative: totalDebts > 0
                )
            }
            .buttonStyle(.plain)
            
            // Subscriptions (tappable)
            NavigationLink(destination: SubscriptionsView().environmentObject(settings)) {
                financialOverviewRow(
                    title: "Planned",
                    amount: upcomingPlannedAmount,
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    subtitle: "\(activePlannedCount) active"
                )
            }
            .buttonStyle(.plain)
            
            // Credits (tappable)
            NavigationLink(destination: CreditsLoansView().environmentObject(settings)) {
                financialOverviewRow(
                    title: "Credits",
                    amount: creditSummary.remaining,
                    icon: "creditcard.fill",
                    color: .red,
                    subtitle: "Due \(shortDate(creditSummary.nextDue))",
                    showNegative: true
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var savingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Savings")
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
            
            VStack(spacing: 8) {
                // Show savings accounts
                let savingsAccounts = accounts.filter { $0.isSavings }
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
                        NavigationLink(destination: AccountDetailsView(account: account, accounts: $accounts, transactions: transactions)) {
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
                                NavigationLink(destination: AccountDetailsView(account: account, accounts: $accounts, transactions: transactions)) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
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
            
            VStack(spacing: 8) {
                // Filter out savings accounts - only show regular accounts
                let regularAccounts = accounts.filter { !$0.isSavings }
                let pinnedAccounts = regularAccounts.filter { $0.isPinned }
                let nonPinnedAccounts = regularAccounts.filter { !$0.isPinned }
                
                if regularAccounts.isEmpty {
                    Text("No accounts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    // Show pinned accounts
                    ForEach(pinnedAccounts) { account in
                        NavigationLink(destination: AccountDetailsView(account: account, accounts: $accounts, transactions: transactions)) {
                            AccountRow(
                                account: account,
                                isSelected: account.id == selectedAccountId,
                                includedBinding: binding(for: account)
                            )
                        }
                        .buttonStyle(.plain)
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
                                NavigationLink(destination: AccountDetailsView(account: account, accounts: $accounts, transactions: transactions)) {
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
        .sheet(isPresented: $showAccountForm) {
            AccountFormView(
                account: editingAccount,
                onSave: { account in
                    if let editingAccount = editingAccount {
                        if let index = accounts.firstIndex(where: { $0.id == editingAccount.id }) {
                            accounts[index] = account
                        }
                    } else {
                        accounts.append(account)
                    }
                    showAccountForm = false
                    editingAccount = nil
                },
                onCancel: {
                    showAccountForm = false
                    editingAccount = nil
                }
            )
        }
    }
    
    private var plannedVsActualPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plans")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(periodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Chart {
                ForEach(filteredTimelinePoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Planned", point.planned)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                }
                
                ForEach(filteredTimelinePoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Actual", point.actual)
                    )
                    .foregroundStyle(Color.white)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    private var floatingActionButton: some View {
        ZStack {
            if showActionMenu {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showActionMenu = false
                        }
                    }
            }
            
        VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        if showActionMenu {
                            ForEach(actionOptions) { option in
                                Button {
                                    startAddingTransaction(for: option.type)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(option.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                        Image(systemName: option.icon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .frame(width: 52, height: 52)
                                            .background(
                                                LinearGradient(
                                                    colors: [option.tint.opacity(0.9), option.tint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .scaleEffect(showActionMenu ? 1 : 0.7, anchor: .trailing)
                            }
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showActionMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showActionMenu ? "xmark" : "plus")
                                .font(.title2.weight(.bold))
                                .rotationEffect(.degrees(showActionMenu ? 45 : 0))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func startAddingTransaction(for type: TransactionType) {
        currentFormMode = .add(type)
        draftTransaction = TransactionDraft(type: type)
        showTransactionForm = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showActionMenu = false
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactions.insert(newTransaction, at: 0)
        case .edit(let id):
            let updated = draft.toTransaction(existingId: id)
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions[index] = updated
            }
        }
        showTransactionForm = false
    }
    
    private func binding(for account: Account) -> Binding<Bool> {
        Binding {
            accounts.first { $0.id == account.id }?.includedInTotal ?? true
        } set: { newValue in
            guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
            accounts[index].includedInTotal = newValue
        }
    }
}

struct AccountRow: View {
    @EnvironmentObject var settings: AppSettings
    let account: Account
    let isSelected: Bool
    let includedBinding: Binding<Bool>
    
    var body: some View {
        HStack(spacing: 12) {
            // Account type icon
            ZStack {
                Circle()
                    .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: account.iconName)
                    .font(.headline)
                    .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
            }
            
            // Account info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Included toggle
            Toggle("", isOn: includedBinding)
                .labelsHidden()
                .tint(.accentColor)
                .scaleEffect(0.85)
        }
        .padding(16)
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
