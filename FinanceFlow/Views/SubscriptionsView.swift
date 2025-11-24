//
//  SubscriptionsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

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
    @StateObject private var manager = SubscriptionManager.shared
    @EnvironmentObject var settings: AppSettings
    @State private var showAddSheet = false
    @State private var selectedSubscription: PlannedPayment?
    @State private var selectedMode: SubscriptionMode = .expenses
    @State private var selectedDate: Date? = nil
    
    // Filtered subscriptions based on selected mode and date
    private var filteredSubscriptions: [PlannedPayment] {
        let calendar = Calendar.current
        var filtered = manager.subscriptions(isIncome: selectedMode == .income)
        
        // If a date is selected, filter by that specific date
        if let selectedDate = selectedDate {
            let selectedDay = calendar.startOfDay(for: selectedDate)
            filtered = filtered.filter { subscription in
                let subDay = calendar.startOfDay(for: subscription.date)
                return subDay == selectedDay
            }
        }
        
        return filtered
    }
    
    // Group subscriptions by date (matching TransactionsView style)
    private var groupedSubscriptions: [(date: Date, subscriptions: [PlannedPayment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSubscriptions) { subscription in
            calendar.startOfDay(for: subscription.date)
        }
        return grouped
            .map { (date: $0.key, subscriptions: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
    
    // Helper function to format date for empty state
    private func formatDateForEmptyState(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
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
    
    var body: some View {
        ZStack {
            // Bottom Layer: Background
            Color.customBackground.ignoresSafeArea()
            
            // Middle Layer: Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Segmented Control (Expenses/Income)
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(SubscriptionMode.allCases, id: \.self) { mode in
                            Text(mode.localizedTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Premium Expandable Calendar Card
                    ExpandableCalendarView(
                        subscriptions: manager.subscriptions,
                        selectedDate: $selectedDate
                    )
                    .padding(.horizontal)
                    
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
                    if filteredSubscriptions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: selectedDate == nil ? "tray" : "calendar.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.5))
                            
                            if let date = selectedDate {
                                VStack(spacing: 4) {
                                    Text("No plans for", comment: "No plans for date")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    Text(formatDateForEmptyState(date))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                Text(selectedMode == .expenses ? String(localized: "No active expenses", comment: "No active expenses") : String(localized: "No active income", comment: "No active income"))
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(Array(groupedSubscriptions.enumerated()), id: \.element.date) { index, dayGroup in
                            VStack(alignment: .leading, spacing: 12) {
                                // Day Header (matching TransactionsView)
                                dayHeader(for: dayGroup.date)
                                    .padding(.horizontal, 20)
                                    .padding(.top, index == 0 ? 8 : 16)
                                    .padding(.bottom, 8)
                                
                                // Subscriptions for this day (using exact TransactionRow design)
                                ForEach(dayGroup.subscriptions) { subscription in
                                    Button {
                                        selectedSubscription = subscription
                                    } label: {
                                        SubscriptionRow(subscription: subscription)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            manager.deleteSubscription(subscription)
                                        } label: {
                                            Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
                                        }
                                    }
                                    .id(subscription.id)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100) // Space for FAB button
            }
            
            // Top Layer: Floating Action Button (pinned to bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 6)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle(Text("Subscriptions", comment: "Subscriptions view title"))
        .sheet(isPresented: $showAddSheet) {
            CustomSubscriptionFormView(
                paymentType: .subscription,
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
        }
        .sheet(item: $selectedSubscription) { subscription in
            CustomSubscriptionFormView(
                paymentType: .subscription,
                existingPayment: subscription,
                onSave: { updatedSubscription in
                    manager.updateSubscription(updatedSubscription)
                    selectedSubscription = nil
                },
                onCancel: {
                    selectedSubscription = nil
                }
            )
            .environmentObject(settings)
        }
    }
}

// MARK: - ExpandableCalendarView

struct ExpandableCalendarView: View {
    let subscriptions: [PlannedPayment]
    @Binding var selectedDate: Date?
    @State private var isExpanded: Bool = false
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    
    // Get subscriptions for a specific date
    private func subscriptions(for date: Date) -> [PlannedPayment] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return subscriptions.filter { subscription in
            let subDate = calendar.startOfDay(for: subscription.date)
            return subDate >= dayStart && subDate < dayEnd
        }
    }
    
    // Check if date has income
    private func hasIncome(for date: Date) -> Bool {
        subscriptions(for: date).contains { $0.isIncome }
    }
    
    // Check if date has expense
    private func hasExpense(for date: Date) -> Bool {
        subscriptions(for: date).contains { !$0.isIncome }
    }
    
    // Get current week dates
    private var currentWeekDates: [Date] {
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    // Get all dates in current month
    private var monthDates: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysToSubtract = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var dates: [Date?] = []
        
        // Add padding days (days from previous month)
        for i in 0..<daysToSubtract {
            if let date = calendar.date(byAdding: .day, value: -daysToSubtract + i, to: firstDay) {
                dates.append(date)
            } else {
                dates.append(nil)
            }
        }
        
        // Add days of current month
        var currentDate = firstDay
        while currentDate < monthInterval.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Fill remaining days to complete grid (6 rows x 7 days = 42)
        while dates.count < 42 {
            dates.append(nil)
        }
        
        return dates
    }
    
    var body: some View {
        // Premium Widget Container - wraps all calendar content
        VStack(spacing: 0) {
            // Header with month/year and chevron toggle button
            HStack {
                if isExpanded {
                    // Month/Year display
                    Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Previous/Next month buttons
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                } else {
                    // Week view header
                    Text("This Week", comment: "This week header")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                
                // Chevron Toggle Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.customCardBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            
            if isExpanded {
                // Full Month Grid
                VStack(spacing: 16) {
                    // Weekday headers
                    HStack(spacing: 0) {
                        ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                            Text(day)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Calendar grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                        ForEach(Array(monthDates.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                CalendarDayCell(
                                    date: date,
                                    dayNumber: calendar.component(.day, from: date),
                                    hasIncome: hasIncome(for: date),
                                    hasExpense: hasExpense(for: date),
                                    isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!),
                                    isToday: calendar.isDateInToday(date),
                                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                                ) {
                                    // Toggle selection: tap selected date to deselect
                                    if let currentSelected = selectedDate, calendar.isDate(date, inSameDayAs: currentSelected) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedDate = nil
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedDate = date
                                        }
                                        // Update current month if selecting a date from a different month
                                        let selectedMonth = calendar.dateComponents([.year, .month], from: date)
                                        let currentMonthComponents = calendar.dateComponents([.year, .month], from: currentMonth)
                                        if selectedMonth != currentMonthComponents {
                                            withAnimation {
                                                currentMonth = calendar.date(from: selectedMonth) ?? currentMonth
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Empty cell
                                Color.clear
                                    .frame(height: 56)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Single Week Row
                VStack(spacing: 8) {
                    // Weekday headers
                    HStack(spacing: 0) {
                        ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                            Text(day)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Week dates
                    HStack(spacing: 14) {
                        ForEach(currentWeekDates, id: \.self) { date in
                            CalendarDayCell(
                                date: date,
                                dayNumber: calendar.component(.day, from: date),
                                hasIncome: hasIncome(for: date),
                                hasExpense: hasExpense(for: date),
                                isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!),
                                isToday: calendar.isDateInToday(date),
                                isCurrentMonth: true
                            ) {
                                // Toggle selection: tap selected date to deselect
                                if let currentSelected = selectedDate, calendar.isDate(date, inSameDayAs: currentSelected) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedDate = nil
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedDate = date
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - CalendarDayCell

struct CalendarDayCell: View {
    let date: Date
    let dayNumber: Int
    let hasIncome: Bool
    let hasExpense: Bool
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Day number with cleaner font
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected ? .semibold : (isToday ? .medium : .regular)))
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary.opacity(0.4)
                    )
                
                // Indicator dots (neatly positioned below number)
                HStack(spacing: 4) {
                    if hasIncome {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }
                    if hasExpense {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isSelected {
                        // Soft, rounded selection highlight (squircle for iOS feel)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 40)
                    } else if isToday {
                        // Subtle today indicator
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 40, height: 40)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
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
                Text("\(shortDate(subscription.date)) • \(subscription.accountName)")
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

// MARK: - Custom Subscription Form View

struct CustomSubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    
    let paymentType: PlannedPaymentType
    let existingPayment: PlannedPayment?
    let initialIsIncome: Bool
    let onSave: (PlannedPayment) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var amount: Double = 0
    @State private var date: Date = Date()
    @State private var accountName: String = "Main Card"
    @State private var selectedCategory: String? = nil
    @State private var isIncome: Bool = false
    
    @FocusState private var isAmountFocused: Bool
    
    private let categories: [(name: String, icon: String, color: Color)] = [
        ("Entertainment", "tv.fill", .purple),
        ("Utilities", "bolt.fill", .yellow),
        ("Housing", "house.fill", .blue),
        ("General", "arrow.triangle.2.circlepath", .gray),
        ("Debt", "creditcard.fill", .red),
        ("Health", "heart.fill", .pink),
        ("Shopping", "bag.fill", .orange),
        ("Transport", "car.fill", .cyan),
        ("Income", "arrow.down.circle.fill", .green)
    ]
    
    private let accounts = ["Main Card", "Savings", "Credit Card"]
    
    init(
        paymentType: PlannedPaymentType,
        existingPayment: PlannedPayment? = nil,
        initialIsIncome: Bool = false,
        onSave: @escaping (PlannedPayment) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.paymentType = paymentType
        self.existingPayment = existingPayment
        self.initialIsIncome = initialIsIncome
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let existing = existingPayment {
            _title = State(initialValue: existing.title)
            _amount = State(initialValue: existing.amount)
            _date = State(initialValue: existing.date)
            _accountName = State(initialValue: existing.accountName)
            _selectedCategory = State(initialValue: existing.category)
            _isIncome = State(initialValue: existing.isIncome)
        } else {
            _isIncome = State(initialValue: initialIsIncome)
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Type Toggle (Income/Expense)
                        VStack(spacing: 12) {
                            Text("Type", comment: "Type field label")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker("Type", selection: $isIncome) {
                                Text("Expense", comment: "Expense type").tag(false)
                                Text("Income", comment: "Income type").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Large Amount Input (Top Center)
                        VStack(spacing: 8) {
                            Text("Amount", comment: "Amount field label")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("0", value: $amount, format: .number)
                                .font(.system(size: 48, weight: .bold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($isAmountFocused)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                                .background(Color.customCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .padding(.horizontal)
                        
                        // Category Selection (Horizontal Scrollable Grid)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category", comment: "Category field label")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(categories, id: \.name) { category in
                                        CategoryChip(
                                            name: category.name,
                                            icon: category.icon,
                                            color: category.color,
                                            isSelected: selectedCategory == category.name || (selectedCategory == nil && category.name == "General")
                                        ) {
                                            selectedCategory = category.name == "General" ? nil : category.name
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            // Name Field
                            CustomFormRow(
                                icon: "text.alignleft",
                                title: String(localized: "Name", comment: "Name field label"),
                                value: $title,
                                placeholder: isIncome ? String(localized: "Income source name", comment: "Income source placeholder") : String(localized: "Subscription name", comment: "Subscription name placeholder")
                            )
                            
                            // Date Field
                            DatePickerRow(
                                icon: "calendar",
                                title: String(localized: "Next Payment Date", comment: "Next payment date label"),
                                date: $date
                            )
                            
                            // Account Field
                            AccountPickerRow(
                                icon: "creditcard",
                                title: String(localized: "Account", comment: "Account field label"),
                                selectedAccount: $accountName,
                                accounts: accounts
                            )
                        }
                        .padding(.horizontal)
                        
                        // Save Button
                        Button {
                            let payment = PlannedPayment(
                                id: existingPayment?.id ?? UUID(),
                                title: title.trimmingCharacters(in: .whitespaces),
                                amount: amount,
                                date: date,
                                status: existingPayment?.status ?? .upcoming,
                                accountName: accountName,
                                category: selectedCategory,
                                type: paymentType,
                                isIncome: isIncome
                            )
                            onSave(payment)
                        } label: {
                            Text("Save", comment: "Save button")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? (isIncome ? Color.green : Color.blue) : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!isValid)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Delete Button (only when editing)
                        if existingPayment != nil {
                            Button {
                                // Delete action would be handled by parent
                                onCancel()
                            } label: {
                                Text("Delete Subscription", comment: "Delete subscription button")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
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
            }
            .onAppear {
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
        }
    }
}

// MARK: - Form Components

struct CategoryChip: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.2) : color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomFormRow: View {
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

struct DatePickerRow: View {
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

struct AccountPickerRow: View {
    let icon: String
    let title: String
    @Binding var selectedAccount: String
    let accounts: [String]
    
    @State private var showPicker = false
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(selectedAccount)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                
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
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                List {
                    ForEach(accounts, id: \.self) { account in
                        Button {
                            selectedAccount = account
                            showPicker = false
                        } label: {
                            HStack {
                                Text(account)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedAccount == account {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(Text("Select Account", comment: "Select account sheet title"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }
}
