//
//  AIAssistantView.swift
//  SoloStyle
//

import SwiftUI
import SwiftData
import Combine

// MARK: - AI Service (Search via backend)

@MainActor
@Observable
class AIService {
    static let shared = AIService()

    var isLoading = false
    var lastError: String?
    var lastMasters: [MasterResult] = []

    private init() {}

    func search(query: String, latitude: Double, longitude: Double) async -> String {
        isLoading = true
        lastError = nil
        lastMasters = []
        defer { isLoading = false }

        do {
            let response = try await NetworkManager.shared.searchMasters(
                query: query,
                latitude: latitude,
                longitude: longitude
            )
            lastMasters = response.masters
            return response.answer
        } catch let error as NetworkError {
            lastError = error.errorDescription
            return "Не удалось выполнить поиск: \(error.errorDescription ?? "неизвестная ошибка")"
        } catch {
            lastError = error.localizedDescription
            return "Произошла ошибка: \(error.localizedDescription)"
        }
    }
}

struct AIAssistantView: View {
    /// Measured height of the floating GlassTabBar (passed from MainTabView)
    var tabBarHeight: CGFloat = 0

    @State private var aiService = AIService.shared
    @State private var locationManager = LocationManager.shared

    @State private var inputText = ""
    @State private var chatMessages: [ChatMessage] = []
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            mainContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        messageInput
                        // Space for the floating tab bar
                        Color.clear.frame(height: tabBarHeight)
                    }
                }
                .background(Design.Colors.backgroundPrimary)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("AI Assistant")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { locationManager.requestPermission() }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if chatMessages.isEmpty {
            welcomeScreen
        } else {
            messagesView
        }
    }

    // MARK: - Welcome

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.l) {
                Spacer(minLength: 60)

                avatarView
                    .animateOnAppear()

                Text("Найди мастера")
                    .font(Design.Typography.title2)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .animateOnAppear(delay: 0.1)

                Text("Опиши, что тебе нужно, и я подберу лучших мастеров поблизости")
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.xl)
                    .animateOnAppear(delay: 0.15)

                actionsGrid
                    .padding(.horizontal, Design.Spacing.m)
                    .animateOnAppear(delay: 0.2)

                locationBadge
                    .animateOnAppear(delay: 0.3)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var avatarView: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Design.Colors.accentPrimary)
            .frame(width: 64, height: 64)
            .glassEffect(.regular.tint(Color.blue.opacity(0.2)), in: .circle)
            .symbolEffect(.breathe.pulse.byLayer, options: .repeating)
    }

    private var actionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Design.Spacing.s), GridItem(.flexible(), spacing: Design.Spacing.s)], spacing: Design.Spacing.s) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button {
                    HapticManager.selection()
                    runQuickAction(action)
                } label: {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: action.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(action.colors[0])
                        Text(action.title)
                            .font(Design.Typography.subheadline)
                            .foregroundStyle(Design.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.s)
                }
                .glassEffect(.regular.tint(action.colors[0].opacity(0.15)).interactive(), in: .capsule)
            }
        }
    }

    private var locationBadge: some View {
        HStack(spacing: Design.Spacing.xs) {
            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash")
                .font(.system(size: 12))
                .foregroundStyle(locationManager.isAuthorized ? Design.Colors.accentSuccess : Design.Colors.accentWarning)

            Text(locationManager.isAuthorized ? "Геолокация активна" : "Геолокация не разрешена")
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
        }
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.xs)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .capsule)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Design.Spacing.m) {
                    ForEach(chatMessages) { msg in
                        MessageRow(message: msg)
                            .id(msg.id)
                    }

                    // Master cards after the last AI message
                    if !aiService.lastMasters.isEmpty {
                        MasterCardsView(masters: aiService.lastMasters)
                            .id("masters")
                    }

                    if aiService.isLoading {
                        TypingRow()
                            .id("typing")
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
                .padding(.top, Design.Spacing.s)
                .padding(.bottom, Design.Spacing.s)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chatMessages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: aiService.isLoading) { _, loading in
                if loading {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            .onChange(of: aiService.lastMasters.count) { _, count in
                if count > 0 {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("masters", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if !aiService.lastMasters.isEmpty {
                proxy.scrollTo("masters", anchor: .bottom)
            } else if let id = chatMessages.last?.id {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input

    private var messageInput: some View {
        HStack(spacing: Design.Spacing.s) {
            if !chatMessages.isEmpty {
                Button {
                    HapticManager.impact(.light)
                    withAnimation(.spring(response: 0.3)) {
                        chatMessages.removeAll()
                        aiService.lastMasters = []
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Design.Colors.textTertiary)
                        .frame(width: 36, height: 36)
                }
            }

            HStack(spacing: Design.Spacing.s) {
                TextField("Опишите услугу...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(Design.Typography.body)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        send()
                    }

                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray.opacity(0.3)
                            : Design.Colors.accentPrimary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.s)
            .glassEffect(.regular.tint(Color.white.opacity(0.08)), in: .capsule)
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.xs)
        .background(
            Design.Colors.backgroundPrimary
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Logic

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        HapticManager.impact(.light)
        inputFocused = false

        let userMsg = ChatMessage(content: text, isFromUser: true)
        withAnimation(.spring(response: 0.3)) {
            chatMessages.append(userMsg)
        }
        inputText = ""

        Task {
            let response = await aiService.search(
                query: text,
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )

            let aiMsg = ChatMessage(content: response, isFromUser: false)
            withAnimation(.spring(response: 0.3)) {
                chatMessages.append(aiMsg)
            }
            HapticManager.notification(.success)
        }
    }

    private func runQuickAction(_ action: QuickAction) {
        inputText = action.prompt
        send()
    }
}

// MARK: - Quick Actions

enum QuickAction: CaseIterable {
    case haircut, manicure, massage, makeup

    var title: String {
        switch self {
        case .haircut: "Стрижка"
        case .manicure: "Маникюр"
        case .massage: "Массаж"
        case .makeup: "Макияж"
        }
    }

    var prompt: String {
        switch self {
        case .haircut: "haircut"
        case .manicure: "manicure"
        case .massage: "massage"
        case .makeup: "makeup"
        }
    }

    var icon: String {
        switch self {
        case .haircut: "scissors"
        case .manicure: "hand.raised"
        case .massage: "figure.mind.and.body"
        case .makeup: "paintbrush.pointed"
        }
    }

    var colors: [Color] {
        switch self {
        case .haircut: [.purple, .blue]
        case .manicure: [.pink, .red]
        case .massage: [.green, .mint]
        case .makeup: [.orange, .yellow]
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let time = Date()
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xs) {
            if message.isFromUser {
                Spacer(minLength: 48)
            } else {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular.tint(Color.blue.opacity(0.15)), in: .circle)
            }

            if message.isFromUser {
                Text(message.content)
                    .font(Design.Typography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.vertical, Design.Spacing.s + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            } else {
                // AI message with markdown support
                Text(.init(message.content))
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.vertical, Design.Spacing.s + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Design.Colors.backgroundSecondary)
                    )
            }

            if !message.isFromUser { Spacer(minLength: 16) }
        }
    }
}

// MARK: - Master Cards

struct MasterCardsView: View {
    let masters: [MasterResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            // Section header
            HStack(spacing: Design.Spacing.xs) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.Colors.accentPrimary)
                Text("Найденные мастера")
                    .font(Design.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Design.Colors.textSecondary)
            }
            .padding(.leading, Design.Spacing.xxs)

            ForEach(masters) { master in
                MasterCard(master: master)
            }
        }
        .padding(.top, Design.Spacing.xs)
    }
}

struct MasterCard: View {
    let master: MasterResult

    var body: some View {
        VStack(spacing: 0) {
            // Top row: avatar + name + rating
            HStack(spacing: Design.Spacing.s) {
                // Avatar
                Text(initials(master.masterName))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(avatarGradient, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(master.masterName)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)

                    Text(master.serviceName)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Rating badge
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(String(format: "%.1f", master.rating))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Design.Colors.textPrimary)
                }
                .padding(.horizontal, Design.Spacing.xs)
                .padding(.vertical, Design.Spacing.xxs)
                .glassEffect(.regular.tint(Color.orange.opacity(0.1)), in: .capsule)
            }

            // Divider
            Rectangle()
                .fill(Design.Colors.textTertiary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.vertical, Design.Spacing.s)

            // Bottom row: price, distance, experience
            HStack(spacing: 0) {
                // Price
                VStack(spacing: 2) {
                    Text(master.formattedPrice)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)
                    Text("цена")
                        .font(Design.Typography.caption2)
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                // Separator dot
                Circle()
                    .fill(Design.Colors.textTertiary.opacity(0.3))
                    .frame(width: 4, height: 4)

                // Distance
                VStack(spacing: 2) {
                    Text(master.formattedDistance)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)
                    Text("до вас")
                        .font(Design.Typography.caption2)
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                // Separator dot
                Circle()
                    .fill(Design.Colors.textTertiary.opacity(0.3))
                    .frame(width: 4, height: 4)

                // Experience
                VStack(spacing: 2) {
                    Text("\(master.experience) лет")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)
                    Text("стаж")
                        .font(Design.Typography.caption2)
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(Design.Spacing.m)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.l))
    }

    private var avatarGradient: LinearGradient {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal]
        let hash = abs(master.masterName.hashValue)
        let c1 = colors[hash % colors.count]
        let c2 = colors[(hash / colors.count) % colors.count]
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Typing Indicator

struct TypingRow: View {
    @State private var currentDot = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(Color.blue.opacity(0.15)), in: .circle)

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Design.Colors.textTertiary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(currentDot == i ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentDot)
                }
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.m)
            .background(RoundedRectangle(cornerRadius: 20).fill(Design.Colors.backgroundSecondary))

            Spacer()
        }
        .onReceive(timer) { _ in
            currentDot = (currentDot + 1) % 3
        }
    }
}

#Preview {
    AIAssistantView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
