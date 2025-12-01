//
//  CreditPaymentSheet.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct CreditPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManager
    
    let credit: Credit
    let onPayment: (Double, Date, Account?) -> Void
    let onCancel: () -> Void
    
    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedAccount: Account?
    @State private var showAccountPicker = false
    
    @FocusState private var isAmountFocused: Bool
    
    private var accounts: [Account] {
        accountManager.accounts.filter { $0.accountType != .credit }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        VStack(spacing: 8) {
                            Text("Make Payment")
                                .font(.title2.weight(.bold))
                            Text(credit.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Amount Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $amountText)
                                .font(.system(size: 40, weight: .bold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($isAmountFocused)
                                .onChange(of: amountText) { oldValue, newValue in
                                    let cleaned = normalizeDecimalInput(newValue)
                                    amountText = cleaned
                                    if let value = Double(cleaned) {
                                        amount = value
                                    } else if cleaned.isEmpty {
                                        amount = 0
                                    }
                                }
                        }
                        .padding(.horizontal)
                        
                        // Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                        .padding(.horizontal)
                        
                        // Account Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From Account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                showAccountPicker = true
                            } label: {
                                HStack {
                                    if let account = selectedAccount {
                                        Text(account.name)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Text("Select Account")
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.customCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Pay Button
                        Button {
                            onPayment(amount, selectedDate, selectedAccount ?? accounts.first)
                            dismiss()
                        } label: {
                            Text("Pay")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(amount > 0 ? Color.blue : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(amount <= 0)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet
            }
            .onAppear {
                amount = credit.monthlyPayment
                amountText = String(format: "%.2f", credit.monthlyPayment)
                selectedAccount = accounts.first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
        }
    }
    
    private var accountPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accounts) { account in
                        Button {
                            selectedAccount = account
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
                                    Text(currencyString(account.balance, code: settings.currency))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedAccount?.id == account.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(12)
                            .background(selectedAccount?.id == account.id ? Color.accentColor.opacity(0.1) : Color.customCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
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
}

