//
//  ChatListView.swift
//  SoloStyle
//
//  Conversations list — entry point to the messenger.
//

import SwiftData
import SwiftUI

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\MessengerConversation.lastMessageAt, order: .reverse)])
    private var allConversations: [MessengerConversation]

    @State private var chatService = ChatService.shared
    @State private var showingStartSheet = false
    @State private var searchText: String = ""

    private var myExternalId: String {
        AuthManager.shared.currentUserExternalId ?? ""
    }

    /// Active (non-archived) conversations matching the search filter.
    private var visibleConversations: [MessengerConversation] {
        let active = allConversations.filter { $0.archivedAt == nil }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return active }
        return active.filter { conv in
            let name = (conv.otherDisplayName ?? conv.otherExternalId(of: myExternalId)).lowercased()
            let preview = (conv.lastMessagePreview ?? "").lowercased()
            return name.contains(q) || preview.contains(q)
        }
    }

    private var pinnedConversations: [MessengerConversation] {
        visibleConversations.filter { $0.isPinned }
    }

    private var regularConversations: [MessengerConversation] {
        visibleConversations.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                if allConversations.filter({ $0.archivedAt == nil }).isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: L.chatsEmptyTitle,
                        subtitle: L.chatsEmptySubtitle,
                        actionTitle: L.newChat,
                        action: { showingStartSheet = true }
                    )
                } else {
                    listContent
                }

                // FAB compose button
                if !allConversations.isEmpty {
                    composeFAB
                        .padding(.trailing, Design.Spacing.l)
                        .padding(.bottom, 100)  // above tab bar
                }
            }
            .navigationTitle(L.tabChats)
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L.searchChats
            )
            .sheet(isPresented: $showingStartSheet) {
                StartConversationSheet()
            }
            .task {
                await ChatService.shared.bootstrap(context: modelContext)
            }
            .refreshable {
                await chatService.syncConversations()
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: Design.Spacing.xs) {
                if !pinnedConversations.isEmpty {
                    sectionHeader(L.pinned, icon: "pin.fill")
                    ForEach(pinnedConversations) { conv in
                        conversationLink(conv)
                    }
                    if !regularConversations.isEmpty {
                        sectionHeader(L.allChats, icon: "bubble.left.and.bubble.right")
                            .padding(.top, Design.Spacing.s)
                    }
                }
                ForEach(regularConversations) { conv in
                    conversationLink(conv)
                }
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.top, Design.Spacing.s)
            .padding(.bottom, 120)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Design.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundStyle(Design.Colors.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Design.Spacing.xs)
        .padding(.top, Design.Spacing.s)
    }

    private func conversationLink(_ conv: MessengerConversation) -> some View {
        NavigationLink {
            ChatView(conversation: conv)
        } label: {
            ConversationRow(conversation: conv, myExternalId: myExternalId)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            // Pin / Unpin
            Button {
                togglePin(conv)
            } label: {
                Label(conv.isPinned ? L.unpin : L.pin,
                      systemImage: conv.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Archive
            Button {
                archive(conv)
            } label: {
                Label(L.archive, systemImage: "archivebox.fill")
            }
            .tint(.gray)

            // Mark read
            if conv.unreadCount(of: myExternalId) > 0 {
                Button {
                    markRead(conv)
                } label: {
                    Label(L.markRead, systemImage: "envelope.open.fill")
                }
                .tint(.blue)
            }
        }
    }

    // MARK: - FAB

    private var composeFAB: some View {
        Button {
            HapticManager.impact(.medium)
            showingStartSheet = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Design.Colors.accentPrimary)
                        .shadow(color: Design.Colors.accentPrimary.opacity(0.4), radius: 14, y: 6)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mutations

    private func togglePin(_ conv: MessengerConversation) {
        HapticManager.impact(.light)
        withAnimation(Design.Animation.smooth) {
            conv.isPinned.toggle()
        }
        try? modelContext.save()
    }

    private func archive(_ conv: MessengerConversation) {
        HapticManager.notification(.warning)
        withAnimation(Design.Animation.smooth) {
            conv.archivedAt = Date()
        }
        try? modelContext.save()
    }

    private func markRead(_ conv: MessengerConversation) {
        HapticManager.impact(.light)
        let role = conv.masterExternalId == myExternalId ? "master" : "client"
        // Zero local unread, tell server we've read everything up to the latest seq.
        if role == "master" {
            conv.unreadMaster = 0
        } else {
            conv.unreadClient = 0
        }
        try? modelContext.save()
        chatService.sendRead(conversationId: conv.id, upToSeq: conv.lastSeenSeq)
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: MessengerConversation
    let myExternalId: String

    private var unread: Int { conversation.unreadCount(of: myExternalId) }
    private var displayName: String {
        conversation.otherDisplayName ?? "ID: \(conversation.otherExternalId(of: myExternalId).prefix(6))"
    }

    var body: some View {
        HStack(spacing: Design.Spacing.s) {
            ProfileAvatar(name: displayName, imageData: nil, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Design.Spacing.xxs) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    Text(displayName)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let date = conversation.lastMessageAt {
                        Text(formatTimestamp(date))
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }

                HStack {
                    Text(conversation.lastMessagePreview ?? L.noMessagesYet)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(unread > 0 ? Design.Colors.textPrimary : Design.Colors.textSecondary)
                        .lineLimit(1)
                        .fontWeight(unread > 0 ? .semibold : .regular)

                    Spacer()

                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Design.Colors.accentPrimary, in: Capsule())
                    }
                }
            }
        }
        .padding(Design.Spacing.s)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
        .contentShape(Rectangle())
    }

    private func formatTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDateInYesterday(date) {
            return L.yesterday
        }
        if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: date).capitalized
        }
        return date.formatted(date: .numeric, time: .omitted)
    }
}

// MARK: - Start Conversation Sheet

private struct StartConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var otherId: String = ""
    @State private var asRole: String = "master"
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Design.Spacing.l) {
                Text(L.startNewChatTitle)
                    .font(Design.Typography.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Design.Spacing.s)

                FormField(
                    title: L.otherUserId,
                    placeholder: "telegram_id / apple_user_id",
                    text: $otherId,
                    icon: "person.text.rectangle"
                )

                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text(L.iActAs)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                    HStack(spacing: Design.Spacing.s) {
                        roleChip(L.roleMaster, value: "master")
                        roleChip(L.roleClient, value: "client")
                    }
                }

                if let error {
                    Text(error)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.accentError)
                }

                Spacer()

                GlassButton(
                    title: L.createChat,
                    icon: "plus.message",
                    style: .prominent,
                    isFullWidth: true,
                    isLoading: isSubmitting
                ) {
                    Task { await create() }
                }
            }
            .padding(Design.Spacing.l)
            .navigationTitle(L.newChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.cancel) { dismiss() }
                }
            }
        }
    }

    private func roleChip(_ title: String, value: String) -> some View {
        Button {
            HapticManager.selection()
            asRole = value
        } label: {
            Text(title)
                .font(Design.Typography.subheadline)
                .fontWeight(asRole == value ? .semibold : .regular)
                .foregroundStyle(asRole == value ? .white : Design.Colors.textPrimary)
                .padding(.horizontal, Design.Spacing.m)
                .padding(.vertical, Design.Spacing.xs)
                .soloGlass(
                    tint: asRole == value ? Color.blue.opacity(0.5) : Color.white.opacity(0.1),
                    shape: .capsule
                )
        }
    }

    private func create() async {
        let trimmed = otherId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = L.enterIdPlease
            return
        }
        isSubmitting = true
        error = nil
        let conv = await ChatService.shared.startConversation(otherExternalId: trimmed, asRole: asRole)
        isSubmitting = false
        if conv != nil {
            dismiss()
        } else {
            error = L.cantCreateChatError
        }
    }
}

#Preview {
    ChatListView()
        .modelContainer(for: [MessengerConversation.self, MessengerMessage.self], inMemory: true)
}
