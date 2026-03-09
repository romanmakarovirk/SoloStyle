//
//  AIAssistantView.swift
//  SoloStyle
//

import SwiftUI
import SwiftData
import MapKit
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
    @State private var keyboardVisible = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            mainContent
                .onTapGesture {
                    inputFocused = false
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        messageInput
                        // Space for the floating tab bar — hide when keyboard covers it
                        if !keyboardVisible {
                            Color.clear.frame(height: tabBarHeight)
                        }
                    }
                }
                .background(Design.Colors.backgroundPrimary)
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle(L.aiAssistant)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { locationManager.requestPermission() }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = false }
                }
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

                Text(L.findMaster)
                    .font(Design.Typography.title2)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .animateOnAppear(delay: 0.1)

                Text(L.findMasterSubtitle)
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
            .soloGlass(tint: Color.blue.opacity(0.2), shape: .circle)
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
                .soloGlass(tint: action.colors[0].opacity(0.15), interactive: true, shape: .capsule)
            }
        }
    }

    private var locationBadge: some View {
        HStack(spacing: Design.Spacing.xs) {
            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash")
                .font(.system(size: 12))
                .foregroundStyle(locationManager.isAuthorized ? Design.Colors.accentSuccess : Design.Colors.accentWarning)

            Text(locationManager.isAuthorized ? L.locationActive : L.locationDenied)
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
        }
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.xs)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .capsule)
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

                    // Map + master cards after the last AI message
                    if !aiService.lastMasters.isEmpty {
                        // Map first — right after the AI text response
                        MastersMapView(
                            masters: aiService.lastMasters,
                            userLatitude: locationManager.latitude,
                            userLongitude: locationManager.longitude
                        )
                        .id("map")

                        // Then master cards list
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
            .scrollDismissesKeyboard(.immediately)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo("masters", anchor: .bottom)
                        }
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
                TextField(L.describeService, text: $inputText, axis: .vertical)
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
            .soloGlass(tint: Color.white.opacity(0.08), shape: .capsule)
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.xs)
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
        case .haircut: L.qaHaircut
        case .manicure: L.qaManicure
        case .massage: L.qaMassage
        case .makeup: L.qaMakeup
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
                    .soloGlass(tint: Color.blue.opacity(0.15), shape: .circle)
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

// MARK: - Shared Master Helpers (deduplicated — used by MasterCard, BookMasterSheet, MasterMapPin, MastersMapView)

private let _masterAvatarPalette: [Color] = [.blue, .purple, .pink, .orange, .teal]

extension MasterResult {
    /// Two-letter initials from the master name
    var initials: String {
        let parts = masterName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(masterName.prefix(2)).uppercased()
    }

    /// Deterministic gradient based on the master name hash
    var avatarGradient: LinearGradient {
        let hash = abs(masterName.hashValue)
        let c1 = _masterAvatarPalette[hash % _masterAvatarPalette.count]
        let c2 = _masterAvatarPalette[(hash / _masterAvatarPalette.count) % _masterAvatarPalette.count]
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Primary color (first gradient stop)
    var primaryColor: Color {
        _masterAvatarPalette[abs(masterName.hashValue) % _masterAvatarPalette.count]
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
                Text(L.foundMasters)
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
    @State private var showingBooking = false

    var body: some View {
        Button {
            HapticManager.impact(.light)
            showingBooking = true
        } label: {
            VStack(spacing: 0) {
                // Top row: avatar + name + rating
                HStack(spacing: Design.Spacing.s) {
                    // Avatar
                    Text(master.initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(master.avatarGradient, in: .circle)

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
                    .soloGlass(tint: Color.orange.opacity(0.1), shape: .capsule)
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
                        Text(L.priceLabel)
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
                        Text(L.distanceLabel)
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
                        Text(L.yearsExp(master.experience))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Design.Colors.textPrimary)
                        Text(L.experienceLabel)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Book button
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L.bookAppointment)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Spacing.s)
                .background(
                    Capsule()
                        .fill(Design.Colors.accentPrimary)
                )
                .padding(.top, Design.Spacing.s)
            }
            .padding(Design.Spacing.m)
            .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingBooking) {
            BookMasterSheet(master: master)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

}

// MARK: - Book Master Sheet

struct BookMasterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let master: MasterResult

    @State private var selectedDate = Date()
    @State private var clientName = ""
    @State private var clientPhone = ""
    @State private var comment = ""
    @State private var isBooked = false
    @State private var isSaving = false
    @FocusState private var focusedField: BookingField?

    private enum BookingField { case name, phone, comment }

    private var canBook: Bool {
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                if isBooked {
                    successView
                } else {
                    bookingForm
                }
            }
            .navigationTitle(L.bookingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Booking Form

    private var bookingForm: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.l) {
                // Master info card
                masterInfoCard
                    .animateOnAppear()

                // Date & time
                dateTimeSection
                    .animateOnAppear(delay: 0.05)

                // Client info
                clientInfoSection
                    .animateOnAppear(delay: 0.1)

                // Comment
                commentSection
                    .animateOnAppear(delay: 0.15)

                // Confirm button
                confirmButton
                    .animateOnAppear(delay: 0.2)
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.top, Design.Spacing.s)
            .padding(.bottom, Design.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Master Info Card

    private var masterInfoCard: some View {
        HStack(spacing: Design.Spacing.m) {
            // Avatar
            Text(master.initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(master.avatarGradient, in: .circle)

            VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                Text(master.masterName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(master.serviceName)
                    .font(.system(size: 14))
                    .foregroundStyle(Design.Colors.textSecondary)

                HStack(spacing: Design.Spacing.m) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", master.rating))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Design.Colors.textPrimary)

                    Text(master.formattedPrice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Design.Colors.accentPrimary)

                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text(master.formattedDistance)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Design.Colors.textTertiary)
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.xl))
    }

    // MARK: - Date Time Section

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack(spacing: Design.Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 32, height: 32)
                    .soloGlass(tint: Color.blue.opacity(0.15), shape: .circle)

                Text(L.selectDateTime)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Design.Colors.textSecondary)

                Spacer()
            }

            DatePicker(
                "",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(Design.Colors.accentPrimary)
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.xl))
    }

    // MARK: - Client Info Section

    private var clientInfoSection: some View {
        VStack(spacing: Design.Spacing.s) {
            HStack(spacing: Design.Spacing.s) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 24)

                TextField(L.yourName, text: $clientName)
                    .font(Design.Typography.body)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
            }
            .padding(Design.Spacing.m)
            .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))

            HStack(spacing: Design.Spacing.s) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .frame(width: 24)

                TextField(L.yourPhone, text: $clientPhone)
                    .font(Design.Typography.body)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
            }
            .padding(Design.Spacing.m)
            .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
        }
    }

    // MARK: - Comment Section

    private var commentSection: some View {
        HStack(alignment: .top, spacing: Design.Spacing.s) {
            Image(systemName: "text.quote")
                .font(.system(size: 14))
                .foregroundStyle(.mint)
                .frame(width: 24)
                .padding(.top, 2)

            TextField(L.bookingComment, text: $comment, axis: .vertical)
                .lineLimit(2...4)
                .font(Design.Typography.body)
                .focused($focusedField, equals: .comment)
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            bookAppointment()
        } label: {
            HStack(spacing: Design.Spacing.s) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(L.confirmBooking)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.l)
                    .fill(canBook
                        ? LinearGradient(colors: [Design.Colors.accentPrimary, Design.Colors.accentPrimary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .disabled(!canBook || isSaving)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Design.Spacing.l) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Design.Colors.accentSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Design.Colors.accentSuccess.opacity(0.3))
                    .frame(width: 76, height: 76)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Design.Colors.accentSuccess)
            }
            .animateOnAppear()

            VStack(spacing: Design.Spacing.xs) {
                Text(L.bookingSuccess)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .animateOnAppear(delay: 0.1)

                Text(L.bookingSuccessMsg)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.xl)
                    .animateOnAppear(delay: 0.15)
            }

            // Booking summary
            VStack(spacing: Design.Spacing.s) {
                summaryRow(icon: "person.fill", label: L.masterLabel, value: master.masterName, tint: .purple)
                summaryRow(icon: "scissors", label: L.serviceLabel, value: master.serviceName, tint: .blue)
                summaryRow(icon: "calendar", label: L.selectDateTime, value: selectedDate.formatted(date: .abbreviated, time: .shortened), tint: .orange)
                summaryRow(icon: "rublesign.circle.fill", label: L.priceLabel, value: master.formattedPrice, tint: .green)
            }
            .padding(Design.Spacing.m)
            .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.xl))
            .padding(.horizontal, Design.Spacing.m)
            .animateOnAppear(delay: 0.2)

            Spacer()

            Button {
                HapticManager.impact(.light)
                dismiss()
            } label: {
                Text(L.great)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.l)
                            .fill(Design.Colors.accentSuccess)
                    )
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.bottom, Design.Spacing.xl)
            .animateOnAppear(delay: 0.25)
        }
    }

    private func summaryRow(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: Design.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .soloGlass(tint: tint.opacity(0.15), shape: .circle)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Design.Colors.textTertiary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Design.Colors.textPrimary)
        }
    }

    // MARK: - Logic

    private func bookAppointment() {
        focusedField = nil
        isSaving = true
        HapticManager.impact(.medium)

        // Create local service from master data
        let service = Service(
            name: master.serviceName,
            price: Decimal(master.price),
            duration: 60
        )
        modelContext.insert(service)

        // Create client
        let name = clientName.trimmingCharacters(in: .whitespaces)
        let phone = clientPhone.trimmingCharacters(in: .whitespaces)
        let client = Client(
            name: name,
            phone: phone.isEmpty ? nil : phone
        )
        modelContext.insert(client)

        // Create appointment
        let appointment = Appointment(
            date: selectedDate,
            service: service,
            client: client
        )
        if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
            appointment.notes = comment.trimmingCharacters(in: .whitespaces)
        }
        modelContext.insert(appointment)

        // Schedule notification
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            NotificationManager.shared.scheduleReminder(for: appointment)
        }

        StatsCache.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSaving = false
            withAnimation(Design.Animation.smooth) {
                isBooked = true
            }
            HapticManager.notification(.success)
        }
    }

}

// MARK: - Masters Map View

struct MastersMapView: View {
    let masters: [MasterResult]
    let userLatitude: Double
    let userLongitude: Double

    @State private var isExpanded = false
    @State private var selectedMaster: MasterResult?

    /// Coordinate for a master — uses real coords if available, otherwise approximates from distanceKm
    private func coordinate(for master: MasterResult, index: Int) -> CLLocationCoordinate2D {
        if let lat = master.masterLat, let lon = master.masterLon {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        // Approximate: spread masters around user at their distance, evenly angled
        let angle = (Double(index) / Double(max(masters.count, 1))) * 2 * .pi
        // 1 degree latitude ≈ 111 km
        let latOffset = (master.distanceKm / 111.0) * cos(angle)
        let lonOffset = (master.distanceKm / (111.0 * cos(userLatitude * .pi / 180))) * sin(angle)
        return CLLocationCoordinate2D(latitude: userLatitude + latOffset, longitude: userLongitude + lonOffset)
    }

    private var allMasterCoords: [(MasterResult, CLLocationCoordinate2D)] {
        masters.enumerated().map { (i, m) in (m, coordinate(for: m, index: i)) }
    }

    private var mapRegion: MKCoordinateRegion {
        let userCoord = CLLocationCoordinate2D(latitude: userLatitude, longitude: userLongitude)
        var allCoords = [userCoord]
        for (_, coord) in allMasterCoords {
            allCoords.append(coord)
        }

        let lats = allCoords.map(\.latitude)
        let lons = allCoords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let spanLat = max((lats.max()! - lats.min()!) * 1.5, 0.02)
        let spanLon = max((lons.max()! - lons.min()!) * 1.5, 0.02)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            // Header
            Button {
                HapticManager.impact(.light)
                withAnimation(Design.Animation.smooth) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Design.Spacing.s) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 32, height: 32)
                        .soloGlass(tint: Color.teal.opacity(0.15), shape: .circle)

                    Text(L.mastersOnMap)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Design.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                        .soloGlass(tint: Color.white.opacity(0.08), shape: .circle)
                }
            }

            mapContent
                .frame(height: isExpanded ? 340 : 180)
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.l))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Radius.l)
                        .strokeBorder(Design.Colors.textTertiary.opacity(0.15), lineWidth: 0.5)
                )
                .animation(Design.Animation.smooth, value: isExpanded)
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.xl))
    }

    private var mapContent: some View {
        Map(initialPosition: .region(mapRegion)) {
            // User location
            Annotation(L.you, coordinate: CLLocationCoordinate2D(latitude: userLatitude, longitude: userLongitude)) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(.blue)
                        .frame(width: 16, height: 16)
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                        .frame(width: 16, height: 16)
                }
            }

            // Master annotations — all masters, with real or approximated coords
            ForEach(Array(allMasterCoords.enumerated()), id: \.element.0.id) { _, pair in
                let (master, coord) = pair
                Annotation(
                    master.masterName,
                    coordinate: coord
                ) {
                    MasterMapPin(master: master, isSelected: selectedMaster?.id == master.id)
                        .onTapGesture {
                            HapticManager.selection()
                            withAnimation(Design.Animation.smooth) {
                                selectedMaster = selectedMaster?.id == master.id ? nil : master
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
        }
        .overlay(alignment: .bottom) {
            // Selected master info pill
            if let master = selectedMaster {
                HStack(spacing: Design.Spacing.s) {
                    Text(String(master.masterName.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(master.avatarGradient, in: .circle)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(master.masterName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Design.Colors.textPrimary)
                        Text("\(master.formattedPrice) \u{2022} \(master.formattedDistance)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Design.Colors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", master.rating))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Design.Colors.textPrimary)
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
                .padding(.vertical, Design.Spacing.s)
                .soloGlass(tint: Color.white.opacity(0.2), shape: .capsule)
                .padding(.horizontal, Design.Spacing.s)
                .padding(.bottom, Design.Spacing.s)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

}

// MARK: - Master Map Pin

struct MasterMapPin: View {
    let master: MasterResult
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Outer glow when selected
                if isSelected {
                    Circle()
                        .fill(master.primaryColor.opacity(0.25))
                        .frame(width: 44, height: 44)
                }

                // Main pin circle
                Circle()
                    .fill(master.avatarGradient)
                    .frame(width: isSelected ? 36 : 30, height: isSelected ? 36 : 30)
                    .shadow(color: master.primaryColor.opacity(0.4), radius: isSelected ? 8 : 4, y: 2)

                // Initials
                Text(master.initials)
                    .font(.system(size: isSelected ? 13 : 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Price tag
            Text(master.formattedPrice)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Design.Colors.textPrimary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        }
        .animation(Design.Animation.bouncy, value: isSelected)
    }

}

// MARK: - Typing Indicator

struct TypingRow: View {
    @State private var currentDot = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .soloGlass(tint: Color.blue.opacity(0.15), shape: .circle)

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
        .onAppear {
            timerTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { break }
                    currentDot = (currentDot + 1) % 3
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
    }
}

#Preview {
    AIAssistantView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
