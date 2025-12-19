//
//  ChartHelpers.swift
//  FinanceFlow
//
//  Created for consistent chart styling and utilities
//

import SwiftUI
import Charts

// MARK: - Chart Style Configuration

struct ChartStyle {
    static let defaultHeight: CGFloat = 180
    static let largeHeight: CGFloat = 240
    static let smallHeight: CGFloat = 80
    static let compactHeight: CGFloat = 140
    
    static let defaultCornerRadius: CGFloat = 16
    static let defaultPadding: CGFloat = 20
    
    // Minimalistic styling
    static let gridLineOpacity: Double = 0.08
    static let axisLabelOpacity: Double = 0.5
    static let chartBackgroundOpacity: Double = 0.03
    
    // Clean color palette
    static let primaryChartColor = Color.blue
    static let incomeColor = Color.green.opacity(0.8)
    static let expenseColor = Color.red.opacity(0.8)
    static let netColor = Color.blue.opacity(0.8)
}

// MARK: - Chart Axis Configuration

extension View {
    /// Standard X-axis configuration for date-based charts
    func standardDateXAxis(
        strideCount: Int = 5,
        formatter: @escaping (Date) -> String = { date in
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    ) -> some View {
        self.chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatter(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    /// Standard Y-axis configuration for amount-based charts
    func standardAmountYAxis(
        formatter: @escaping (Double) -> String = { amount in
            if amount >= 1000 {
                return String(format: "%.0fk", amount / 1000)
            } else if amount >= 100 {
                return String(format: "%.0f", amount)
            } else {
                return String(format: "%.0f", amount)
            }
        },
        useLeadingPosition: Bool = false
    ) -> some View {
        self.chartYAxis {
            if useLeadingPosition {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                    if let amount = value.as(Double.self), amount > 0 {
                        AxisValueLabel {
                            Text(formatter(amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                        }
                    }
                }
            } else {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(ChartStyle.gridLineOpacity))
                    if let amount = value.as(Double.self), amount > 0 {
                        AxisValueLabel {
                            Text(formatter(amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(ChartStyle.axisLabelOpacity))
                        }
                    }
                }
            }
        }
    }
    
    /// Standard chart container styling - minimalistic
    func chartContainer() -> some View {
        self
            .padding(ChartStyle.defaultPadding)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ChartStyle.defaultCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ChartStyle.defaultCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: Color.primary.opacity(0.03), radius: 8, x: 0, y: 2)
    }
    
    /// Minimalistic chart container with tap gesture
    func clickableChartContainer(onTap: @escaping () -> Void) -> some View {
        self
            .padding(ChartStyle.defaultPadding)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ChartStyle.defaultCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ChartStyle.defaultCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: Color.primary.opacity(0.03), radius: 8, x: 0, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Chart Data Point Protocols

/// Protocol for chart data points that can be used with Swift Charts
protocol ChartDataPointProtocol: Identifiable {
    var date: Date { get }
    var value: Double { get }
}

// MARK: - Common Chart Mark Styles

struct ChartMarkStyles {
    /// Standard line mark style for actual data
    static func actualLine() -> some View {
        EmptyView()
    }
    
    /// Standard line mark style for projected/forecasted data
    static func projectedLine() -> some View {
        EmptyView()
    }
    
    /// Standard line mark style for planned data
    static func plannedLine() -> some View {
        EmptyView()
    }
}

// MARK: - Chart Formatting Helpers

struct ChartFormatters {
    /// Format date for chart axis labels
    static func formatChartDate(_ date: Date, format: String = "d MMM") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    /// Format amount for chart axis labels
    static func formatChartAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0fk", amount / 1000)
        } else if amount >= 100 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    /// Format percentage for chart labels
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
}

// MARK: - Reusable Chart Components

/// Standard line chart with date on X-axis and amount on Y-axis
struct StandardLineChart<Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    let data: Data
    let xValue: (Data.Element) -> Date
    let yValue: (Data.Element) -> Double
    let color: Color
    let lineWidth: CGFloat
    let isDashed: Bool
    let interpolationMethod: InterpolationMethod
    
    init(
        data: Data,
        xValue: @escaping (Data.Element) -> Date,
        yValue: @escaping (Data.Element) -> Double,
        color: Color = .primary,
        lineWidth: CGFloat = 2.5,
        isDashed: Bool = false,
        interpolationMethod: InterpolationMethod = .catmullRom
    ) {
        self.data = data
        self.xValue = xValue
        self.yValue = yValue
        self.color = color
        self.lineWidth = lineWidth
        self.isDashed = isDashed
        self.interpolationMethod = interpolationMethod
    }
    
    var body: some View {
        Chart {
            ForEach(data) { item in
                LineMark(
                    x: .value("Date", xValue(item), unit: .day),
                    y: .value("Value", yValue(item))
                )
                .foregroundStyle(color)
                .interpolationMethod(interpolationMethod)
                .lineStyle(StrokeStyle(
                    lineWidth: lineWidth,
                    dash: isDashed ? [5, 5] : []
                ))
            }
        }
    }
}

/// Standard bar chart with date on X-axis and amount on Y-axis
struct StandardBarChart<Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    let data: Data
    let xValue: (Data.Element) -> Date
    let yValue: (Data.Element) -> Double
    let color: Color
    
    init(
        data: Data,
        xValue: @escaping (Data.Element) -> Date,
        yValue: @escaping (Data.Element) -> Double,
        color: Color = .blue
    ) {
        self.data = data
        self.xValue = xValue
        self.yValue = yValue
        self.color = color
    }
    
    var body: some View {
        Chart {
            ForEach(data) { item in
                BarMark(
                    x: .value("Date", xValue(item), unit: .day),
                    y: .value("Value", yValue(item))
                )
                .foregroundStyle(color)
            }
        }
    }
}

/// Standard donut/pie chart for category breakdowns
struct StandardDonutChart<Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    let data: Data
    let value: (Data.Element) -> Double
    let color: (Data.Element) -> Color
    let innerRadius: CGFloat
    let angularInset: CGFloat
    
    init(
        data: Data,
        value: @escaping (Data.Element) -> Double,
        color: @escaping (Data.Element) -> Color,
        innerRadius: CGFloat = 0.6,
        angularInset: CGFloat = 2
    ) {
        self.data = data
        self.value = value
        self.color = color
        self.innerRadius = innerRadius
        self.angularInset = angularInset
    }
    
    var body: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value("Amount", value(item)),
                innerRadius: .ratio(innerRadius),
                angularInset: angularInset
            )
            .foregroundStyle(color(item))
        }
    }
}

// MARK: - Chart Empty State

struct ChartEmptyState: View {
    let icon: String
    let message: String
    let height: CGFloat
    
    init(
        icon: String = "chart.line.uptrend.xyaxis",
        message: String = "No data available",
        height: CGFloat = 200
    ) {
        self.icon = icon
        self.message = message
        self.height = height
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
