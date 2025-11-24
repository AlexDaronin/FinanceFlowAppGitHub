//
//  StatisticsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var summaries = MonthlySummary.sample
    @State private var categorySpending = CategorySpending.sample
    @State private var selectedRange: RangePreset = .threeMonths
    
    private var filteredSummaries: [MonthlySummary] {
        switch selectedRange {
        case .threeMonths:
            return Array(summaries.prefix(3))
        case .sixMonths:
            return Array(summaries.prefix(6))
        case .year:
            return summaries
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    rangeSelector
                    incomeExpenseChart
                    plannedActualCard
                    categoryBreakdown
                }
                .padding()
            }
            .background(Color.customBackground)
            .navigationTitle(Text("Statistics", comment: "Statistics view title"))
        }
    }
    
    private var rangeSelector: some View {
        HStack {
            Text("Overview", comment: "Overview label")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Spacer()
            Picker("Range", selection: $selectedRange) {
                ForEach(RangePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var incomeExpenseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expense", comment: "Income vs expense chart title")
                .font(.headline)
                .foregroundStyle(.primary)
            Chart {
                ForEach(filteredSummaries) { summary in
                    BarMark(
                        x: .value("Month", summary.month),
                        y: .value("Income", summary.income)
                    )
                    .foregroundStyle(Color.green.gradient)
                    
                    BarMark(
                        x: .value("Month", summary.month),
                        y: .value("Expense", -summary.expense)
                    )
                    .foregroundStyle(Color.red.gradient)
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.primary.opacity(0.1), radius: 12, x: 0, y: 4)
    }
    
    private var plannedActualCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Planned vs Actual Spending", comment: "Planned vs actual chart title")
                .font(.headline)
                .foregroundStyle(.primary)
            Chart {
                ForEach(filteredSummaries) { summary in
                    LineMark(
                        x: .value("Month", summary.month),
                        y: .value("Planned", summary.planned)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                    
                    LineMark(
                        x: .value("Month", summary.month),
                        y: .value("Actual", summary.expense)
                    )
                    .foregroundStyle(Color.white)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .frame(height: 220)
            .chartYScale(domain: .automatic(includesZero: true))
        }
        .padding()
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.primary.opacity(0.1), radius: 12, x: 0, y: 4)
    }
    
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown", comment: "Category breakdown chart title")
                .font(.headline)
                .foregroundStyle(.primary)
            Chart(categorySpending) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Category", item.name))
            }
            .frame(height: 260)
            .chartLegend(.visible)
        }
        .padding()
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.primary.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

