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

// MARK: - Statistics View

struct StatisticsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var showExpensesSheet = false
    
    private var expensesSummary: ExpensesSummary {
        calculateExpensesSummary(
            transactions: transactionManager.transactions,
            categories: settings.categories
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    .padding(.top)
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
        }
    }
}

// MARK: - Helper Function

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
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(currencyString(totalAmount, code: currency))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Right side: Miniature donut chart
                Chart(categoryData) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                    )
                    .foregroundStyle(item.color)
                }
                .frame(width: 80, height: 80)
                .chartBackground { chartProxy in
                    // Empty background for mini chart
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
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded Sheet View

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
                        .foregroundStyle(item.color)
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
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
