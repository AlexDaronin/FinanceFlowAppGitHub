//
//  SpendingProjectionChart.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts

struct SpendingProjectionChart: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var debtManager: DebtManager
    
    let transactions: [Transaction]
    
    @State private var selectedDate: Date?
    @State private var cachedChartData: [ChartDataService.ChartDataPoint] = []
    @State private var lastTransactionCount: Int = 0
    @State private var lastStartDay: Int = 0
    @State private var lastDebtTransactionCount: Int = 0
    
    // MARK: - Computed Properties
    
    /// Period for the chart based on financial month
    private var period: (start: Date, end: Date) {
        DateRangeHelper.currentPeriod(for: settings.startDay)
    }
    
    /// Chart data calculated by ChartDataService (использует кэш)
    private var chartData: [ChartDataService.ChartDataPoint] {
        cachedChartData
    }
    
    // Функция для обновления кэша графика
    private func updateChartCache() {
        let transactionsChanged = lastTransactionCount != transactions.count
        let startDayChanged = lastStartDay != settings.startDay
        let debtChanged = lastDebtTransactionCount != debtManager.transactions.count
        
        guard transactionsChanged || startDayChanged || debtChanged else { return }
        
        let confirmedTransactions = ChartDataService.filterConfirmedTransactions(transactions)
        let configuration = ChartDataService.Configuration.currentPeriod(
            startDay: settings.startDay,
            debtTransactions: debtManager.transactions
        )
        cachedChartData = ChartDataService.calculateChartData(
            from: confirmedTransactions,
            configuration: configuration
        )
        
        lastTransactionCount = transactions.count
        lastStartDay = settings.startDay
        lastDebtTransactionCount = debtManager.transactions.count
    }
    
    /// Get values for selected date
    private var selectedDateData: ChartDataService.ChartDataPoint? {
        guard let selectedDate = selectedDate else { return nil }
        let calendar = Calendar.current
        let period = self.period
        
        // Ensure selected date is within the period
        guard selectedDate >= period.start && selectedDate < period.end else {
            return nil
        }
        
        return chartData.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top header with navigation and summary
            headerView
            
            // Chart area
            chartView
                .frame(height: 280)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            // Bottom footer with balance
            footerView
        }
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        // Убрана тяжёлая тень для улучшения производительности
        // .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
        .onAppear {
            updateChartCache()
        }
        .onChange(of: transactions.count) { oldValue, newValue in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                updateChartCache()
            }
        }
        .onChange(of: settings.startDay) { oldValue, newValue in
            updateChartCache()
        }
        .onChange(of: debtManager.transactions.count) { oldValue, newValue in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                updateChartCache()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Navigation arrows and period title
            HStack {
                Button(action: {
                    // Navigate to previous period
                    // This could be implemented if needed
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .opacity(0.5) // Disabled for now
                
                Spacer()
                
                if let selectedDate = selectedDate {
                    Text(formatShortDate(selectedDate))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text(formatShortDate(period.start))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    // Navigate to next period
                    // This could be implemented if needed
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .opacity(0.5) // Disabled for now
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Income and Expenses summary
            HStack(spacing: 20) {
                // Income (left, green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Поступления", comment: "Income label"))
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(currencyString(
                        selectedDateData?.cumulativeIncome ?? chartData.last?.cumulativeIncome ?? 0,
                        code: settings.currency
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Expenses (right, white/gray)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "Расходы", comment: "Expenses label"))
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.7))
                    Text(currencyString(
                        selectedDateData?.cumulativeExpenses ?? chartData.last?.cumulativeExpenses ?? 0,
                        code: settings.currency
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        let data = chartData
        let calendar = Calendar.current
        
        // Show empty state if no data
        if data.isEmpty {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(String(localized: "No spending data available", comment: "No spending data message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            )
        }
        
        return AnyView(Chart {
            // Income line (green, dashed)
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Income", point.cumulativeIncome)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.linear) // Более лёгкая интерполяция для производительности
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            
            // Expenses line (gray/light, dashed)
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Expenses", point.cumulativeExpenses)
                )
                .foregroundStyle(.primary.opacity(0.6))
                .interpolationMethod(.linear) // Более лёгкая интерполяция для производительности
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            
            // Vertical dashed line at selected date
            if let selectedDate = selectedDate {
                RuleMark(x: .value("Selected", selectedDate, unit: .day))
                    .foregroundStyle(.primary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .center) {
                        // Date label with X button
                        HStack(spacing: 4) {
                            Text(formatShortDate(selectedDate))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.primary)
                            Button(action: {
                                withAnimation {
                                    self.selectedDate = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.customCardBackground)
                        .clipShape(Capsule())
                    }
                
                // Points on lines at selected date
                if let selectedData = selectedDateData {
                    PointMark(
                        x: .value("Date", selectedDate, unit: .day),
                        y: .value("Income", selectedData.cumulativeIncome)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(40)
                    
                    PointMark(
                        x: .value("Date", selectedDate, unit: .day),
                        y: .value("Expenses", selectedData.cumulativeExpenses)
                    )
                    .foregroundStyle(.primary.opacity(0.7))
                    .symbolSize(40)
                }
            }
        }
        .chartXAxis {
            let endDate = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 4))) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(0.1))
                
                if let date = value.as(Date.self) {
                    let isStart = calendar.isDate(date, inSameDayAs: period.start)
                    let isEnd = calendar.isDate(date, inSameDayAs: endDate)
                    
                    if isStart || isEnd {
                        AxisValueLabel {
                            if isStart {
                                Text(formatShortDate(date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(formatPeriodEndDate(date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(0.1))
                if let amount = value.as(Double.self), amount > 0 {
                    AxisValueLabel {
                        Text(formatChartAmount(amount))
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartXScale(domain: .automatic)
        .chartBackground { chartProxy in
            // Упрощённый вариант без GeometryReader для лучшей производительности
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Упрощённый расчёт без GeometryReader
                            // Используем приблизительный расчёт на основе данных
                            if !data.isEmpty {
                                let ratio = min(max(value.location.x / 300.0, 0.0), 1.0) // Приблизительная ширина графика
                                let index = Int(ratio * Double(data.count - 1))
                                let clampedIndex = max(0, min(index, data.count - 1))
                                
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = data[clampedIndex].date
                                }
                            }
                        }
                )
        }
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    // Swipe left/right to navigate days
                    let horizontalMovement = value.translation.width
                    let swipeThreshold: CGFloat = 30
                    
                    if abs(horizontalMovement) > swipeThreshold {
                        let calendar = Calendar.current
                        let period = self.period
                        let dayChange = horizontalMovement > 0 ? -1 : 1
                        
                        // If no date is selected, start from the last data point or today
                        let baseDate: Date
                        if let currentSelected = selectedDate {
                            baseDate = currentSelected
                        } else if let lastData = chartData.last {
                            baseDate = lastData.date
                        } else {
                            baseDate = Date()
                        }
                        
                        if let newDate = calendar.date(byAdding: .day, value: dayChange, to: baseDate) {
                            if newDate >= period.start && newDate < period.end {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = newDate
                                }
                            }
                        }
                    }
                }
        )
        )
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            // Balance icon and label
            HStack(spacing: 6) {
                Image(systemName: "scalemass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                if let selectedDate = selectedDate {
                    Text(String(localized: "Баланс на", comment: "Balance on") + " \(formatShortDate(selectedDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "Баланс", comment: "Balance"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Balance amount
            if let selectedData = selectedDateData {
                let balance = selectedData.balance
                Text(currencyString(balance, code: settings.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            } else if let lastData = chartData.last {
                let balance = lastData.balance
                Text(currencyString(balance, code: settings.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Formatting Helpers
    
    /// Format date for display (e.g., "22 дек")
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    /// Format period end date (e.g., "17 янв 2026")
    private func formatPeriodEndDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Format chart amount for Y-axis
    private func formatChartAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0f", amount / 1000) + "k"
        } else {
            return String(format: "%.0f", amount)
        }
    }
}
