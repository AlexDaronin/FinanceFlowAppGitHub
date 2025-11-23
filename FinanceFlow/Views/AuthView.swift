//
//  AuthView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo and title
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("FinanceFlow")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text(isLoginMode ? "Welcome back" : "Create your account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Email/Password form
                    VStack(spacing: 16) {
                        if !isLoginMode {
                            TextField("Full Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isLoginMode ? .password : .newPassword)
                        
                        if !isLoginMode {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)
                        }
                        
                        Button {
                            handleEmailSignIn()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(isLoginMode ? "Sign In" : "Sign Up")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .opacity(isLoading ? 0.7 : 1.0)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty || (!isLoginMode && (name.isEmpty || confirmPassword.isEmpty)))
                    }
                    .padding(.horizontal, 24)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    
                    // Social Sign-In Buttons
                    VStack(spacing: 16) {
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(12)
                        
                        // Google Sign In
                        Button {
                            handleGoogleSignIn()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Toggle between login and registration
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isLoginMode.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(isLoginMode ? "Sign Up" : "Sign In")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.top, 8)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let email = appleIDCredential.email ?? ""
                let fullName = appleIDCredential.fullName
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task { @MainActor in
                        let userName = displayName.isEmpty ? email.components(separatedBy: "@").first ?? "User" : displayName
                        authManager.signIn(with: .apple, email: email.isEmpty ? nil : email, name: userName.isEmpty ? nil : userName)
                        isLoading = false
                    }
                }
            }
        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        // In a real app, this would integrate with Google Sign-In SDK
        // For now, we'll simulate the sign-in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            authManager.signIn(with: .google)
            isLoading = false
        }
    }
    
    private func handleEmailSignIn() {
        // Template authentication - accepts any email/password
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        
        if !isLoginMode {
            guard !name.isEmpty else {
                errorMessage = "Please enter your name"
                return
            }
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match"
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate authentication delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                let userName = name.isEmpty ? email.components(separatedBy: "@").first ?? "User" : name
                authManager.signIn(with: .email, email: email, name: userName)
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
}

