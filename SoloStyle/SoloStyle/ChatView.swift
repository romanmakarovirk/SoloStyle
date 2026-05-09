//
//  ChatView.swift
//  SoloStyle
//
//  Single-conversation messenger view.  Bubbles + composer + read receipts.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: MessengerConversation

    @Environment(\.modelContext) private var modelContext

    @Query private var messages: [MessengerMessage]

    @State private var chatService = ChatService.shared
    @State private var draft: String = ""
    @FocusState private var isInputFocused: Bool

    private var myExternalId: String {
        AuthManager.shared.currentUserExternalId ?? ""
    }

    private var sortedMessages: [MessengerMessage] {
        // Within a conversation we want chronological order.  We use seq when
        // available (server-assigned), and createdAt as fallback for pending
        // local rows that don't have a seq yet.
        messages.sorted { lhs, rhs in
            if lhs.seq != 0 && rhs.seq != 0 {
                return lhs.seq < rhs.seq
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var typing: Bool {
        guard let last = chatService.typingFromOther[conversation.id] else { return false }
        return Date().timeIntervalSince(last) < 5
    }

    init(conversation: MessengerConversation) {
        self.conversation = conversation
        let convID = conversation.id
        // Filter MessengerMessage rows that belong to this conversation.  SwiftData
        // doesn't let us compare on relationships directly, so we use the
        // server conv id stored on the parent.
        _messages = Query(
            filter: #Predicate<MessengerMessage> { msg in
                msg.conversation?.id == convID
            }
        )
    }

    var body: some View {
        ZStack {
            Design.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Design.Spacing.xs) {
                            ForEach(sortedMessages) { msg in
                                MessageBubble(message: msg, mine: msg.senderExternalId == myExternalId)
                                    .id(msg.clientMessageId)
                            }

                            if typing {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal, Design.Spacing.m)
                            }
                        }
                        .padding(.vertical, Design.Spacing.m)
                    }
                    .onChange(of: sortedMessages.count) { _, _ in
                        if let last = sortedMessages.last {
                            withAnimation(Design.Animation.smooth) {
                                proxy.scrollTo(last.clientMessageId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = sortedMessages.last {
                            proxy.scrollTo(last.clientMessageId, anchor: .bottom)
                        }
                    }
                }

                composer
            }
        }
        .navigationTitle(conversation.otherDisplayName ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConnectionStatusDot(state: chatService.connectionState)
            }
        }
        .task {
            await chatService.syncMessages(for: conversation.id)
            chatService.connect()
            markRead()
        }
        .onChange(of: sortedMessages.count) { _, _ in
            markRead()
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: Design.Spacing.s) {
            TextField("Сообщение", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onChange(of: draft) { _, newValue in
                    // Send typing indicator on first character only (debounce-ish)
                    if !newValue.isEmpty && newValue.count == 1 {
                        chatService.sendTyping(conversationId: conversation.id)
                    }
                }
                .padding(.horizontal, Design.Spacing.s)
                .padding(.vertical, Design.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.l)
                        .fill(Design.Colors.backgroundSecondary)
                )

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
            }
            .disabled(!canSend)
            .animation(Design.Animation.quick, value: canSend)
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.s)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.impact(.light)
        chatService.sendText(trimmed, to: conversation)
        draft = ""
    }

    /// Tell the server we've read up to the highest seq we currently have.
    private func markRead() {
        let maxSeq = sortedMessages
            .filter { $0.senderExternalId != myExternalId }
            .map(\.seq)
            .max() ?? 0
        if maxSeq > 0 {
            chatService.sendRead(conversationId: conversation.id, upToSeq: maxSeq)
        }
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: MessengerMessage
    let mine: Bool

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 60) }

            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                if let text = message.body, !text.isEmpty {
                    Text(text)
                        .font(Design.Typography.body)
                        .foregroundStyle(mine ? .white : Design.Colors.textPrimary)
                        .padding(.horizontal, Design.Spacing.s)
                        .padding(.vertical, Design.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: Design.Radius.l)
                                .fill(
                                    mine
                                    ? AnyShapeStyle(Design.Colors.accentPrimary)
                                    : AnyShapeStyle(Color(.tertiarySystemBackground))
                                )
                        )
                }

                HStack(spacing: 4) {
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(Design.Colors.textTertiary)

                    if mine {
                        statusIcon
                    }
                }
                .padding(.horizontal, 4)
            }

            if !mine { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Design.Spacing.m)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(Design.Colors.textTertiary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Colors.textTertiary)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Colors.textTertiary)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Colors.accentPrimary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Colors.accentError)
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(Design.Colors.textTertiary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == idx ? 1 : 0.3)
            }
        }
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.l)
                .fill(Color(.tertiarySystemBackground))
        )
        .onAppear {
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                phase = 2
            }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Connection status dot

private struct ConnectionStatusDot: View {
    let state: ChatConnectionState

    var color: Color {
        switch state {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected, .failed: return .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: MessengerConversation.self, MessengerMessage.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let conv = MessengerConversation(
        id: UUID(),
        masterExternalId: "master_demo",
        clientExternalId: "client_demo"
    )
    container.mainContext.insert(conv)
    return NavigationStack {
        ChatView(conversation: conv)
    }
    .modelContainer(container)
}
