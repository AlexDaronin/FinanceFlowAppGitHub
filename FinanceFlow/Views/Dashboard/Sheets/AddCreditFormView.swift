//
//  AddCreditFormView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct AddCreditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    let existingCredit: Credit?
    let onSave: (Credit) -> Void
    let onCancel: () -> Void
    let onDelete: ((Credit) -> Void)?
    
    @State private var showDeleteAlert = false
    
    @State private var title: String = ""
    @State private var totalAmount: Double = 0
    @State private var monthlyPayment: Double = 0
    @State private var interestRate: String = ""
    @State private var startDate: Date = Date()
    @State private var dueDate: Date = Date()
    @State private var termMonths: String = ""
    @State private var selectedAccountId: UUID? = nil
    @State private var trackInPlannedPayments: Bool = true // Default to true
    
    @State private var showAccountPicker = false
    
    @FocusState private var isAmountFocused: Bool
    @State private var amountText: String = ""
    
    // Get accounts from accountManager, excluding credit accounts
    // Only show regular accounts (not savings, not credits)
    // This ensures we only show accounts that exist in accountManager
    private var accounts: [Account] {
        accountManager.accounts.filter { account in
            // Only show regular accounts (not savings, not credits)
            // All accounts should be in "accounts", "savings" or "credits"
            // For credit form, we only want regular accounts (not savings, not credits)
            !account.isSavings && account.accountType != .credit
        }
    }
    
    private var selectedAccount: Account? {
        // First, try to find account by ID
        if let accountId = selectedAccountId,
           let account = accountManager.getAccount(id: accountId) {
            // Verify account is still valid (not credit, not savings)
            if account.accountType != .credit && !account.isSavings {
                return account
            }
        }
        // If selected account doesn't exist or is invalid, return first available account
        return accounts.first
    }
    
    init(
        existingCredit: Credit? = nil,
        onSave: @escaping (Credit) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: ((Credit) -> Void)? = nil
    ) {
        self.existingCredit = existingCredit
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        if let existing = existingCredit {
            _title = State(initialValue: existing.title)
            _totalAmount = State(initialValue: existing.totalAmount)
            _monthlyPayment = State(initialValue: existing.monthlyPayment)
            _startDate = State(initialValue: existing.startDate ?? existing.dueDate)
            _dueDate = State(initialValue: existing.dueDate)
            _selectedAccountId = State(initialValue: existing.paymentAccountId)
        }
    }
    
    private var isValid: Bool {
        // Title is optional (like in transactions), only amount and monthly payment are required
        totalAmount > 0 &&
        monthlyPayment > 0
    }
    
    // MARK: - Toolbar Buttons
    @ViewBuilder
    private var trailingToolbarButtons: some View {
        if existingCredit != nil && onDelete != nil {
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
            Label(String(localized: "Delete", comment: "Delete button"), systemImage: "trash")
        }
    }
    
    // MARK: - Handle Save
    private func handleSave() {
        // Calculate remaining and paid amounts
        // When editing, preserve the paid amount; when creating, paid is 0
        let paid = existingCredit?.paid ?? 0
        let remaining = max(0, totalAmount - paid)
        
        // Calculate months left based on remaining and monthly payment
        let monthsLeft = monthlyPayment > 0 ? max(1, Int(ceil(remaining / monthlyPayment))) : 1
        
        // Use default title if empty (like in transactions)
        let creditTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "Loan", comment: "Default loan title") : title.trimmingCharacters(in: .whitespaces)
        
        // Create or update the linked Account for this credit
        let creditAccountId: UUID
        if let existingAccountId = existingCredit?.linkedAccountId,
           let existingAccount = accountManager.getAccount(id: existingAccountId) {
            // Update existing account
            var updatedAccount = existingAccount
            updatedAccount.name = creditTitle
            updatedAccount.balance = -remaining // Negative balance represents debt
            accountManager.updateAccount(updatedAccount)
            creditAccountId = existingAccountId
        } else {
            // Create new account for this credit
            let creditAccount = Account(
                name: creditTitle,
                balance: -totalAmount, // Negative initial balance
                includedInTotal: true,
                accountType: .credit,
                currency: settings.currency,
                isPinned: false,
                isSavings: false,
                iconName: "creditcard.fill"
            )
            accountManager.addAccount(creditAccount)
            creditAccountId = creditAccount.id
        }
        
        // Preserve existing interestRate and termMonths when editing
        let credit = Credit(
            id: existingCredit?.id ?? UUID(),
            title: creditTitle,
            totalAmount: totalAmount,
            remaining: remaining,
            paid: paid,
            monthsLeft: monthsLeft,
            dueDate: dueDate,
            monthlyPayment: monthlyPayment,
            interestRate: existingCredit?.interestRate, // Preserve existing value
            startDate: startDate,
            paymentAccountId: selectedAccountId,
            termMonths: existingCredit?.termMonths, // Preserve existing value
            linkedAccountId: creditAccountId
        )
        
        // Save credit to CreditManager
        onSave(credit)
        
        // Create subscription for tracking planned payments if enabled
        if trackInPlannedPayments {
            // Use selectedAccountId or default to first account
            let accountId = selectedAccountId ?? accounts.first?.id
            
            if let accountId = accountId, let creditAccount = accountManager.getAccount(id: creditAccountId) {
                // Delete existing subscription for this credit if editing
                if let existingCredit = existingCredit,
                   let existingSubscription = subscriptionManager.subscriptions.first(where: { $0.linkedCreditId == existingCredit.id }) {
                    subscriptionManager.deleteSubscription(existingSubscription)
                }
                
                // Create new subscription with transfer type
                // BUG FIX: Use startDate for the subscription date and startDate field
                // This ensures the first transaction is created on the correct date (7 December, not 5 December)
                let subscription = PlannedPayment(
                    title: String(localized: "Payment: %@", comment: "Payment title").replacingOccurrences(of: "%@", with: creditTitle),
                    amount: monthlyPayment,
                    date: startDate, // Use startDate as the base date for subscription
                    status: .upcoming,
                    accountId: accountId,
                    toAccountId: creditAccount.id, // Transfer to credit account
                    category: nil, // No category for transfers
                    type: .subscription,
                    isIncome: false, // Not income
                    totalLoanAmount: nil,
                    remainingBalance: nil,
                    startDate: startDate, // CRITICAL: Pass startDate so first transaction uses the correct date
                    interestRate: nil,
                    linkedCreditId: credit.id,
                    isRepeating: true,
                    repetitionFrequency: "Month",
                    repetitionInterval: 1,
                    selectedWeekdays: nil,
                    skippedDates: nil,
                    endDate: nil
                )
                subscriptionManager.addSubscription(subscription)
            }
        } else if let existingCredit = existingCredit {
            // If tracking is disabled, remove existing subscription
            if let existingSubscription = subscriptionManager.subscriptions.first(where: { $0.linkedCreditId == existingCredit.id }) {
                subscriptionManager.deleteSubscription(existingSubscription)
            }
        }
        
        dismiss()
    }
    
    private func formatAmount(_ value: Double) -> String {
        if value == 0 {
            return ""
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
    
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
        
        if totalAmount == 0 && !cleaned.isEmpty {
            if let firstChar = cleaned.first, firstChar.isNumber, firstChar != "0" {
                amountText = cleaned
                if let value = Double(cleaned) {
                    totalAmount = value
                }
                return
            }
        }
        
        amountText = cleaned
        
        if let value = Double(cleaned) {
            totalAmount = value
        } else if cleaned.isEmpty {
            totalAmount = 0
        }
    }
    
    /// Update all fields from existingCredit
    private func updateFieldsFromExistingCredit() {
        if let existing = existingCredit {
            title = existing.title
            totalAmount = existing.totalAmount
            monthlyPayment = existing.monthlyPayment
            startDate = existing.startDate ?? existing.dueDate
            dueDate = existing.dueDate
            
            // Verify account still exists before setting selectedAccountId
            if let accountId = existing.paymentAccountId,
               let account = accountManager.getAccount(id: accountId),
               account.accountType != .credit && !account.isSavings {
                selectedAccountId = accountId
            } else {
                // Account doesn't exist or is invalid, use default account or first available account
                // Filter default account to ensure it's valid for credits (not credit type, not savings)
                if let defaultId = accountManager.getDefaultAccountId(),
                   let defaultAccount = accountManager.getAccount(id: defaultId),
                   defaultAccount.accountType != .credit && !defaultAccount.isSavings {
                    selectedAccountId = defaultId
                } else {
                    selectedAccountId = accounts.first?.id
                }
            }
            
            // Update amount text
            amountText = formatAmount(totalAmount)
            
            // Check if subscription exists for existing credit
            let hasSubscription = subscriptionManager.subscriptions.contains { $0.linkedCreditId == existing.id }
            trackInPlannedPayments = hasSubscription
        } else {
            // Reset to defaults for new credit
            title = ""
            totalAmount = 0
            monthlyPayment = 0
            startDate = Date()
            dueDate = Date()
            amountText = ""
            trackInPlannedPayments = true
            
            // Set default account if not set (only if account exists)
            if selectedAccountId == nil {
                // Use default account if available and valid for credits, otherwise use first available
                if let defaultId = accountManager.getDefaultAccountId(),
                   let defaultAccount = accountManager.getAccount(id: defaultId),
                   defaultAccount.accountType != .credit && !defaultAccount.isSavings {
                    selectedAccountId = defaultId
                } else if let firstAccount = accounts.first {
                    selectedAccountId = firstAccount.id
                }
            } else if let accountId = selectedAccountId {
                // Verify selected account still exists
                if accountManager.getAccount(id: accountId) == nil {
                    // Use default account if available and valid, otherwise use first available
                    if let defaultId = accountManager.getDefaultAccountId(),
                       let defaultAccount = accountManager.getAccount(id: defaultId),
                       defaultAccount.accountType != .credit && !defaultAccount.isSavings {
                        selectedAccountId = defaultId
                    } else {
                        selectedAccountId = accounts.first?.id
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Input (Total Debt) - Orange theme with icon
                        VStack(spacing: 8) {
                            Text(String(localized: "Total Loan Amount", comment: "Total loan amount label"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                // Banknote/Signature icon (Orange)
                                Image(systemName: "banknote")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.orange)
                                
                                Spacer()
                                
                                // Large amount input (Orange)
                                TextField("0", text: $amountText)
                                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isAmountFocused)
                                    .foregroundStyle(.orange)
                                    .frame(minWidth: 120)
                                    .onChange(of: amountText) { oldValue, newValue in
                                        handleAmountInput(newValue)
                                    }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Specialized Loan Fields
                        VStack(spacing: 16) {
                            // Loan Name
                            CreditFormRow(
                                icon: "text.alignleft",
                                title: String(localized: "Loan Name", comment: "Loan name field"),
                                value: $title,
                                placeholder: String(localized: "e.g., Car Loan", comment: "Loan name placeholder")
                            )
                            
                            // Monthly Payment
                            CreditAmountRow(
                                icon: "dollarsign.circle",
                                title: String(localized: "Monthly Payment", comment: "Monthly payment field"),
                                amount: $monthlyPayment,
                                placeholder: "0.00"
                            )
                            
                            // Track in Planned Payments Toggle
                            CreditToggleRow(
                                icon: "calendar.badge.plus",
                                title: String(localized: "Track in Planned Payments", comment: "Track in planned payments toggle"),
                                isOn: $trackInPlannedPayments
                            )
                            
                            // Start Date
                            CreditDateRow(
                                icon: "calendar",
                                title: String(localized: "Start Date", comment: "Start date field"),
                                date: $startDate
                            )
                            
                            // Account Selection
                            CreditAccountRow(
                                icon: "creditcard",
                                title: "Account",
                                selectedAccount: selectedAccount,
                                onTap: {
                                    showAccountPicker = true
                                }
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(existingCredit != nil ? String(localized: "Edit Credit", comment: "Edit credit title") : String(localized: "Add Credit", comment: "Add credit title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarButtons
                }
            }
            .alert(String(localized: "Delete Credit", comment: "Delete credit alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    if let credit = existingCredit {
                        onDelete?(credit)
                    }
                }
            } message: {
                if let credit = existingCredit {
                    Text(String(localized: "Are you sure you want to delete \"%@\"? This action cannot be undone.", comment: "Delete credit confirmation").replacingOccurrences(of: "%@", with: credit.title))
                }
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet
            }
            .onAppear {
                // Update fields from existingCredit when view appears
                // This ensures fields are populated when editing a credit
                updateFieldsFromExistingCredit()
                
                // Auto-focus amount field (only for new credits)
                if existingCredit == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAmountFocused = true
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Account Picker Sheet
    
    private var accountPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // Only show accounts that exist in accountManager and match our filter criteria
                    ForEach(accounts.filter { account in
                        // Double-check that account still exists in accountManager
                        accountManager.getAccount(id: account.id) != nil
                    }) { account in
                        accountPickerItem(account: account)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "Select Account", comment: "Select account title"))
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
            // Verify account still exists before selecting it
            if let existingAccount = accountManager.getAccount(id: account.id),
               existingAccount.accountType != .credit && !existingAccount.isSavings {
                selectedAccountId = account.id
            } else {
                // Account was deleted or is invalid, use first available account
                selectedAccountId = accounts.first?.id
            }
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
                    Text(currencyString(account.balance, code: account.currency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedAccountId == account.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background(selectedAccountId == account.id ? Color.orange.opacity(0.1) : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedAccountId == account.id ? Color.orange.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: selectedAccountId == account.id ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Components

struct CreditFormRow: View {
    let icon: String
    let title: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.orange)
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

struct CreditAmountRow: View {
    let icon: String
    let title: String
    @Binding var amount: Double
    let placeholder: String
    
    @State private var amountText: String = ""
    @FocusState private var isFocused: Bool
    
    private func formatAmount(_ value: Double) -> String {
        if value == 0 {
            return ""
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            TextField(placeholder, text: $amountText)
                .font(.body)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onChange(of: amountText) { oldValue, newValue in
                    // Normalize input to accept both dots and commas
                    var cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                    cleaned = cleaned.filter { $0.isNumber || $0 == "." }
                    let components = cleaned.split(separator: ".", omittingEmptySubsequences: false)
                    if components.count > 2 {
                        let firstPart = String(components[0])
                        let rest = components.dropFirst().joined(separator: "")
                        cleaned = firstPart + "." + rest
                    }
                    amountText = cleaned
                    if let value = Double(cleaned) {
                        amount = value
                    } else if cleaned.isEmpty {
                        amount = 0
                    }
                }
                .onChange(of: amount) { oldValue, newValue in
                    if !isFocused {
                        amountText = formatAmount(newValue)
                    }
                }
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            amountText = formatAmount(amount)
        }
    }
}

struct CreditDateRow: View {
    let icon: String
    let title: String
    @Binding var date: Date
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.orange)
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

struct CreditAccountRow: View {
    let icon: String
    let title: String
    let selectedAccount: Account?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let account = selectedAccount {
                    Text(account.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "Select Account", comment: "Select account placeholder"))
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.6))
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

struct CreditToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
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

