//
//  Chat.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
        
        var title: String {
            switch self {
            case .user: return "You"
            case .assistant: return "AI"
            }
        }
    }
    
    let id = UUID()
    let role: Role
    let text: String
    let date: Date
    
    static let sample: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi Alex! I looked at your last week. Food is up 18%. Maybe shift some delivery meals to home cooking?", date: Date()),
        ChatMessage(role: .user, text: "Should I pay my card today or keep cash for rent?", date: Date()),
        ChatMessage(role: .assistant, text: "Rent is due in 5 days and you already set that money aside. Consider paying the card now to avoid interest.", date: Date())
    ]
}

