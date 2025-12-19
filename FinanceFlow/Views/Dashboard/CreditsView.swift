//
//  CreditsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct CreditsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var creditManager: CreditManager
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showAddSheet = false
    @State private var editingCredit: Credit?
    @State private var showingPaymentSheet = false
    @State private var creditForPayment: Credit?
    @State private var creditToDelete: Credit?
    @State private var showDeleteAlert = false
    @State private var selectedSubscription: PlannedPayment? = nil // For editing credit via subscription
    @State private var selectedOccurrenceDate: Date? = nil
    
    private var totalRemaining: Double {
        creditManager.totalRemaining
    }
    
    var body: some View {
        ZStack {
            Color.customBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Total Remaining Debt Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Total Remaining Debt", comment: "Total remaining debt label"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(currencyString(totalRemaining, code: settings.currency))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.customCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Credits List
                    if creditManager.credits.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text(String(localized: "No credits or loans", comment: "No credits message"))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(creditManager.credits) { credit in
                                CreditCard(
                                    credit: credit,
                                    onEdit: {
                                        // When editing credit, always open subscription form (like in Future tab)
                                        // This allows editing amount, account, and other subscription properties
                                        // First, try to find existing subscription
                                        if let subscription = subscriptionManager.subscriptions.first(where: { $0.linkedCreditId == credit.id }) {
                                            selectedSubscription = subscription
                                        } else {
                                            // If no subscription exists, create a temporary one for editing
                                            // This allows editing credit properties through subscription form
                                            if let creditAccountId = credit.linkedAccountId,
                                               let creditAccount = accountManager.getAccount(id: creditAccountId),
                                               let paymentAccountId = credit.paymentAccountId ?? accountManager.accounts.first(where: { $0.accountType != .credit && !$0.isSavings })?.id {
                                                // Create temporary subscription for editing
                                                let tempSubscription = PlannedPayment(
                                                    title: String(localized: "Payment: %@", comment: "Payment title").replacingOccurrences(of: "%@", with: credit.title),
                                                    amount: credit.monthlyPayment,
                                                    date: credit.startDate ?? credit.dueDate,
                                                    status: .upcoming,
                                                    accountId: paymentAccountId,
                                                    toAccountId: creditAccount.id,
                                                    category: nil,
                                                    type: .subscription,
                                                    isIncome: false,
                                                    totalLoanAmount: nil,
                                                    remainingBalance: nil,
                                                    startDate: credit.startDate,
                                                    interestRate: nil,
                                                    linkedCreditId: credit.id,
                                                    isRepeating: true,
                                                    repetitionFrequency: "Month",
                                                    repetitionInterval: 1,
                                                    selectedWeekdays: nil,
                                                    skippedDates: nil,
                                                    endDate: nil
                                                )
                                                // Add temporary subscription to manager (will be saved when user saves)
                                                subscriptionManager.addSubscription(tempSubscription)
                                                selectedSubscription = tempSubscription
                                            } else {
                                                // Fallback: open credit form if we can't create subscription
                                                editingCredit = credit
                                                showAddSheet = true
                                            }
                                        }
                                    },
                                    onDelete: {
                                        creditToDelete = credit
                                        showDeleteAlert = true
                                    }
                                )
                                .environmentObject(subscriptionManager)
                                .environmentObject(transactionManager)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        editingCredit = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.orange)
                                    .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 6)
                            )
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 110)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Credits & Loans")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            AddCreditFormView(
                existingCredit: editingCredit,
                onSave: { credit in
                    if editingCredit != nil {
                        creditManager.updateCredit(credit)
                    } else {
                        creditManager.addCredit(credit)
                    }
                    showAddSheet = false
                    editingCredit = nil
                },
                onCancel: {
                    showAddSheet = false
                    editingCredit = nil
                },
                onDelete: editingCredit != nil ? { credit in
                    creditManager.deleteCredit(credit, accountManager: accountManager, subscriptionManager: subscriptionManager)
                    showAddSheet = false
                    editingCredit = nil
                } : nil
            )
            .environmentObject(settings)
            .environmentObject(accountManager)
            .environmentObject(creditManager)
            .environmentObject(subscriptionManager)
            .id(editingCredit?.id ?? UUID()) // Force view update when editingCredit changes
        }
        .sheet(isPresented: $showingPaymentSheet) {
            if let credit = creditForPayment {
                CreditPaymentSheet(
                    credit: credit,
                    onPayment: { amount, date, account in
                        // Handle payment logic
                        if let account = account, let creditAccountId = credit.linkedAccountId, let creditAccount = accountManager.getAccount(id: creditAccountId) {
                            creditManager.updateCreditBalance(
                                creditId: credit.id,
                                paymentAmount: amount,
                                accountManager: accountManager
                            )
                            
                            // Create transfer transaction (from main account to credit account)
                            let transaction = Transaction(
                                title: String(localized: "Payment: %@", comment: "Payment title").replacingOccurrences(of: "%@", with: credit.title),
                                category: "Transfer",
                                amount: amount,
                                date: date,
                                type: .transfer,
                                accountId: account.id,
                                toAccountId: creditAccount.id,
                                currency: settings.currency
                            )
                            transactionManager.addTransaction(transaction)
                        }
                        showingPaymentSheet = false
                        creditForPayment = nil
                    },
                    onCancel: {
                        showingPaymentSheet = false
                        creditForPayment = nil
                    }
                )
                .environmentObject(settings)
                .environmentObject(accountManager)
            }
        }
        .sheet(item: $selectedSubscription) { subscription in
            AddSubscriptionFormView(
                existingPayment: subscription,
                initialIsIncome: subscription.isIncome,
                occurrenceDate: selectedOccurrenceDate,
                onSave: { payment in
                    // Update subscription
                    subscriptionManager.updateSubscription(payment)
                    
                    // Also update the linked credit with new values from subscription
                    if let linkedCreditId = payment.linkedCreditId,
                       let existingCredit = creditManager.getCredit(id: linkedCreditId) {
                        // Create updated credit with new values from subscription
                        let updatedCredit = Credit(
                            id: existingCredit.id,
                            title: existingCredit.title,
                            totalAmount: existingCredit.totalAmount,
                            remaining: existingCredit.remaining,
                            paid: existingCredit.paid,
                            monthsLeft: existingCredit.monthsLeft,
                            dueDate: existingCredit.dueDate,
                            monthlyPayment: payment.amount, // Update from subscription
                            interestRate: existingCredit.interestRate,
                            startDate: payment.startDate, // Update from subscription
                            paymentAccountId: payment.accountId, // Update from subscription
                            termMonths: existingCredit.termMonths,
                            linkedAccountId: existingCredit.linkedAccountId
                        )
                        creditManager.updateCredit(updatedCredit)
                    }
                    
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                },
                onCancel: {
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                },
                onDeleteSingle: { payment, date in
                    // Find the transaction for this specific date
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
                    // Handle pay action - create the paid transaction
                    let paymentDate = Date()
                    
                    if let subscription = selectedSubscription {
                        // First, find and delete the subscription transaction
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
                        
                        // Create the paid transaction
                        let transaction = Transaction(
                            title: subscription.title,
                            category: subscription.category ?? "General",
                            amount: subscription.amount,
                            date: paymentDate,
                            type: transactionType,
                            accountId: subscription.accountId,
                            toAccountId: subscription.toAccountId,
                            currency: settings.currency,
                            sourcePlannedPaymentId: nil,
                            occurrenceDate: nil
                        )
                        transactionManager.addTransaction(transaction)
                        // Balance is updated automatically by CreateTransactionUseCase
                    }
                    selectedSubscription = nil
                    selectedOccurrenceDate = nil
                }
            )
            .environmentObject(settings)
            .environmentObject(accountManager)
            .environmentObject(creditManager)
            .environmentObject(transactionManager)
        }
        .alert(String(localized: "Delete Loan", comment: "Delete loan alert title"), isPresented: $showDeleteAlert) {
            Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
                creditToDelete = nil
            }
            Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                if let credit = creditToDelete {
                    creditManager.deleteCredit(credit, accountManager: accountManager, subscriptionManager: subscriptionManager)
                    creditToDelete = nil
                }
            }
        } message: {
            if let credit = creditToDelete {
                Text(String(localized: "Are you sure you want to delete \"%@\"? This action cannot be undone.", comment: "Delete loan confirmation").replacingOccurrences(of: "%@", with: credit.title))
            }
        }
    }
}

struct CreditCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var accountManager: AccountManager
    let credit: Credit
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var progressColor: Color {
        let progress = credit.progress
        if progress < 30 {
            return .orange
        } else if progress < 70 {
            return .blue
        } else {
            return .green
        }
    }
    
    // Get subscription for this credit
    private var creditSubscription: PlannedPayment? {
        subscriptionManager.subscriptions.first { $0.linkedCreditId == credit.id }
    }
    
    // Get future payment dates
    private var futurePayments: [Date] {
        guard let subscription = creditSubscription else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return transactionManager.transactions
            .filter { $0.sourcePlannedPaymentId == subscription.id }
            .filter { calendar.startOfDay(for: $0.date) >= today }
            .map { $0.date }
            .sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header: Icon + Title + Delete Button
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(progressColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundStyle(progressColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(credit.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    if let accountName = credit.paymentAccountName(accountManager: accountManager) {
                        Text(String(localized: "From: %@", comment: "From account").replacingOccurrences(of: "%@", with: accountName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Progress Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(format: String(localized: "%d%% Paid", comment: "Percent paid"), Int(credit.percentPaid)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: credit.percentPaid)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        // Progress bar with animation
                        // BUG FIX 3: Ensure progress bar updates dynamically with smooth animation
                        RoundedRectangle(cornerRadius: 8)
                            .fill(progressColor)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * (credit.progress / 100))), height: 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: credit.progress)
                    }
                }
                .frame(height: 12)
            }
            
            // Financial Info Grid
            VStack(spacing: 12) {
                // Row 1: Total Amount and Paid
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Total Amount", comment: "Total amount label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currencyString(credit.totalAmount, code: settings.currency))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Paid", comment: "Paid label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currencyString(credit.paid, code: settings.currency))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: credit.paid)
                    }
                }
                
                // Row 2: Remaining and Monthly Payment
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Remaining", comment: "Remaining label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currencyString(credit.remaining, code: settings.currency))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: credit.remaining)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Monthly Payment", comment: "Monthly payment label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currencyString(credit.monthlyPayment, code: settings.currency))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Future Payments (if tracking is enabled)
            if !futurePayments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(String(localized: "Upcoming Payments", comment: "Upcoming payments label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    
                    // Show next 3 payments
                    ForEach(Array(futurePayments.prefix(3).enumerated()), id: \.offset) { index, date in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currencyString(credit.monthlyPayment, code: settings.currency))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if futurePayments.count > 3 {
                        Text(String(format: String(localized: "+ %d more", comment: "More payments count"), futurePayments.count - 3))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
        }
        .padding(20)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

