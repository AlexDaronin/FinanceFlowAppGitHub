//
//  CreditsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct CreditsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var manager: CreditManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showAddSheet = false
    @State private var selectedCredit: Credit?
    @State private var creditToDelete: Credit?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Bottom Layer: Background
            Color.customBackground.ignoresSafeArea()
            
            // Middle Layer: Scrollable Content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Top anchor for scroll reset
                        Color.clear
                            .frame(height: 0)
                            .id("top")
                        
                        // Total Remaining Debt Summary Card (Red accent)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Remaining Debt", comment: "Total remaining debt label")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(currencyString(manager.totalRemaining, code: settings.currency))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.customCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Credits List
                    if manager.credits.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("No credits or loans", comment: "No credits empty state")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(manager.credits) { credit in
                            Button {
                                selectedCredit = credit
                            } label: {
                                CreditCard(credit: credit)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    creditToDelete = credit
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
                                }
                            }
                            .padding(.horizontal)
                        }
                        }
                    }
                    .padding(.bottom, 100) // Space for FAB button
                }
                .onAppear {
                    // Reset scroll position when view appears
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            
            // Standardized Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // --- BUTTON ---
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56) // Fixed standard size
                            .background(
                                Circle()
                                    .fill(Color.red) // <--- Change this per view
                                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 6)
                            )
                    }
                    // ----------------
                }
                .padding(.trailing, 20) // Fixed right margin
                .padding(.bottom, 110)   // Fixed bottom margin (optimized for thumb reach)
            }
            .ignoresSafeArea() // CRITICAL: Pins button relative to screen edge, ignoring layout differences
        }
        .navigationTitle(Text("Credits & Loans", comment: "Credits view title"))
        .sheet(isPresented: $showAddSheet) {
            AddCreditFormView(
                onSave: { newCredit in
                    manager.addCredit(newCredit)
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
            .environmentObject(settings)
        }
        .sheet(item: $selectedCredit) { credit in
            AddCreditFormView(
                existingCredit: credit,
                onSave: { updatedCredit in
                    manager.updateCredit(updatedCredit)
                    selectedCredit = nil
                },
                onCancel: {
                    selectedCredit = nil
                },
                onDelete: { creditToDelete in
                    manager.deleteCredit(creditToDelete)
                    // Also delete associated PlannedPayment if it exists
                    if let associatedPayment = subscriptionManager.subscriptions.first(where: { 
                        $0.type == .loan && $0.title == creditToDelete.title 
                    }) {
                        subscriptionManager.deleteSubscription(associatedPayment)
                    }
                    selectedCredit = nil
                }
            )
            .environmentObject(settings)
        }
        .alert("Delete Credit", isPresented: $showDeleteConfirmation, presenting: creditToDelete) { credit in
            Button("Cancel", role: .cancel) {
                creditToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let credit = creditToDelete {
                    manager.deleteCredit(credit)
                    creditToDelete = nil
                }
            }
        } message: { credit in
            Text("Are you sure you want to delete \"\(credit.title)\"? This action cannot be undone.")
        }
    }
}

// MARK: - CreditCard (The "Pro" Look)

struct CreditCard: View {
    @EnvironmentObject var settings: AppSettings
    let credit: Credit
    
    private var iconName: String {
        let title = credit.title.lowercased()
        if title.contains("car") || title.contains("auto") || title.contains("vehicle") {
            return "car.fill"
        } else if title.contains("home") || title.contains("house") || title.contains("mortgage") {
            return "house.fill"
        } else if title.contains("bank") || title.contains("personal") {
            return "banknote.fill"
        } else {
            return "creditcard.fill"
        }
    }
    
    private var progressColor: Color {
        let progress = credit.progress
        if progress < 25 {
            return .orange
        } else if progress < 75 {
            return .blue
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Row: Icon + Title + Next Payment Date
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(progressColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundStyle(progressColor)
                }
                
                // Title
                Text(credit.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Next Payment Date (Gray caption)
                Text("\(String(localized: "Next payment:", comment: "Next payment prefix")) \(shortDate(credit.dueDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Middle: Thick Rounded Linear Progress Bar with % Paid
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(String(format: "%.1f", credit.percentPaid))% \(String(localized: "Paid", comment: "Paid percentage"))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background (gray)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 16)
                        
                        // Foreground (colored)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [progressColor, progressColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, min(geometry.size.width * (credit.progress / 100), geometry.size.width)),
                                height: 16
                            )
                    }
                }
                .frame(height: 16)
            }
            
            // Bottom Row: Left vs Total
            HStack {
                // Left (Bold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Left", comment: "Left amount label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.remaining, code: settings.currency))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Total (Gray)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total", comment: "Total amount label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.totalAmount, code: settings.currency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

