//
//  TimelinePoint.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct TimelinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let planned: Double
    let actual: Double
    let note: String?
    
    static let sample: [TimelinePoint] = {
        let calendar = Calendar.current
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        }
        return [
            .init(date: day(25), planned: 400, actual: 420, note: nil),
            .init(date: day(22), planned: 800, actual: 780, note: "Transfer to Savings"),
            .init(date: day(18), planned: 1200, actual: 1180, note: nil),
            .init(date: day(15), planned: 1600, actual: 1500, note: "Paid Credit Card"),
            .init(date: day(10), planned: 2000, actual: 2100, note: nil),
            .init(date: day(7), planned: 2400, actual: 2380, note: nil),
            .init(date: day(4), planned: 2800, actual: 2760, note: "Transfer to Cash"),
            .init(date: day(1), planned: 3200, actual: 3150, note: nil)
        ]
    }()
}

