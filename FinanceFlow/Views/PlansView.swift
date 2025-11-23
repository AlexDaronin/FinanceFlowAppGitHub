//
//  PlansView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts

struct PlansView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedType: PlanType = .expenses
    @State private var currentPeriodOffset: Int = 0
    @State private var showBankConnectionPrompt = true
    @State private var showExpenseEditor = false
    @State private var editedExpenseAmount: Double = 0
    
    let transactions: [Transaction]
    let plannedPayments: [PlannedPayment]
    let accounts: [Account]
    
    enum PlanType: String, CaseIterable {
        case expenses = "Expenses"
        case income = "Income"
        
        var transactionType: TransactionType {
            switch self {
            case .expenses:
                return .expense
            case .income:
                return .income
            }
        }
    }
    
    private var periodStart: Date {
        let calendar = Calendar.current
        let today = Date()
        let baseDate = calendar.date(byAdding: .month, value: currentPeriodOffset, to: today) ?? today
        let todayDay = calendar.component(.day, from: baseDate)
        let base = todayDay < settings.startDay
            ? calendar.date(byAdding: .month, value: -1, to: baseDate) ?? baseDate
            : baseDate
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = settings.startDay
        return calendar.date(from: components) ?? baseDate
    }
    
    private var periodEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
    }
    
    private var periodDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let endDisplay = Calendar.current.date(byAdding: .day, value: -1, to: periodEnd) ?? periodEnd
        return "\(formatter.string(from: periodStart)) – \(formatter.string(from: endDisplay))"
    }
    
    // Actual spending/income since period start
    private var actualSinceStart: Double {
        let filtered = transactions.filter { transaction in
            transaction.date >= periodStart &&
            transaction.date < Date() &&
            transaction.type == selectedType.transactionType
        }
        return filtered.map(\.amount).reduce(0, +)
    }
    
    // Remaining planned payments in the period
    private var remainingPlanned: Double {
        let filtered = plannedPayments.filter { payment in
            payment.date >= Date() &&
            payment.date < periodEnd &&
            payment.status == .upcoming
        }
        return filtered.map(\.amount).reduce(0, +)
    }
    
    // Total money for the month (income - planned expenses)
    private var moneyForMonth: Double {
        if selectedType == .expenses {
            let totalIncome = transactions
                .filter { $0.type == .income && $0.date >= periodStart && $0.date < periodEnd }
                .map(\.amount)
                .reduce(0, +)
            let totalPlanned = plannedPayments
                .filter { $0.date >= periodStart && $0.date < periodEnd }
                .map(\.amount)
                .reduce(0, +)
            return totalIncome - totalPlanned
        } else {
            return transactions
                .filter { $0.type == .income && $0.date >= periodStart && $0.date < periodEnd }
                .map(\.amount)
                .reduce(0, +)
        }
    }
    
    // Chart data points - daily cumulative values
    private var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        var dataPoints: [ChartDataPoint] = []
        let today = Date()
        
        // Generate points for each day in the period (sample every 2-3 days for performance)
        var currentDate = periodStart
        var cumulativeActual: Double = 0
        var cumulativePlanned: Double = 0
        
        while currentDate < periodEnd {
            let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
            
            // Calculate actual up to this date
            let dayTransactions = transactions.filter { transaction in
                transaction.date >= periodStart &&
                transaction.date < dayEnd &&
                transaction.type == selectedType.transactionType
            }
            cumulativeActual = dayTransactions.map(\.amount).reduce(0, +)
            
            // Calculate planned up to this date
            let dayPlanned = plannedPayments.filter { payment in
                payment.date >= periodStart &&
                payment.date < dayEnd
            }
            cumulativePlanned = dayPlanned.map(\.amount).reduce(0, +)
            
            let isFuture = currentDate > today
            dataPoints.append(ChartDataPoint(
                date: currentDate,
                actual: cumulativeActual,
                planned: cumulativePlanned,
                isFuture: isFuture
            ))
            
            // Sample every 2 days for better performance
            guard let nextDate = calendar.date(byAdding: .day, value: 2, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        // Always include today and period end
        if !dataPoints.contains(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            let todayTransactions = transactions.filter { transaction in
                transaction.date >= periodStart &&
                transaction.date <= today &&
                transaction.type == selectedType.transactionType
            }
            let todayActual = todayTransactions.map(\.amount).reduce(0, +)
            let todayPlanned = plannedPayments.filter { $0.date >= periodStart && $0.date <= today }.map(\.amount).reduce(0, +)
            dataPoints.append(ChartDataPoint(date: today, actual: todayActual, planned: todayPlanned, isFuture: false))
        }
        
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with toggle and date range
                        headerSection
                        
                        // Metrics
                        metricsSection
                        
                        // Chart
                        chartSection
                        
                        // Bank connection prompt
                        if showBankConnectionPrompt {
                            bankConnectionPrompt
                        }
                        
                        // Summary cards
                        summarySection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showExpenseEditor) {
                expenseEditorSheet
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Segment control with circles
            HStack(spacing: 16) {
                ForEach(PlanType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedType = type
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(selectedType == type ? Color.white : Color.clear)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(selectedType == type ? Color.accentColor : Color.secondary.opacity(0.4))
                                    .frame(width: selectedType == type ? 10 : 6, height: selectedType == type ? 10 : 6)
                            }
                            Text(type.rawValue)
                                .font(.subheadline.weight(selectedType == type ? .semibold : .regular))
                                .foregroundStyle(selectedType == type ? .primary : .secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedType == type ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            
            // Date range with navigation
            HStack {
                Button {
                    withAnimation {
                        currentPeriodOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(periodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Button {
                    withAnimation {
                        currentPeriodOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var metricsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Since the beginning of the month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currencyString(actualSinceStart))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Still in plans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currencyString(remainingPlanned, code: settings.currency))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                let data = chartData.sorted { $0.date < $1.date }
                
                // Planned line - dashed green (always shown)
                ForEach(data) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Planned", point.planned)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                }
                
                // Actual line - solid white for past, dashed for future
                let pastData = data.filter { !$0.isFuture }
                ForEach(pastData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Actual", point.actual)
                    )
                    .foregroundStyle(Color.white)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                
                // Future actual line - dashed white (projection)
                let futureData = data.filter { $0.isFuture }
                if !futureData.isEmpty {
                    ForEach(futureData) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Actual", point.actual)
                        )
                        .foregroundStyle(Color.white)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                    }
                }
                
                // Red segment when actual exceeds planned (only for past dates)
                ForEach(pastData) { point in
                    if point.actual > point.planned && point.planned > 0 {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Overage", point.actual)
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatChartDate(date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatChartAmount(amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
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
    
    private var bankConnectionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect banks and upload transactions for several months to get a monthly forecast.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Button {
                        // Connect banks action
                    } label: {
                        Text("Connect banks")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                
                Button {
                    withAnimation {
                        showBankConnectionPrompt = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.customSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private var summarySection: some View {
        VStack(spacing: 12) {
            // Money for the month
            HStack {
                Text("Money for the month")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currencyString(moneyForMonth, code: settings.currency))
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
            // Expenses
            HStack {
                Text(selectedType == .expenses ? "Expenses" : "Income")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currencyString(actualSinceStart, code: settings.currency))
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Button {
                    editedExpenseAmount = actualSinceStart
                    showExpenseEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.customSecondaryBackground)
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var expenseEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount", value: $editedExpenseAmount, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit \(selectedType == .expenses ? "Expenses" : "Income")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExpenseEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save action - would update actual spending
                        showExpenseEditor = false
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    private func formatChartAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0f", amount / 1000) + "k"
        }
        return String(format: "%.0f", amount)
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let actual: Double
    let planned: Double
    let isFuture: Bool
}

