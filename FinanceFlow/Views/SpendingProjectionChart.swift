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
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    let transactions: [Transaction]
    
    // Chart data points
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let actual: Double
        let projected: Double?
        let previousMonth: Double?
    }
    
    private var period: (start: Date, end: Date) {
        DateRangeHelper.currentPeriod(for: settings.startDay)
    }
    
    private var previousPeriod: (start: Date, end: Date) {
        DateRangeHelper.period(for: settings.startDay, offset: -1)
    }
    
    private var today: Date {
        Date()
    }
    
    // Calculate daily cumulative actual spending
    // FIX 1: Iterate through EVERY day from start to today, carrying over values
    private var actualSpendingData: [ChartDataPoint] {
        let calendar = Calendar.current
        let period = self.period
        let today = self.today
        var dataPoints: [ChartDataPoint] = []
        var cumulativeSpending: Double = 0
        
        // Start from the first day of the period
        var currentDate = calendar.startOfDay(for: period.start)
        let todayStart = calendar.startOfDay(for: today)
        
        // Iterate through EVERY single day from period start to today
        while currentDate <= todayStart && currentDate < period.end {
            let dayStart = currentDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            // Sum all expense transactions for this specific day
            let dayTransactions = transactions.filter { transaction in
                transaction.type == .expense &&
                transaction.date >= dayStart &&
                transaction.date < dayEnd
            }
            
            // Add day's transactions to cumulative total
            // If no transactions, cumulativeSpending carries over (doesn't drop to zero)
            cumulativeSpending += dayTransactions.map(\.amount).reduce(0, +)
            
            dataPoints.append(ChartDataPoint(
                date: currentDate,
                actual: cumulativeSpending,
                projected: nil,
                previousMonth: nil
            ))
            
            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dataPoints
    }
    
    // Calculate projected spending (from today to end of period)
    // FIX 2: Projected must START with exact same value and date as last actual point
    private var projectedSpendingData: [ChartDataPoint] {
        let calendar = Calendar.current
        let period = self.period
        let today = self.today
        var dataPoints: [ChartDataPoint] = []
        
        // Get the LAST actual data point - this is our starting point
        guard let lastActualPoint = actualSpendingData.last else {
            // If no actual data, start from zero
            return []
        }
        
        let lastActualDate = lastActualPoint.date
        let lastActualValue = lastActualPoint.actual
        
        // Calculate average daily burn rate from past transactions (excluding planned payments)
        let daysElapsed = max(1, calendar.dateComponents([.day], from: period.start, to: today).day ?? 1)
        
        // Get past planned payments that were already paid
        let pastPlannedPayments = subscriptionManager.subscriptions.filter { subscription in
            !subscription.isIncome &&
            subscription.date >= period.start &&
            subscription.date <= today
        }
        let pastPlannedTotal = pastPlannedPayments.map(\.amount).reduce(0, +)
        
        // Variable spending = total actual - planned payments already paid
        let variableSpending = max(0, lastActualValue - pastPlannedTotal)
        let averageDailyBurn = variableSpending / Double(daysElapsed)
        
        // Get future planned payments (subscriptions/loans) in this period
        let futurePlannedPayments = subscriptionManager.subscriptions.filter { subscription in
            !subscription.isIncome &&
            subscription.status == .upcoming &&
            subscription.date > today &&
            subscription.date < period.end
        }
        
        // Group planned payments by day
        var plannedByDay: [Date: Double] = [:]
        for payment in futurePlannedPayments {
            let day = calendar.startOfDay(for: payment.date)
            plannedByDay[day, default: 0] += payment.amount
        }
        
        // CRITICAL FIX 2: Start projected line from the EXACT same point as actual line ends
        // This creates seamless connection
        dataPoints.append(ChartDataPoint(
            date: lastActualDate,
            actual: 0, // Not used in projected line
            projected: lastActualValue, // Same value as last actual point
            previousMonth: nil
        ))
        
        // Calculate projected spending day by day from tomorrow onwards
        var projectedTotal = lastActualValue
        var currentDate = calendar.date(byAdding: .day, value: 1, to: lastActualDate) ?? lastActualDate
        
        while currentDate < period.end {
            // Add planned payment for this day if any
            if let plannedAmount = plannedByDay[currentDate] {
                projectedTotal += plannedAmount
            }
            
            // Add average daily burn for variable costs (food, entertainment, etc.)
            projectedTotal += averageDailyBurn
            
            dataPoints.append(ChartDataPoint(
                date: currentDate,
                actual: 0, // Not used for projected
                projected: projectedTotal,
                previousMonth: nil
            ))
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dataPoints
    }
    
    // Calculate previous month's spending curve
    private var previousMonthData: [ChartDataPoint] {
        let calendar = Calendar.current
        let previousPeriod = self.previousPeriod
        var dataPoints: [ChartDataPoint] = []
        var cumulativeSpending: Double = 0
        
        // Sample every 2-3 days for performance, but ensure we have key points
        var currentDate = previousPeriod.start
        var dayCount = 0
        
        while currentDate < previousPeriod.end {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            // Sum all expense transactions for this day in previous period
            let dayTransactions = transactions.filter { transaction in
                transaction.type == .expense &&
                transaction.date >= dayStart &&
                transaction.date < dayEnd
            }
            
            cumulativeSpending += dayTransactions.map(\.amount).reduce(0, +)
            
            // Map to current period date for comparison (same day of month)
            let daysFromStart = calendar.dateComponents([.day], from: previousPeriod.start, to: currentDate).day ?? 0
            if let mappedDate = calendar.date(byAdding: .day, value: daysFromStart, to: period.start) {
                // Only add point if it's within current period
                if mappedDate < period.end {
                    dataPoints.append(ChartDataPoint(
                        date: mappedDate,
                        actual: 0, // Not used
                        projected: nil,
                        previousMonth: cumulativeSpending
                    ))
                }
            }
            
            // Sample every 2 days for performance
            dayCount += 1
            guard let nextDate = calendar.date(byAdding: .day, value: 2, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        // Always include the last day of previous period
        if let lastDay = calendar.date(byAdding: .day, value: -1, to: previousPeriod.end) {
            let dayStart = calendar.startOfDay(for: lastDay)
            let dayEnd = previousPeriod.end
            
            let dayTransactions = transactions.filter { transaction in
                transaction.type == .expense &&
                transaction.date >= dayStart &&
                transaction.date < dayEnd
            }
            
            cumulativeSpending += dayTransactions.map(\.amount).reduce(0, +)
            
            let daysFromStart = calendar.dateComponents([.day], from: previousPeriod.start, to: lastDay).day ?? 0
            if let mappedDate = calendar.date(byAdding: .day, value: daysFromStart, to: period.start),
               mappedDate < period.end {
                dataPoints.append(ChartDataPoint(
                    date: mappedDate,
                    actual: 0,
                    projected: nil,
                    previousMonth: cumulativeSpending
                ))
            }
        }
        
        return dataPoints
    }
    
    // Combined chart data
    // Ensures seamless connection between actual and projected lines
    private var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        
        // Combine actual and projected data
        let actual = actualSpendingData
        let projected = projectedSpendingData
        let previous = previousMonthData
        
        // Create a dictionary for quick lookup by day
        var dataMap: [Date: ChartDataPoint] = [:]
        
        // Add actual data - these are the solid line points
        for point in actual {
            let day = calendar.startOfDay(for: point.date)
            dataMap[day] = ChartDataPoint(
                date: point.date,
                actual: point.actual,
                projected: nil,
                previousMonth: nil
            )
        }
        
        // Add projected data - merge with actual if same day (for connection point)
        for point in projected {
            let day = calendar.startOfDay(for: point.date)
            if let existing = dataMap[day] {
                // Merge: keep actual value, add projected value
                // This creates the connection point where both lines meet
                dataMap[day] = ChartDataPoint(
                    date: existing.date,
                    actual: existing.actual, // Keep actual value
                    projected: point.projected, // Add projected value
                    previousMonth: existing.previousMonth
                )
            } else {
                // Future date with only projected value
                dataMap[day] = point
            }
        }
        
        // Add previous month data for comparison
        for point in previous {
            let day = calendar.startOfDay(for: point.date)
            if let existing = dataMap[day] {
                dataMap[day] = ChartDataPoint(
                    date: existing.date,
                    actual: existing.actual,
                    projected: existing.projected,
                    previousMonth: point.previousMonth
                )
            } else {
                dataMap[day] = point
            }
        }
        
        // Convert to sorted array - ensures chronological order
        return Array(dataMap.values).sorted { $0.date < $1.date }
    }
    
    // Check if spending is on track (warning indicator)
    private var isOverBudget: Bool {
        guard let lastProjected = chartData.filter({ $0.projected != nil }).last?.projected,
              let lastPrevious = chartData.filter({ $0.previousMonth != nil }).last?.previousMonth else {
            return false
        }
        return lastProjected > lastPrevious * 1.1 // 10% over previous month
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            chartView
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    private var headerSection: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Spending Projection")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isOverBudget {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(formatPeriodDescription())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
    }
    
    private var sortedChartData: [ChartDataPoint] {
        chartData.sorted { $0.date < $1.date }
    }
    
    private var chartView: some View {
        let data = sortedChartData
        let today = self.today
        let previousData = data.filter { $0.previousMonth != nil }
        
        // Actual data: all points with actual > 0 up to and including today
        let actualData = data.filter { $0.actual > 0 && $0.date <= today }
        
        // Projected data: all points with projected value, starting from today
        // This includes the connection point (today) which has both actual and projected
        let projectedData = data.filter { $0.projected != nil && $0.date >= today }
        
        return Chart {
            // Previous month comparison line (gray/green, low opacity)
            ForEach(previousData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Previous Month", point.previousMonth ?? 0)
                    )
                    .foregroundStyle(Color.green.opacity(0.3))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
            // Actual spending line (solid, primary color)
                ForEach(actualData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Actual", point.actual)
                    )
                .foregroundStyle(Color.primary)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                
            // Projected spending line (dashed, secondary color with opacity)
            // FIX 3: Clean LineMarks only, no AreaMark
                ForEach(projectedData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Projected", point.projected ?? 0)
                    )
                .foregroundStyle(Color.secondary.opacity(0.8))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                let calendar = Calendar.current
                let endDate = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
            let dayCount = calendar.dateComponents([.day], from: period.start, to: period.end).day ?? 30
            let strideCount = max(1, dayCount / 4)
                
            AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    if let date = value.as(Date.self) {
                        let isStart = calendar.isDate(date, inSameDayAs: period.start)
                        let isToday = calendar.isDate(date, inSameDayAs: today)
                        let isEnd = calendar.isDate(date, inSameDayAs: endDate)
                        
                        if isStart || isToday || isEnd {
                            AxisValueLabel {
                                VStack(spacing: 2) {
                                    if isStart {
                                        Text("Start")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    } else if isToday {
                                        Text("Today")
                                            .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                    } else if isEnd {
                                        Text("End")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(formatChartDate(date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            AxisValueLabel {
                                Text(formatChartDate(date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.15))
                    if let amount = value.as(Double.self), amount > 0 {
                        AxisValueLabel {
                            Text(formatChartAmount(amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
    }
    
    private func formatPeriodDescription() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDisplay = Calendar.current.date(byAdding: .day, value: -1, to: period.end) ?? period.end
        return "\(formatter.string(from: period.start)) – \(formatter.string(from: endDisplay))"
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    private func formatChartAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0fk", amount / 1000)
        }
        return String(format: "%.0f", amount)
    }
}

