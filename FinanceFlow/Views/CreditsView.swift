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
    @EnvironmentObject var accountManager: AccountManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @State private var showAddSheet = false
    @State private var editingCredit: Credit?
    @State private var showingPaymentSheet = false
    @State private var creditForPayment: Credit?
    @State private var creditToDelete: Credit?
    @State private var showDeleteAlert = false
    
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
                        Text("Total Remaining Debt")
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
                            Text("No credits or loans")
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
                                    onPay: {
                                        creditForPayment = credit
                                        showingPaymentSheet = true
                                    },
                                    onEdit: {
                                        editingCredit = credit
                                        showAddSheet = true
                                    },
                                    onDelete: {
                                        creditToDelete = credit
                                        showDeleteAlert = true
                                    }
                                )
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
                    creditManager.deleteCredit(credit, accountManager: accountManager)
                    showAddSheet = false
                    editingCredit = nil
                } : nil
            )
            .environmentObject(settings)
            .environmentObject(accountManager)
            .environmentObject(creditManager)
        }
        .sheet(isPresented: $showingPaymentSheet) {
            if let credit = creditForPayment {
                CreditPaymentSheet(
                    credit: credit,
                    onPayment: { amount, date, account in
                        // Handle payment logic
                        if let account = account {
                            creditManager.updateCreditBalance(
                                creditId: credit.id,
                                paymentAmount: amount,
                                accountManager: accountManager
                            )
                            
                            // Create transaction
                            let transaction = Transaction(
                                title: "Payment: \(credit.title)",
                                category: "Debt",
                                amount: amount,
                                date: date,
                                type: .expense,
                                accountName: account.name,
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
        .alert("Delete Loan", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                creditToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let credit = creditToDelete {
                    creditManager.deleteCredit(credit, accountManager: accountManager)
                    creditToDelete = nil
                }
            }
        } message: {
            if let credit = creditToDelete {
                Text("Are you sure you want to delete \"\(credit.title)\"? This action cannot be undone.")
            }
        }
    }
}

struct CreditCard: View {
    @EnvironmentObject var settings: AppSettings
    let credit: Credit
    let onPay: () -> Void
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Row: Icon + Title + Next Payment
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(progressColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundStyle(progressColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(credit.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("Next payment: \(credit.dueDate.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Middle: Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(credit.percentPaid))% Paid")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * (credit.progress / 100), height: 12)
                    }
                }
                .frame(height: 12)
            }
            
            // Bottom Row: Left vs Total
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.remaining, code: settings.currency))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.totalAmount, code: settings.currency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    onPay()
                } label: {
                    Text("Pay")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                
                Button {
                    onEdit()
                } label: {
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

