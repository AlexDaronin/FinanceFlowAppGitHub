//
//  AddSubscriptionFormView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 03/12/2025.
//

import SwiftUI

struct AddSubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManagerAdapter
    
    let existingPayment: PlannedPayment?
    let initialIsIncome: Bool
    let occurrenceDate: Date?
    let onSave: (PlannedPayment) -> Void
    let onCancel: () -> Void
    let onDeleteSingle: ((PlannedPayment, Date) -> Void)?
    let onDeleteAll: (PlannedPayment) -> Void
    let onPay: (Date) -> Void
    
    @State private var transactionType: TransactionType
    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var subscriptionName: String = ""
    @State private var selectedCategory: String? = nil
    @State private var nextPaymentDate: Date = Date()
    @State private var selectedAccountId: UUID? = nil
    @State private var toAccountId: UUID? = nil
    @State private var isRepeating: Bool = false
    @State private var repetitionFrequency: RepetitionFrequency = .month
    @State private var repetitionInterval: Int = 1
    @State private var selectedWeekdays: Set<Int> = [] // 0 = Sunday, 1 = Monday, etc.
    
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showToAccountPicker = false
    @State private var showDeleteAlert = false
    
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNameFocused: Bool
    
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
    
    init(
        existingPayment: PlannedPayment?,
        initialIsIncome: Bool,
        occurrenceDate: Date?,
        onSave: @escaping (PlannedPayment) -> Void,
        onCancel: @escaping () -> Void,
        onDeleteSingle: ((PlannedPayment, Date) -> Void)?,
        onDeleteAll: @escaping (PlannedPayment) -> Void,
        onPay: @escaping (Date) -> Void
    ) {
        self.existingPayment = existingPayment
        self.initialIsIncome = initialIsIncome
        self.occurrenceDate = occurrenceDate
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDeleteSingle = onDeleteSingle
        self.onDeleteAll = onDeleteAll
        self.onPay = onPay
        
        // Determine transaction type from existing payment or initial value
        let initialType: TransactionType
        if let existing = existingPayment {
            if existing.toAccountId != nil {
                initialType = .transfer
            } else {
                initialType = existing.isIncome ? .income : .expense
            }
        } else {
            initialType = initialIsIncome ? .income : .expense
        }
        _transactionType = State(initialValue: initialType)
        
        _amount = State(initialValue: existingPayment?.amount ?? 0)
        _amountText = State(initialValue: {
            guard let amount = existingPayment?.amount else { return "" }
            if amount.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", amount)
            } else {
                let formatted = String(format: "%.2f", amount)
                return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        }())
        _subscriptionName = State(initialValue: existingPayment?.title ?? "")
        _selectedCategory = State(initialValue: existingPayment?.category)
        _nextPaymentDate = State(initialValue: existingPayment?.date ?? Date())
        // Use existing accountId if editing, otherwise use nil (will be set in onAppear)
        _selectedAccountId = State(initialValue: existingPayment?.accountId)
        _toAccountId = State(initialValue: existingPayment?.toAccountId)
        _isRepeating = State(initialValue: existingPayment?.isRepeating ?? false)
        
        if let frequency = existingPayment?.repetitionFrequency,
           let freq = RepetitionFrequency(rawValue: frequency) {
            _repetitionFrequency = State(initialValue: freq)
        }
        
        _repetitionInterval = State(initialValue: existingPayment?.repetitionInterval ?? 1)
        
        if let weekdays = existingPayment?.selectedWeekdays {
            _selectedWeekdays = State(initialValue: Set(weekdays))
        }
    }
    
    private var isEditMode: Bool {
        existingPayment != nil
    }
    
    // MARK: - Toolbar Buttons
    @ViewBuilder
    private var trailingToolbarButtons: some View {
        if isEditMode {
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
        .disabled(!isValid)
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
        
        // Determine title based on transaction type
        let defaultTitle: String
        switch transactionType {
        case .income:
            defaultTitle = String(localized: "Recurring Income", comment: "Recurring income default title")
        case .expense:
            defaultTitle = String(localized: "Recurring Expense", comment: "Recurring expense default title")
        case .transfer:
            defaultTitle = String(localized: "Recurring Transfer", comment: "Recurring transfer default title")
        case .debt:
            defaultTitle = String(localized: "Recurring Debt", comment: "Recurring debt default title")
        }
        
        // Preserve existing payment ID when editing, create new ID when adding
        let paymentId = existingPayment?.id ?? UUID()
        
        // Preserve other fields from existing payment if editing
        let payment = PlannedPayment(
            id: paymentId,
            title: subscriptionName.isEmpty ? defaultTitle : subscriptionName,
            amount: amount,
            date: nextPaymentDate,
            status: existingPayment?.status ?? .upcoming,
            accountId: selectedAccountId ?? accountManager.getDefaultAccountId() ?? accountManager.accounts.first?.id ?? UUID(),
            toAccountId: transactionType == .transfer ? toAccountId : nil,
            category: transactionType == .transfer ? nil : selectedCategory,
            type: existingPayment?.type ?? .subscription,
            isIncome: transactionType == .income,
            totalLoanAmount: existingPayment?.totalLoanAmount,
            remainingBalance: existingPayment?.remainingBalance,
            startDate: existingPayment?.startDate,
            interestRate: existingPayment?.interestRate,
            linkedCreditId: existingPayment?.linkedCreditId,
            isRepeating: isRepeating,
            repetitionFrequency: isRepeating ? repetitionFrequency.rawValue : nil,
            repetitionInterval: isRepeating ? repetitionInterval : nil,
            selectedWeekdays: (repetitionFrequency == .week && !selectedWeekdays.isEmpty) ? Array(selectedWeekdays) : nil,
            skippedDates: existingPayment?.skippedDates,
            endDate: existingPayment?.endDate
        )
        onSave(payment)
        dismiss()
    }
    
    // MARK: - Theme Color
    private var themeColor: Color {
        switch transactionType {
        case .income:
            return .green
        case .expense:
            return .red
        case .transfer:
            return .blue
        case .debt:
            return .orange
        }
    }
    
    // MARK: - Sign Symbol
    private var signSymbol: String {
        switch transactionType {
        case .income:
            return "+"
        case .expense:
            return "-"
        case .transfer, .debt:
            return ""
        }
    }
    
    // MARK: - Available Categories
    private var availableCategories: [Category] {
        var filtered = settings.categories.isEmpty ? Category.defaultCategories : settings.categories
        if transactionType == .income {
            filtered = filtered.filter { $0.type == .income }
        } else if transactionType == .expense {
            filtered = filtered.filter { $0.type == .expense }
        }
        // For transfers and debt, show all categories or none
        return filtered
    }
    
    /// Update all fields from existingPayment
    private func updateFieldsFromExistingPayment() {
        if let existing = existingPayment {
            amount = existing.amount
            amountText = {
                if existing.amount.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f", existing.amount)
                } else {
                    let formatted = String(format: "%.2f", existing.amount)
                    return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                }
            }()
            subscriptionName = existing.title
            selectedCategory = existing.category
            nextPaymentDate = existing.date
            selectedAccountId = existing.accountId
            toAccountId = existing.toAccountId
            isRepeating = existing.isRepeating
            
            if let frequency = existing.repetitionFrequency,
               let freq = RepetitionFrequency(rawValue: frequency) {
                repetitionFrequency = freq
            }
            
            repetitionInterval = existing.repetitionInterval ?? 1
            
            if let weekdays = existing.selectedWeekdays {
                selectedWeekdays = Set(weekdays)
            }
            
            // Update transaction type based on existing payment
            if existing.toAccountId != nil {
                transactionType = .transfer
            } else {
                transactionType = existing.isIncome ? .income : .expense
            }
        }
    }
    
    // MARK: - Selected Category
    private var selectedCategoryObj: Category? {
        guard let categoryName = selectedCategory else { return nil }
        let name: String
        if categoryName.contains(" > ") {
            name = String(categoryName.split(separator: " > ").first ?? "")
        } else {
            name = categoryName
        }
        return settings.categories.first { $0.name == name }
    }
    
    // MARK: - Selected Account
    private var selectedAccountObj: Account? {
        if let accountId = selectedAccountId {
            return accountManager.getAccount(id: accountId)
        }
        return accountManager.accounts.first
    }
    
    // MARK: - To Account (for transfers)
    private var toAccountObj: Account? {
        guard let toAccountId = toAccountId else { return nil }
        return accountManager.getAccount(id: toAccountId)
    }
    
    // MARK: - Dismiss Keyboard Helper
    private func dismissKeyboard() {
        isAmountFocused = false
        isNameFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                        
                        // Pay Now button (if editing)
                        if isEditMode {
                            Button {
                                let dateToUse = occurrenceDate ?? nextPaymentDate
                                onPay(dateToUse)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.white)
                                    Text(String(localized: "Pay Now %@", comment: "Pay now button").replacingOccurrences(of: "%@", with: currencyString(amount, code: settings.currency)))
                                        .foregroundStyle(Color.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal)
                        }
                        
                        // Hero Amount Input (Center)
                        heroAmountField
                            .padding(.horizontal)
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            // Subscription name
                            TransactionFormRow(
                                icon: "text.alignleft",
                                title: String(localized: "Note", comment: "Note field"),
                                value: $subscriptionName,
                                placeholder: String(localized: "Subscription name", comment: "Subscription name placeholder")
                            )
                            
                            // Category Field (not shown for transfers)
                            if transactionType != .transfer {
                                TransactionCategoryRow(
                                    icon: "tag",
                                    title: String(localized: "Category", comment: "Category field label"),
                                    category: selectedCategoryObj,
                                    categoryName: selectedCategory ?? "",
                                    placeholder: String(localized: "Select Category", comment: "Category placeholder"),
                                    onTap: {
                                        dismissKeyboard()
                                        showCategoryPicker = true
                                    }
                                )
                            }
                            
                            // Next Payment Date Field
                            TransactionDateRow(
                                icon: "calendar",
                                title: String(localized: "Next payment date", comment: "Next payment date field"),
                                date: $nextPaymentDate
                            )
                            
                            // Account Field
                            if transactionType == .transfer {
                                // Transfer: From and To accounts
                                TransactionAccountRow(
                                    icon: "arrow.up.circle.fill",
                                    title: String(localized: "From Account", comment: "From account label"),
                                    account: selectedAccountObj,
                                    placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                                    onTap: {
                                        dismissKeyboard()
                                        showAccountPicker = true
                                    }
                                )
                                
                                TransactionAccountRow(
                                    icon: "arrow.down.circle.fill",
                                    title: String(localized: "To Account", comment: "To account label"),
                                    account: toAccountObj,
                                    placeholder: String(localized: "Select Account", comment: "Account placeholder"),
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
                                    account: selectedAccountObj,
                                    placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                                    onTap: {
                                        dismissKeyboard()
                                        showAccountPicker = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Repetition Section
                        repetitionSection
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        dismissKeyboard()
                    }
                )
            }
            .navigationTitle(isEditMode ? String(localized: "Edit Subscription", comment: "Edit subscription title") : String(localized: "Add Subscription", comment: "Add subscription title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarButtons
                }
            }
            .alert(String(localized: "Delete Subscription", comment: "Delete subscription alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                
                // Show "Delete Only This" if onDeleteSingle is available
                if let onDeleteSingle = onDeleteSingle, let payment = existingPayment {
                    // Use occurrenceDate if available, otherwise use nextPaymentDate from the form
                    let dateToUse = occurrenceDate ?? nextPaymentDate
                    Button(String(localized: "Delete Only This", comment: "Delete only this occurrence")) {
                        onDeleteSingle(payment, dateToUse)
                        dismiss()
                    }
                }
                
                Button(String(localized: "Delete All", comment: "Delete all occurrences"), role: .destructive) {
                    if let payment = existingPayment {
                        onDeleteAll(payment)
                    }
                    dismiss()
                }
            } message: {
                if let payment = existingPayment, payment.isRepeating {
                    Text(String(localized: "Do you want to delete only this occurrence or all future occurrences of this subscription?", comment: "Delete subscription alert message"))
                } else {
                    Text(String(localized: "Are you sure you want to delete this subscription? This action cannot be undone.", comment: "Delete subscription alert message"))
                }
            }
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
            .onAppear {
                // Set default account if not set
                if selectedAccountId == nil {
                    selectedAccountId = accountManager.getDefaultAccountId() ?? accountManager.accounts.first?.id
                }
                // Update fields from existingPayment when view appears (for editing)
                if existingPayment != nil {
                    updateFieldsFromExistingPayment()
                }
                
                // Initialize amount text from amount if not already set
                if amountText.isEmpty && amount > 0 {
                    amountText = formatAmount(amount)
                }
                
                // Validate account ID - use default account if current is invalid or nil
                if let accountId = selectedAccountId, accountManager.getAccount(id: accountId) == nil {
                    selectedAccountId = accountManager.getDefaultAccountId() ?? accountManager.accounts.first?.id
                } else if selectedAccountId == nil {
                    selectedAccountId = accountManager.getDefaultAccountId() ?? accountManager.accounts.first?.id
                }
                
                // Auto-focus amount field (only for new subscriptions)
                if existingPayment == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAmountFocused = true
                    }
                }
            }
            .onChange(of: amount) { oldValue, newValue in
                if newValue == 0 {
                    amountText = ""
                } else if amountText.isEmpty || abs(newValue - (Double(amountText) ?? 0)) > 0.01 {
                    amountText = formatAmount(newValue)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Is Valid
    private var isValid: Bool {
        let hasAmount = amount > 0
        let hasName = !subscriptionName.isEmpty
        let hasAccount = selectedAccountId != nil
        
        if transactionType == .transfer {
            let hasToAccount = toAccountId != nil && toAccountId != selectedAccountId
            return hasAmount && hasName && hasAccount && hasToAccount
        } else {
            return hasAmount && hasName && hasAccount
        }
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        Picker("Transaction Type", selection: $transactionType) {
            Text(String(localized: "Expense", comment: "Expense")).tag(TransactionType.expense)
            Text(String(localized: "Income", comment: "Income")).tag(TransactionType.income)
            Text(String(localized: "Transfer", comment: "Transfer")).tag(TransactionType.transfer)
        }
        .pickerStyle(.segmented)
        .onChange(of: transactionType) { oldValue, newValue in
            if newValue != .transfer {
                toAccountId = nil
            } else if oldValue != .transfer {
                // When switching to transfer, set a default toAccount if available
                if toAccountId == nil && accountManager.accounts.count > 1 {
                    if let fromAccount = selectedAccountObj,
                       let toAccount = accountManager.accounts.first(where: { $0.id != fromAccount.id }) {
                        toAccountId = toAccount.id
                    }
                }
            }
        }
    }
    
    // MARK: - Hero Amount Field
    private var heroAmountField: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Amount", comment: "Amount label"))
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
        var cleaned = newValue.replacingOccurrences(of: ",", with: ".")
        cleaned = cleaned.filter { $0.isNumber || $0 == "." }
        let components = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        if components.count > 2 {
            let firstPart = String(components[0])
            let rest = components.dropFirst().joined(separator: "")
            cleaned = firstPart + "." + rest
        }
        
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
                                .foregroundStyle(themeColor)
                            Spacer()
                            Text("\(repetitionInterval) \(repetitionFrequency.localizedUnit)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(themeColor)
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
        
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        if firstWeekday == 1 {
            return weekdays.sorted { (a: WeekdayOption, b: WeekdayOption) in
                let aValue = a.value == 0 ? 7 : a.value
                let bValue = b.value == 0 ? 7 : b.value
                return aValue < bValue
            }
        } else {
            return weekdays.sorted { (a: WeekdayOption, b: WeekdayOption) in
                let aValue = a.value == 0 ? 7 : a.value
                let bValue = b.value == 0 ? 7 : b.value
                return aValue < bValue
            }
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
                            Text(String(localized: "No categories available", comment: "No categories message"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .padding(.top, 100)
                    } else {
                        ForEach(availableCategories) { category in
                            VStack(spacing: 0) {
                                Button {
                                    if !category.subcategories.isEmpty {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if expandedCategories.contains(category.id) {
                                                expandedCategories.remove(category.id)
                                            } else {
                                                expandedCategories.insert(category.id)
                                            }
                                        }
                                    } else {
                                        selectedCategory = category.name
                                        showCategoryPicker = false
                                    }
                                } label: {
                                    HStack(spacing: 14) {
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
                                                Text("\(category.subcategories.count) \(category.subcategories.count == 1 ? String(localized: "subcategory", comment: "Subcategory singular") : String(localized: "subcategories", comment: "Subcategories plural"))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if !category.subcategories.isEmpty {
                                            Image(systemName: expandedCategories.contains(category.id) ? "chevron.down" : "chevron.right")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        } else if selectedCategory == category.name || (selectedCategory?.hasPrefix("\(category.name) >") ?? false) {
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
                                
                                if expandedCategories.contains(category.id) && !category.subcategories.isEmpty {
                                    VStack(spacing: 6) {
                                        ForEach(category.subcategories) { subcategory in
                                            Button {
                                                selectedCategory = "\(category.name) > \(subcategory.name)"
                                                showCategoryPicker = false
                                            } label: {
                                                HStack(spacing: 12) {
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
                                                    
                                                    if selectedCategory == "\(category.name) > \(subcategory.name)" {
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
            .navigationTitle(String(localized: "Select Category", comment: "Select category title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        showCategoryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .environmentObject(settings)
    }
    
    // MARK: - Account Picker Sheet
    private func accountPickerSheet(isFromAccount: Bool) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accountManager.accounts) { account in
                        accountPickerItem(account: account, isFromAccount: isFromAccount)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(isFromAccount ? String(localized: "Select Account", comment: "Select account title") : String(localized: "Select To Account", comment: "Select to account title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
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
    
    private func accountPickerItem(account: Account, isFromAccount: Bool) -> some View {
        Button {
            if isFromAccount {
                selectedAccountId = account.id
                showAccountPicker = false
            } else {
                toAccountId = account.id
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
                    Text(currencyString(account.balance, code: account.currency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let isSelected = isFromAccount ? (selectedAccountId == account.id) : (toAccountId == account.id)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background({
                let isSelected = isFromAccount ? (selectedAccountId == account.id) : (toAccountId == account.id)
                return isSelected ? Color.accentColor.opacity(0.1) : Color.customCardBackground
            }())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke({
                        let isSelected = isFromAccount ? (selectedAccountId == account.id) : (toAccountId == account.id)
                        return isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08)
                    }(), lineWidth: {
                        let isSelected = isFromAccount ? (selectedAccountId == account.id) : (toAccountId == account.id)
                        return isSelected ? 1.5 : 1
                    }())
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddSubscriptionFormView(
        existingPayment: nil,
        initialIsIncome: false,
        occurrenceDate: nil,
        onSave: { _ in },
        onCancel: { },
        onDeleteSingle: nil,
        onDeleteAll: { _ in },
        onPay: { _ in }
    )
    .environmentObject(AppSettings())
    .environmentObject(AccountManager())
}
