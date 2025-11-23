//
//  User.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct User {
    let id: String
    let email: String
    let name: String
    let provider: AuthProvider
}

enum AuthProvider: String {
    case email
    case google
    case apple
}

