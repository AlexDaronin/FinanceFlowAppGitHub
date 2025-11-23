//
//  AIChatView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var messages = ChatMessage.sample
    @State private var draft = ""
    @State private var isThinking = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                chatBubble(for: message)
                                    .id(message.id)
                            }
                            if isThinking {
                                thinkingBubble
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .onChange(of: messages) { _, newMessages in
                        guard let id = newMessages.last?.id else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                composeBar
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(Color.customBackground)
            }
            .background(Color.customBackground)
            .navigationTitle("AI Accountant")
        }
    }
    
    private func chatBubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant { Spacer() }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(message.role.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.role == .assistant ? .white : .primary)
            }
            .padding(12)
            .background(message.role == .assistant ? Color.accentColor : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
            
            if message.role == .user { Spacer() }
        }
    }
    
    private var thinkingBubble: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.white.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .opacity(isThinking ? 1 : 0.4)
                        .animation(.easeInOut(duration: 0.8).repeatForever().delay(Double(index) * 0.15), value: isThinking)
                }
            }
            .padding(12)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }
    
    private var composeBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything about your money...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            
            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(draft.isEmpty ? .gray : Color.accentColor)
                    .clipShape(Circle())
            }
            .disabled(draft.isEmpty)
        }
    }
    
    private func send() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMessage = ChatMessage(role: .user, text: content, date: Date())
        messages.append(newMessage)
        draft = ""
        isThinking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let reply = ChatMessage(role: .assistant, text: AIResponseGenerator.answer(for: content, currencyCode: settings.currency), date: Date())
            messages.append(reply)
            isThinking = false
        }
    }
}

