//
//  CategoryIconLibrary.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct CategoryIconLibrary {
    // Large library for transaction categories - comprehensive set of minimalistic icons
    static let transactionIcons: [String] = [
        // Food & Dining
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill", "birthday.cake.fill", "cart.fill", "tray.fill",
        "fish.fill", "leaf.fill", "carrot.fill", "apple.fill", "pizza.fill",
        "birthday.cake", "cup.and.saucer", "takeoutbag.and.cup.and.straw",
        
        // Drinks & Snacks
        "drop.fill", "drop", "cup.fill", "mug.fill", "mug", "bubbles.and.sparkles.fill",
        "candybar", "popcorn.fill", "popcorn",
        
        // Restaurants & Dining Out
        "fork.knife.circle.fill", "fork.knife.circle", "building.2.fill",
        "storefront.fill", "storefront", "building.2",
        
        // Home & Living
        "house.fill", "house", "lightbulb.fill", "lightbulb", "flame.fill", "flame",
        "drop.fill", "drop", "wifi", "wifi.slash", "antenna.radiowaves.left.and.right",
        "tv.fill", "tv", "sofa.fill", "bed.double.fill", "bed.double",
        "shower.fill", "shower", "door.left.hand.open", "door.right.hand.open",
        "key.fill", "key", "lock.fill", "lock", "lock.shield.fill",
        
        // Bills & Utilities
        "bolt.fill", "bolt", "bolt.circle.fill", "bolt.circle",
        "antenna.radiowaves.left.and.right", "antenna.radiowaves.left.and.right.circle.fill",
        "phone.fill", "phone", "envelope.fill", "envelope", "doc.text.fill", "doc.text",
        "doc.fill", "doc", "paperclip", "paperclip.circle.fill",
        
        // Transport
        "car.fill", "car", "bus.fill", "bus", "tram.fill", "tram",
        "bicycle", "airplane", "airplane.departure", "airplane.arrival",
        "fuelpump.fill", "fuelpump", "parkingsign.circle.fill", "parkingsign.circle",
        "map.fill", "map", "location.fill", "location", "mappin.circle.fill",
        "figure.walk", "figure.run", "scooter",
        
        // Health & Fitness
        "heart.fill", "heart", "cross.case.fill", "cross.case",
        "pills.fill", "pills", "bandage.fill", "bandage",
        "figure.run", "figure.walk", "dumbbell.fill", "dumbbell",
        "figure.strengthtraining.traditional", "figure.yoga", "figure.pool.swim",
        "stethoscope", "medical.thermometer.fill", "medical.thermometer",
        
        // Shopping & Retail
        "bag.fill", "bag", "cart.fill", "cart", "tag.fill", "tag",
        "gift.fill", "gift", "tshirt.fill", "tshirt", "eyeglasses",
        "watch.fill", "watch", "iphone", "ipad", "laptopcomputer",
        "headphones", "speaker.wave.2.fill", "speaker.wave.2",
        
        // Entertainment
        "tv.fill", "tv", "music.note", "music.note.list", "music.mic",
        "gamecontroller.fill", "gamecontroller", "film.fill", "film",
        "camera.fill", "camera", "photo.fill", "photo", "video.fill", "video",
        "theatermasks.fill", "theatermasks", "paintbrush.fill", "paintbrush",
        "paintpalette.fill", "paintpalette",
        
        // Sport & Recreation
        "figure.run", "figure.walk", "figure.bike", "figure.skiing.downhill",
        "figure.skating", "sportscourt.fill", "sportscourt",
        "figure.tennis", "figure.badminton", "figure.soccer",
        
        // Education
        "book.fill", "book", "graduationcap.fill", "graduationcap",
        "pencil", "pencil.and.outline", "pencil.circle.fill", "pencil.circle",
        "studentdesk", "laptopcomputer", "ipad", "macbook",
        "backpack.fill", "backpack", "book.closed.fill", "book.closed",
        
        // Travel
        "airplane", "airplane.departure", "airplane.arrival",
        "bed.double.fill", "bed.double", "map.fill", "map",
        "suitcase.fill", "suitcase", "camera.fill", "camera",
        "beach.umbrella.fill", "beach.umbrella", "mountain.2.fill", "mountain.2",
        "sailboat.fill", "sailboat", "ferry.fill", "ferry",
        "tent.fill", "tent", "globe", "globe.europe.africa.fill",
        
        // Financial & Investments
        "dollarsign.circle.fill", "dollarsign.circle", "creditcard.fill", "creditcard",
        "banknote.fill", "banknote", "chart.line.uptrend.xyaxis",
        "chart.pie.fill", "chart.pie", "building.columns.fill", "building.columns",
        "chart.bar.fill", "chart.bar", "chart.xyaxis.line",
        "bitcoinsign.circle.fill", "bitcoinsign.circle",
        
        // Income
        "arrow.down.circle.fill", "arrow.down.circle", "briefcase.fill", "briefcase",
        "person.fill", "person", "person.2.fill", "person.2",
        "building.2.fill", "building.2", "hand.raised.fill", "hand.raised",
        "person.crop.circle.fill", "person.crop.circle",
        
        // Subscriptions & Services
        "star.fill", "star", "music.note.tv", "play.rectangle.fill", "play.rectangle",
        "app.badge.fill", "app.badge", "cloud.fill", "cloud", "icloud.fill", "icloud",
        "play.circle.fill", "play.circle", "pause.circle.fill", "pause.circle",
        "arrow.triangle.2.circlepath", "arrow.clockwise",
        
        // Gifts & Donations
        "gift.fill", "gift", "heart.circle.fill", "heart.circle",
        "hand.raised.fill", "hand.raised", "star.circle.fill", "star.circle",
        "sparkles", "sparkle", "crown.fill", "crown",
        
        // Pets
        "pawprint.fill", "pawprint", "dog.fill", "cat.fill",
        "fish.fill", "bird.fill",
        
        // Personal Care
        "scissors", "comb.fill", "sparkles.tv.fill", "sparkles.tv",
        "face.smiling.fill", "face.smiling",
        
        // Insurance & Legal
        "shield.fill", "shield", "doc.text.magnifyingglass",
        "scale.3d", "gavel.fill", "gavel",
        
        // General & Other
        "ellipsis.circle.fill", "ellipsis.circle", "questionmark.circle.fill",
        "questionmark.circle", "exclamationmark.circle.fill", "exclamationmark.circle",
        "checkmark.circle.fill", "checkmark.circle", "xmark.circle.fill", "xmark.circle",
        "plus.circle.fill", "plus.circle", "minus.circle.fill", "minus.circle",
        "arrow.left.arrow.right", "arrow.up.arrow.down",
        "arrow.triangle.2.circlepath", "repeat", "arrow.clockwise",
        "circle.fill", "circle", "square.fill", "square"
    ]
    
    // Small library for account types - compact set of account icons
    static let accountIcons: [String] = [
        "wallet.pass.fill",           // Wallet
        "wallet.pass",                // Wallet (outline)
        "creditcard.fill",            // Card
        "creditcard",                 // Card (outline)
        "building.columns.fill",      // Bank
        "building.columns",           // Bank (outline)
        "banknote.fill",              // Cash
        "banknote",                   // Cash (outline)
        "lock.fill",                  // Safe
        "lock",                       // Safe (outline)
        "lock.shield.fill",           // Secure safe
        "dollarsign.circle.fill",     // Savings
        "dollarsign.circle",          // Savings (outline)
        "chart.line.uptrend.xyaxis",  // Deposit/Investment
        "chart.pie.fill",             // Investment account
        "chart.pie",                  // Investment account (outline)
        "chart.bar.fill",             // Investment tracking
        "bitcoinsign.circle.fill",    // Crypto wallet
        "bitcoinsign.circle"          // Crypto wallet (outline)
    ]
    
    static func iconName(for accountType: AccountType) -> String {
        switch accountType {
        case .cash:
            return "banknote.fill"
        case .card:
            return "creditcard.fill"
        case .bankAccount:
            return "building.columns.fill"
        }
    }
}

