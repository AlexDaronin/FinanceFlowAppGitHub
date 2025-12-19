//
//  StatisticsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts

// MARK: - Data Structures

struct CategoryExpenseData: Identifiable {
    let id: UUID
    let categoryName: String
    let iconName: String
    let color: Color
    let amount: Double
    let percentage: Double
    
    init(id: UUID = UUID(), categoryName: String, iconName: String, color: Color, amount: Double, percentage: Double) {
        self.id = id
        self.categoryName = categoryName
        self.iconName = iconName
        self.color = color
        self.amount = amount
        self.percentage = percentage
    }
}

struct ExpensesSummary {
    let totalAmount: Double
    let categoryData: [CategoryExpenseData]
}

// Monthly trend data point
struct MonthlyTrendData: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expense: Double
    let net: Double
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: month)
    }
}

// Weekly spending data point
struct WeeklySpendingData: Identifiable {
    let id = UUID()
    let weekday: String
    let weekdayIndex: Int
    let amount: Double
}

// Top category data for horizontal bar chart
struct TopCategoryData: Identifiable {
    let id = UUID()
    let categoryName: String
    let iconName: String
    let color: Color
    let amount: Double
    let percentage: Double
}

// Account balance data
struct AccountBalanceData: Identifiable {
    let id: UUID
    let accountName: String
    let balance: Double
    let color: Color
    let iconName: String
    
    init(accountName: String, balance: Double, color: Color, iconName: String) {
        self.id = UUID()
        self.accountName = accountName
        self.balance = balance
        self.color = color
        self.iconName = iconName
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @State private var showExpensesSheet = false
    @State private var showIncomeExpenseSheet = false
    @State private var showMonthlyExpensesSheet = false
    @State private var showTopCategoriesSheet = false
    @State private var showWeeklySpendingSheet = false
    @State private var showAccountsSheet = false
    @State private var selectedTimeRange: TimeRange = .last6Months
    
    enum TimeRange: String, CaseIterable {
        case last3Months = "Last 3 Months"
        case last6Months = "Last 6 Months"
        case last12Months = "Last 12 Months"
        case allTime = "All Time"
        
        var localizedTitle: String {
            switch self {
            case .last3Months:
                return String(localized: "Last 3 Months", comment: "Last 3 months time range")
            case .last6Months:
                return String(localized: "Last 6 Months", comment: "Last 6 months time range")
            case .last12Months:
                return String(localized: "Last 12 Months", comment: "Last 12 months time range")
            case .allTime:
                return String(localized: "All Time", comment: "All time range")
            }
        }
    }
    
    private var expensesSummary: ExpensesSummary {
        calculateExpensesSummary(
            transactions: transactionManager.transactions,
            categories: settings.categories
        )
    }
    
    private var monthlyTrendData: [MonthlyTrendData] {
        calculateMonthlyTrends(
            transactions: transactionManager.transactions,
            timeRange: selectedTimeRange
        )
    }
    
    private var weeklySpendingData: [WeeklySpendingData] {
        calculateWeeklySpending(
            transactions: transactionManager.transactions
        )
    }
    
    private var topCategoriesData: [TopCategoryData] {
        calculateTopCategories(
            transactions: transactionManager.transactions,
            categories: settings.categories,
            limit: 5
        )
    }
    
    private var accountBalanceData: [AccountBalanceData] {
        accountManager.accounts
            .filter { $0.includedInTotal }
            .map { account in
                AccountBalanceData(
                    accountName: account.name,
                    balance: account.balance,
                    color: Color.blue.opacity(0.7),
                    iconName: account.iconName
                )
            }
            .sorted { $0.balance > $1.balance }
    }
    
    private var totalBalance: Double {
        accountBalanceData.reduce(0) { $0 + $1.balance }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    timeRangePicker
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Summary Cards Row
                    summaryCardsRow
                        .padding(.horizontal)
                    
                    // Expenses Breakdown Card
                    ExpensesBreakdownCard(
                        totalAmount: expensesSummary.totalAmount,
                        categoryData: expensesSummary.categoryData,
                        currency: settings.currency,
                        onTap: {
                            showExpensesSheet = true
                        }
                    )
                    .padding(.horizontal)
                    
                    // Income vs Expenses Trend Chart
                    incomeExpenseTrendChart
                        .padding(.horizontal)
                    
                    // Monthly Expenses Bar Chart
                    monthlyExpensesChart
                        .padding(.horizontal)
                    
                    // Accounts Balance Chart
                    accountsBalanceChart
                        .padding(.horizontal)
                    
                    // Top Categories Horizontal Bar Chart
                    topCategoriesChart
                        .padding(.horizontal)
                    
                    // Weekly Spending Chart
                    weeklySpendingChart
                        .padding(.horizontal)
                }
                .padding(.bottom, 120)
            }
            .background(Color.customBackground)
            .navigationTitle(Text("Statistics", comment: "Statistics view title"))
            .sheet(isPresented: $showExpensesSheet) {
                ExpensesBreakdownSheet(
                    totalAmount: expensesSummary.totalAmount,
                    categoryData: expensesSummary.categoryData,
                    currency: settings.currency
                )
            }
            .sheet(isPresented: $showIncomeExpenseSheet) {
                IncomeExpenseDetailSheet(
                    data: monthlyTrendData,
                    currency: settings.currency
                )
            }
            .sheet(isPresented: $showMonthlyExpensesSheet) {
                MonthlyExpensesDetailSheet(
                    data: monthlyTrendData,
                    currency: settings.currency
                )
            }
            .sheet(isPresented: $showTopCategoriesSheet) {
                TopCategoriesDetailSheet(
                    data: topCategoriesData,
                    currency: settings.currency
                )
            }
            .sheet(isPresented: $showWeeklySpendingSheet) {
                WeeklySpendingDetailSheet(
                    data: weeklySpendingData,
                    currency: settings.currency
                )
            }
            .sheet(isPresented: $showAccountsSheet) {
                AccountsBalanceDetailSheet(
                    accountsData: accountBalanceData,
                    totalBalance: totalBalance,
                    currency: settings.currency
                )
            }
        }
    }
    
    // MARK: - Summary Cards Row
    
    private var summaryCardsRow: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: String(localized: "Income", comment: "Income label"),
                amount: monthlyTrendData.reduce(0) { $0 + $1.income },
                currency: settings.currency,
                color: ChartStyle.incomeColor,
                icon: "arrow.down.circle.fill"
            )
            
            SummaryCard(
                title: String(localized: "Expenses", comment: "Expenses label"),
                amount: monthlyTrendData.reduce(0) { $0 + $1.expense },
                currency: settings.currency,
                color: ChartStyle.expenseColor,
                icon: "arrow.up.circle.fill"
            )
            
            SummaryCard(
                title: String(localized: "Net", comment: "Net label"),
                amount: monthlyTrendData.reduce(0) { $0 + $1.net },
                currency: settings.currency,
                color: ChartStyle.netColor,
                icon: "equal.circle.fill"
            )
        }
    }
    
    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        Picker(String(localized: "Time Range", comment: "Time range picker"), selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.localizedTitle).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Income vs Expenses Trend Chart
    private var incomeExpenseTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Income vs Expenses", comment: "Income vs expenses chart title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if monthlyTrendData.isEmpty {
                ChartEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "No data available",
                    height: ChartStyle.compactHeight
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Chart(monthlyTrendData) { data in
                    LineMark(
                        x: .value("Month", data.month, unit: .month),
                        y: .value("Income", data.income)
                    )
                    .foregroundStyle(ChartStyle.incomeColor)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))
                    .symbolSize(40)
                    
                    LineMark(
                        x: .value("Month", data.month, unit: .month),
                        y: .value("Expenses", data.expense)
                    )
                    .foregroundStyle(ChartStyle.expenseColor)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))
                    .symbolSize(40)
                }
                .frame(height: ChartStyle.compactHeight)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartDate(date, format: "MMM"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let amount = value.as(Double.self), amount > 0 {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartAmount(amount))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clickableChartContainer {
            showIncomeExpenseSheet = true
        }
    }
    
    // MARK: - Monthly Expenses Bar Chart
    private var monthlyExpensesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Expenses", comment: "Monthly expenses chart title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if monthlyTrendData.isEmpty {
                ChartEmptyState(
                    icon: "chart.bar",
                    message: "No data available",
                    height: ChartStyle.compactHeight
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Chart(monthlyTrendData) { data in
                    BarMark(
                        x: .value("Month", data.month, unit: .month),
                        y: .value("Expenses", data.expense)
                    )
                    .foregroundStyle(ChartStyle.expenseColor.gradient)
                    .cornerRadius(3)
                }
                .frame(height: ChartStyle.compactHeight)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartDate(date, format: "MMM"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let amount = value.as(Double.self), amount > 0 {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartAmount(amount))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clickableChartContainer {
            showMonthlyExpensesSheet = true
        }
    }
    
    // MARK: - Accounts Balance Chart
    private var accountsBalanceChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Accounts Balance", comment: "Accounts balance chart title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(currencyString(totalBalance, code: settings.currency))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if accountBalanceData.isEmpty {
                ChartEmptyState(
                    icon: "creditcard",
                    message: "No accounts available",
                    height: ChartStyle.compactHeight
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Chart(accountBalanceData) { data in
                    BarMark(
                        x: .value("Account", data.accountName),
                        y: .value("Balance", data.balance)
                    )
                    .foregroundStyle(data.color.gradient)
                    .cornerRadius(3)
                }
                .frame(height: ChartStyle.compactHeight)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let account = value.as(String.self) {
                                Text(account)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let amount = value.as(Double.self), amount != 0 {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartAmount(amount))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clickableChartContainer {
            showAccountsSheet = true
        }
    }
    
    // MARK: - Top Categories Chart
    private var topCategoriesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Categories", comment: "Top categories chart title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if topCategoriesData.isEmpty {
                ChartEmptyState(
                    icon: "chart.bar.horizontal",
                    message: "No data available",
                    height: ChartStyle.compactHeight
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Chart(topCategoriesData) { data in
                    BarMark(
                        x: .value("Amount", data.amount),
                        y: .value("Category", data.categoryName)
                    )
                    .foregroundStyle(data.color.opacity(0.8).gradient)
                    .cornerRadius(3)
                }
                .frame(height: CGFloat(min(topCategoriesData.count * 40 + 20, 200)))
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let amount = value.as(Double.self), amount > 0 {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartAmount(amount))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let category = value.as(String.self) {
                                Text(category)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartXScale(domain: .automatic(includesZero: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clickableChartContainer {
            showTopCategoriesSheet = true
        }
    }
    
    // MARK: - Weekly Spending Chart
    private var weeklySpendingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spending by Day", comment: "Weekly spending chart title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if weeklySpendingData.isEmpty {
                ChartEmptyState(
                    icon: "calendar",
                    message: "No data available",
                    height: ChartStyle.compactHeight
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                Chart(weeklySpendingData.sorted { $0.weekdayIndex < $1.weekdayIndex }) { data in
                    BarMark(
                        x: .value("Day", data.weekday),
                        y: .value("Amount", data.amount)
                    )
                    .foregroundStyle(ChartStyle.primaryChartColor.opacity(0.7).gradient)
                    .cornerRadius(3)
                }
                .frame(height: ChartStyle.compactHeight)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let day = value.as(String.self) {
                            AxisValueLabel {
                                Text(day)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                        if let amount = value.as(Double.self), amount > 0 {
                            AxisValueLabel {
                                Text(ChartFormatters.formatChartAmount(amount))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clickableChartContainer {
            showWeeklySpendingSheet = true
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Double
    let currency: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(currencyString(amount, code: currency))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

// MARK: - Helper Functions

private func calculateExpensesSummary(
    transactions: [Transaction],
    categories: [Category]
) -> ExpensesSummary {
    // Filter for expense transactions only
    let expenseTransactions = transactions.filter { $0.type == .expense }
    
    // Group by category and calculate totals
    var categoryTotals: [String: Double] = [:]
    
    for transaction in expenseTransactions {
        let categoryName = transaction.category
        categoryTotals[categoryName, default: 0] += transaction.amount
    }
    
    // Calculate total
    let totalAmount = categoryTotals.values.reduce(0, +)
    
    // Create category data with icon and color
    var categoryData: [CategoryExpenseData] = []
    
    for (categoryName, amount) in categoryTotals {
        // Find matching category to get icon and color
        let category = categories.first { $0.name == categoryName }
        let iconName = category?.iconName ?? "tag.fill"
        let color = category?.color ?? .blue
        
        let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
        
        categoryData.append(
            CategoryExpenseData(
                categoryName: categoryName,
                iconName: iconName,
                color: color,
                amount: amount,
                percentage: percentage
            )
        )
    }
    
    // Sort by amount in descending order
    categoryData.sort { $0.amount > $1.amount }
    
    return ExpensesSummary(
        totalAmount: totalAmount,
        categoryData: categoryData
    )
}

private func calculateMonthlyTrends(
    transactions: [Transaction],
    timeRange: StatisticsView.TimeRange
) -> [MonthlyTrendData] {
    let calendar = Calendar.current
    let now = Date()
    
    // Calculate start date based on time range
    let startDate: Date
    switch timeRange {
    case .last3Months:
        startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
    case .last6Months:
        startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
    case .last12Months:
        startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
    case .allTime:
        startDate = transactions.map(\.date).min() ?? now
    }
    
    // Filter transactions within range
    let filteredTransactions = transactions.filter { $0.date >= startDate && $0.date <= now }
    
    // Group by month
    var monthlyData: [Date: (income: Double, expense: Double)] = [:]
    
    for transaction in filteredTransactions {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.date)) ?? transaction.date
        
        if monthlyData[monthStart] == nil {
            monthlyData[monthStart] = (income: 0, expense: 0)
        }
        
        switch transaction.type {
        case .income:
            monthlyData[monthStart]?.income += transaction.amount
        case .expense:
            monthlyData[monthStart]?.expense += transaction.amount
        default:
            break
        }
    }
    
    // Convert to array and sort
    return monthlyData.map { month, amounts in
        MonthlyTrendData(
            month: month,
            income: amounts.income,
            expense: amounts.expense,
            net: amounts.income - amounts.expense
        )
    }
    .sorted { $0.month < $1.month }
}

private func calculateWeeklySpending(
    transactions: [Transaction]
) -> [WeeklySpendingData] {
    let calendar = Calendar.current
    let expenseTransactions = transactions.filter { $0.type == .expense }
    
    // Group by weekday
    var weekdayTotals: [Int: Double] = [:]
    
    for transaction in expenseTransactions {
        let weekday = calendar.component(.weekday, from: transaction.date)
        // Convert to Monday = 0, Sunday = 6
        let weekdayIndex = (weekday + 5) % 7
        weekdayTotals[weekdayIndex, default: 0] += transaction.amount
    }
    
    let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    return weekdayTotals.map { index, amount in
        WeeklySpendingData(
            weekday: weekdayNames[index],
            weekdayIndex: index,
            amount: amount
        )
    }
}

private func calculateTopCategories(
    transactions: [Transaction],
    categories: [Category],
    limit: Int
) -> [TopCategoryData] {
    let expenseTransactions = transactions.filter { $0.type == .expense }
    
    // Group by category
    var categoryTotals: [String: Double] = [:]
    
    for transaction in expenseTransactions {
        categoryTotals[transaction.category, default: 0] += transaction.amount
    }
    
    // Calculate total for percentage
    let total = categoryTotals.values.reduce(0, +)
    
    // Create data array
    var topCategories: [TopCategoryData] = []
    
    for (categoryName, amount) in categoryTotals {
        let category = categories.first { $0.name == categoryName }
        let iconName = category?.iconName ?? "tag.fill"
        let color = category?.color ?? .blue
        let percentage = total > 0 ? (amount / total) * 100 : 0
        
        topCategories.append(
            TopCategoryData(
                categoryName: categoryName,
                iconName: iconName,
                color: color,
                amount: amount,
                percentage: percentage
            )
        )
    }
    
    // Sort by amount and take top N
    topCategories.sort { $0.amount > $1.amount }
    return Array(topCategories.prefix(limit))
}

// MARK: - Collapsed Card View

struct ExpensesBreakdownCard: View {
    let totalAmount: Double
    let categoryData: [CategoryExpenseData]
    let currency: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left side: Text information
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expenses", comment: "Expenses label")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(currencyString(totalAmount, code: currency))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Right side: Miniature donut chart
                Chart(categoryData.prefix(5)) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.65),
                        angularInset: 1
                    )
                    .foregroundStyle(item.color.opacity(0.8))
                }
                .frame(width: 70, height: 70)
                .chartBackground { chartProxy in
                    // Empty background for mini chart
                }
            }
            .padding(18)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: Color.primary.opacity(0.03), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded Sheet Views

struct ExpensesBreakdownSheet: View {
    let totalAmount: Double
    let categoryData: [CategoryExpenseData]
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Grabber indicator
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Title
                    Text("Expenses Breakdown", comment: "Expenses breakdown sheet title")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Large donut chart
                    Chart(categoryData) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color.opacity(0.8))
                    }
                    .frame(height: 280)
                    .chartBackground { chartProxy in
                        VStack(spacing: 4) {
                            Text("Total", comment: "Total label")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currencyString(totalAmount, code: currency))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Category list
                    VStack(spacing: 12) {
                        ForEach(categoryData) { item in
                            CategoryExpenseRow(
                                categoryName: item.categoryName,
                                iconName: item.iconName,
                                color: item.color,
                                percentage: item.percentage,
                                amount: item.amount,
                                currency: currency
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct IncomeExpenseDetailSheet: View {
    let data: [MonthlyTrendData]
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    Text("Income vs Expenses", comment: "Income vs expenses detail title")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Chart(data) { item in
                        LineMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Income", item.income)
                        )
                        .foregroundStyle(ChartStyle.incomeColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(50)
                        
                        LineMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Expenses", item.expense)
                        )
                        .foregroundStyle(ChartStyle.expenseColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(50)
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(ChartFormatters.formatChartDate(date, format: "MMM yyyy"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let amount = value.as(Double.self), amount > 0 {
                                AxisValueLabel {
                                    Text(currencyString(amount, code: currency))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(data) { item in
                            HStack {
                                Text(item.monthYear)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(ChartStyle.incomeColor)
                                            .frame(width: 8, height: 8)
                                        Text(currencyString(item.income, code: currency))
                                            .font(.subheadline)
                                    }
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(ChartStyle.expenseColor)
                                            .frame(width: 8, height: 8)
                                        Text(currencyString(item.expense, code: currency))
                                            .font(.subheadline)
                                    }
                                    HStack(spacing: 8) {
                                        Text("Net:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(currencyString(item.net, code: currency))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(item.net >= 0 ? ChartStyle.incomeColor : ChartStyle.expenseColor)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.customCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MonthlyExpensesDetailSheet: View {
    let data: [MonthlyTrendData]
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    Text("Monthly Expenses", comment: "Monthly expenses detail title")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Chart(data) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Expenses", item.expense)
                        )
                        .foregroundStyle(ChartStyle.expenseColor.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(ChartFormatters.formatChartDate(date, format: "MMM yyyy"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let amount = value.as(Double.self), amount > 0 {
                                AxisValueLabel {
                                    Text(currencyString(amount, code: currency))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(data) { item in
                            HStack {
                                Text(item.monthYear)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(currencyString(item.expense, code: currency))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding()
                            .background(Color.customCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct TopCategoriesDetailSheet: View {
    let data: [TopCategoryData]
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    Text("Top Categories", comment: "Top categories detail title")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Chart(data) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.categoryName)
                        )
                        .foregroundStyle(item.color.opacity(0.8).gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: CGFloat(data.count * 50 + 40))
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let amount = value.as(Double.self), amount > 0 {
                                AxisValueLabel {
                                    Text(currencyString(amount, code: currency))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(data) { item in
                            CategoryExpenseRow(
                                categoryName: item.categoryName,
                                iconName: item.iconName,
                                color: item.color,
                                percentage: item.percentage,
                                amount: item.amount,
                                currency: currency
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct WeeklySpendingDetailSheet: View {
    let data: [WeeklySpendingData]
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    Text("Spending by Day", comment: "Weekly spending detail title")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Chart(data.sorted { $0.weekdayIndex < $1.weekdayIndex }) { item in
                        BarMark(
                            x: .value("Day", item.weekday),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(ChartStyle.primaryChartColor.opacity(0.7).gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let day = value.as(String.self) {
                                AxisValueLabel {
                                    Text(day)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let amount = value.as(Double.self), amount > 0 {
                                AxisValueLabel {
                                    Text(currencyString(amount, code: currency))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(data.sorted { $0.weekdayIndex < $1.weekdayIndex }) { item in
                            HStack {
                                Text(item.weekday)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(currencyString(item.amount, code: currency))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding()
                            .background(Color.customCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct AccountsBalanceDetailSheet: View {
    let accountsData: [AccountBalanceData]
    let totalBalance: Double
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accounts Balance", comment: "Accounts balance detail title")
                            .font(.title2.bold())
                        Text("Total: \(currencyString(totalBalance, code: currency))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Chart(accountsData) { accountItem in
                        BarMark(
                            x: .value("Account", accountItem.accountName),
                            y: .value("Balance", accountItem.balance)
                        )
                        .foregroundStyle(accountItem.color.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let account = value.as(String.self) {
                                    Text(account)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                            if let amount = value.as(Double.self), amount != 0 {
                                AxisValueLabel {
                                    Text(currencyString(amount, code: currency))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(accountsData, id: \.id) { accountData in
                            AccountBalanceRow(
                                accountName: accountData.accountName,
                                balance: accountData.balance,
                                color: accountData.color,
                                iconName: accountData.iconName,
                                currency: currency
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Account Balance Row

struct AccountBalanceRow: View {
    let accountName: String
    let balance: Double
    let color: Color
    let iconName: String
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(accountName)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(currencyString(balance, code: currency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
        }
        .padding()
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Category Row

struct CategoryExpenseRow: View {
    let categoryName: String
    let iconName: String
    let color: Color
    let percentage: Double
    let amount: Double
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon in colored circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            
            // Category name
            Text(categoryName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Percentage and amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currencyString(amount, code: currency))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}
