//
//  TransactionsChartsHeader.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 25/11/2025.
//

import SwiftUI
import Charts

struct TransactionsChartsHeader: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @StateObject private var dataProvider: ChartDataProvider
    
    init(transactions: [Transaction], currency: String = "PLN") {
        _dataProvider = StateObject(wrappedValue: ChartDataProvider(transactions: transactions, currency: currency))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            incomeExpenseChart
                .padding(.bottom, 16)
        }
        .onChange(of: settings.currency) { _ in
            dataProvider.updateData()
        }
        .onChange(of: transactionManager.transactions) { oldValue, newValue in
            // Обновляем только если транзакции действительно изменились
            if oldValue.count != newValue.count || 
               !oldValue.elementsEqual(newValue, by: { $0.id == $1.id }) {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                    dataProvider.updateTransactions(newValue)
                }
            }
        }
        .onAppear {
            dataProvider.updateTransactions(transactionManager.transactions)
        }
    }
    
    // MARK: - Income vs Expense Chart
    private var incomeExpenseChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Income vs Expense")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Text(String(localized: "Current month", comment: "Current month label"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Chart with Center Text
            ZStack {
                Chart {
                    let summary = dataProvider.incomeExpenseSummary
                    let total = summary.total
                    
                    if total > 0 {
                        // Income sector
                        if summary.income > 0 {
                            SectorMark(
                                angle: .value("Income", summary.income),
                                innerRadius: .ratio(0.65),
                                angularInset: 2
                            )
                            .foregroundStyle(incomeGreen)
                            .cornerRadius(4)
                        }
                        
                        // Expense sector
                        if summary.expense > 0 {
                            SectorMark(
                                angle: .value("Expense", summary.expense),
                                innerRadius: .ratio(0.65),
                                angularInset: 2
                            )
                            .foregroundStyle(expenseRed)
                            .cornerRadius(4)
                        }
                    } else {
                        // Empty state - show a full circle
                        SectorMark(
                            angle: .value("Empty", 360),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .foregroundStyle(Color.secondary.opacity(0.1))
                    }
                }
                .frame(height: 180)
                
                // Center Text - Net Balance
                VStack(spacing: 4) {
                    Text(formatNetBalance(dataProvider.incomeExpenseSummary.netBalance))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text(String(localized: "Net Balance", comment: "Net balance label"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            
            // Custom Legend
            customLegend
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Custom Legend
    private var customLegend: some View {
        HStack(spacing: 24) {
            legendItem(color: incomeGreen, label: "Income", amount: dataProvider.incomeExpenseSummary.income)
            legendItem(color: expenseRed, label: "Expense", amount: dataProvider.incomeExpenseSummary.expense)
        }
    }
    
    private func legendItem(color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Functions
    private func formatNetBalance(_ balance: Double) -> String {
        let formatted = currencyString(abs(balance), code: settings.currency)
        return balance >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
    
    // MARK: - Design Colors
    private var incomeGreen: Color {
        Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    }
    
    private var expenseRed: Color {
        Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    }
    
    private var accentBlue: Color {
        Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF
    }
}

// MARK: - Preview
#Preview {
    // Preview uses mock data - simplified for preview
    TransactionsChartsHeader(transactions: Transaction.sample())
        .environmentObject(AppSettings())
        .background(Color.customBackground)
}
