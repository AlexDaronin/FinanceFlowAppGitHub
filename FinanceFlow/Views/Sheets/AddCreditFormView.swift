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
    
    let existingCredit: Credit?
    let onSave: (Credit) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var totalAmount: Double = 0
    @State private var monthlyPayment: Double = 0
    @State private var interestRate: String = ""
    @State private var startDate: Date = Date()
    @State private var dueDate: Date = Date()
    @State private var termMonths: String = ""
    @State private var selectedAccountName: String? = nil
    @State private var trackInPlannedPayments: Bool = true // Default to true
    
    @State private var showAccountPicker = false
    
    @FocusState private var isAmountFocused: Bool
    @State private var amountText: String = ""
    
    // Get accounts from settings or use sample
    private var accounts: [Account] {
        Account.sample // You may want to get this from settings or a manager
    }
    
    private var selectedAccount: Account? {
        if let accountName = selectedAccountName,
           let account = accounts.first(where: { $0.name == accountName }) {
            return account
        }
        return accounts.first
    }
    
    init(
        existingCredit: Credit? = nil,
        onSave: @escaping (Credit) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingCredit = existingCredit
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let existing = existingCredit {
            _title = State(initialValue: existing.title)
            _totalAmount = State(initialValue: existing.totalAmount)
            _monthlyPayment = State(initialValue: existing.monthlyPayment)
            _interestRate = State(initialValue: existing.interestRate.map { String(format: "%.2f", $0) } ?? "")
            _startDate = State(initialValue: existing.startDate ?? existing.dueDate)
            _dueDate = State(initialValue: existing.dueDate)
            _termMonths = State(initialValue: existing.termMonths.map { String($0) } ?? "")
            _selectedAccountName = State(initialValue: existing.accountName)
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        totalAmount > 0 &&
        monthlyPayment > 0
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
        let cleaned = newValue.filter { $0.isNumber || $0 == "." }
        
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Input (Total Debt) - Orange theme with icon
                        VStack(spacing: 8) {
                            Text("Total Loan Amount")
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
                                title: "Loan Name",
                                value: $title,
                                placeholder: "e.g., Car Loan"
                            )
                            
                            // Monthly Payment
                            CreditAmountRow(
                                icon: "dollarsign.circle",
                                title: "Monthly Payment",
                                amount: $monthlyPayment,
                                placeholder: "0.00"
                            )
                            
                            // Track in Planned Payments Toggle
                            CreditToggleRow(
                                icon: "calendar.badge.plus",
                                title: "Track in Planned Payments",
                                isOn: $trackInPlannedPayments
                            )
                            
                            // Interest Rate (Optional)
                            CreditFormRow(
                                icon: "percent",
                                title: "Interest Rate",
                                value: Binding(
                                    get: { interestRate },
                                    set: { newValue in
                                        let cleaned = newValue.filter { $0.isNumber || $0 == "." }
                                        interestRate = cleaned
                                    }
                                ),
                                placeholder: "Optional (e.g., 5.5)"
                            )
                            
                            // Start Date
                            CreditDateRow(
                                icon: "calendar",
                                title: "Start Date",
                                date: $startDate
                            )
                            
                            // Term (Months) - Optional
                            CreditFormRow(
                                icon: "calendar.badge.clock",
                                title: "Term (Months)",
                                value: Binding(
                                    get: { termMonths },
                                    set: { newValue in
                                        let cleaned = newValue.filter { $0.isNumber }
                                        termMonths = cleaned
                                    }
                                ),
                                placeholder: "Optional (e.g., 60)"
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
                        
                        // Save Button
                        Button {
                            let interestRateValue = interestRate.isEmpty ? nil : Double(interestRate)
                            let termMonthsValue = termMonths.isEmpty ? nil : Int(termMonths)
                            
                            // Calculate remaining and paid amounts
                            // When editing, preserve the paid amount; when creating, paid is 0
                            let paid = existingCredit?.paid ?? 0
                            let remaining = max(0, totalAmount - paid)
                            
                            // Calculate months left
                            // If term is provided, use it; otherwise calculate from remaining and monthly payment
                            let monthsLeft: Int
                            if let term = termMonthsValue {
                                // If we have a term, calculate remaining months based on progress
                                let progress = totalAmount > 0 ? (paid / totalAmount) : 0
                                monthsLeft = max(1, Int(Double(term) * (1 - progress)))
                            } else {
                                // Fallback to calculation based on remaining and monthly payment
                                monthsLeft = monthlyPayment > 0 ? max(1, Int(ceil(remaining / monthlyPayment))) : 1
                            }
                            
                            let credit = Credit(
                                id: existingCredit?.id ?? UUID(),
                                title: title.trimmingCharacters(in: .whitespaces),
                                totalAmount: totalAmount,
                                remaining: remaining,
                                paid: paid,
                                monthsLeft: monthsLeft,
                                dueDate: dueDate,
                                monthlyPayment: monthlyPayment,
                                interestRate: interestRateValue,
                                startDate: startDate,
                                accountName: selectedAccountName,
                                termMonths: termMonthsValue
                            )
                            
                            // Save credit to CreditManager
                            onSave(credit)
                            
                            // If toggle is ON, also create a PlannedPayment and save to SubscriptionManager
                            if trackInPlannedPayments {
                                let plannedPayment = PlannedPayment(
                                    title: title.trimmingCharacters(in: .whitespaces),
                                    amount: monthlyPayment,
                                    date: dueDate,
                                    status: .upcoming,
                                    accountName: selectedAccountName ?? "Main Card",
                                    category: "Debt",
                                    type: .loan,
                                    isIncome: false,
                                    totalLoanAmount: totalAmount,
                                    remainingBalance: remaining,
                                    startDate: startDate,
                                    interestRate: interestRateValue
                                )
                                SubscriptionManager.shared.addSubscription(plannedPayment)
                            }
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? Color.orange : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!isValid)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(existingCredit != nil ? "Edit Credit" : "Add Credit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet
            }
            .onAppear {
                // Initialize amount text from totalAmount
                if totalAmount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(totalAmount)
                }
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
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
                    ForEach(accounts) { account in
                        accountPickerItem(account: account)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showAccountPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func accountPickerItem(account: Account) -> some View {
        Button {
            selectedAccountName = account.name
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
                if selectedAccountName == account.name {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background(selectedAccountName == account.name ? Color.orange.opacity(0.1) : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedAccountName == account.name ? Color.orange.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: selectedAccountName == account.name ? 1.5 : 1)
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
                    let cleaned = newValue.filter { $0.isNumber || $0 == "." }
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
                    Text("Select Account")
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
