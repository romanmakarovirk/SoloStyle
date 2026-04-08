//
//  ClientMainView.swift
//  SoloStyle
//
//  Client interface — AI search (like master AIAssistant), calendar bookings, settings
//

import SwiftUI
import SwiftData
import MapKit
import Combine

// MARK: - Client Tab

enum ClientTab: String, CaseIterable, Identifiable {
    case search
    case bookings
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: L.tabSearch
        case .bookings: L.tabMyBookings
        case .settings: L.tabSettings
        }
    }

    var icon: String {
        switch self {
        case .search: "sparkles"
        case .bookings: "calendar.badge.clock"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .search: "sparkles"
        case .bookings: "calendar.badge.clock"
        case .settings: "gearshape.fill"
        }
    }

    var isAI: Bool { self == .search }
}

// MARK: - Client Main View

struct ClientMainView: View {
    @State private var selectedTab: ClientTab = .search
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ClientSearchTab(tabBarHeight: tabBarHeight)
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)

                ClientBookingsTab()
                    .opacity(selectedTab == .bookings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .bookings)

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ClientGlassTabBar(selectedTab: $selectedTab)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                .padding(.horizontal, Design.Spacing.s)
                .padding(.bottom, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ClientTabBarHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(ClientTabBarHeightKey.self) { tabBarHeight = $0 }
        }
        .background(Design.Colors.backgroundPrimary)
        .ignoresSafeArea(.keyboard)
    }
}

private struct ClientTabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Client Glass Tab Bar

private struct ClientGlassTabBar: View {
    @Binding var selectedTab: ClientTab
    @Namespace private var namespace

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    tabBarContent
                }
            } else {
                tabBarContent
            }
        }
        .soloGlass(tint: Color.white.opacity(0.1), shape: .capsule)
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            ForEach(ClientTab.allCases) { tab in
                ClientTabBarItem(tab: tab, isSelected: selectedTab == tab, namespace: namespace) {
                    HapticManager.selection()
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.s)
    }
}

private struct ClientTabBarItem: View {
    let tab: ClientTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    private var aiGradient: LinearGradient {
        LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if tab.isAI {
                    Image(systemName: tab.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isSelected ? aiGradient : LinearGradient(colors: [Design.Colors.textTertiary], startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, options: .nonRepeating, value: isSelected)
                } else {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        tab.isAI && isSelected
                            ? AnyShapeStyle(aiGradient)
                            : AnyShapeStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Tab (Identical to AIAssistantView)

private struct ClientSearchTab: View {
    var tabBarHeight: CGFloat = 0

    @State private var aiService = AIService.shared
    @State private var locationManager = LocationManager.shared

    @State private var inputText = ""
    @State private var chatMessages: [ChatMessage] = []
    @State private var keyboardVisible = false
    @State private var searchTask: Task<Void, Never>?
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

                // Avatar sparkles
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 64, height: 64)
                    .soloGlass(tint: Color.blue.opacity(0.2), shape: .circle)
                    .symbolEffect(.breathe.pulse.byLayer, options: .repeating)
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

                // 2×2 Quick Actions Grid
                actionsGrid
                    .padding(.horizontal, Design.Spacing.m)
                    .animateOnAppear(delay: 0.2)

                // Location badge
                locationBadge
                    .animateOnAppear(delay: 0.3)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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
                        MastersMapView(
                            masters: aiService.lastMasters,
                            userLatitude: locationManager.latitude,
                            userLongitude: locationManager.longitude
                        )
                        .id("map")

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
            .onChange(of: chatMessages.count) { _, count in
                if count > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy)
                    }
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
                    searchTask?.cancel()
                    searchTask = nil
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

        searchTask?.cancel()
        searchTask = Task {
            let response = await aiService.search(
                query: text,
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )

            guard !Task.isCancelled else { return }

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

// MARK: - Bookings Tab (Identical to CalendarView)

private struct ClientBookingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appointment.date) private var appointments: [Appointment]

    @State private var selectedDate = Date()
    @State private var isAnimatingDate = false

    private var todayAppointments: [Appointment] {
        appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Date header — large, left-aligned
                    dateHeader
                        .animateOnAppear()

                    // Week strip
                    weekStrip
                        .animateOnAppear(delay: 0.05)

                    // Summary pill
                    if !todayAppointments.isEmpty {
                        summaryPill
                            .padding(.top, Design.Spacing.s)
                            .animateOnAppear(delay: 0.1)
                    }

                    // Appointments list
                    ScrollView {
                        LazyVStack(spacing: Design.Spacing.s) {
                            if todayAppointments.isEmpty {
                                emptyState
                                    .animateOnAppear(delay: 0.15)
                            } else {
                                ForEach(Array(todayAppointments.enumerated()), id: \.element.id) { index, appointment in
                                    AppointmentRow(appointment: appointment, onDelete: {})
                                        .animateOnAppear(delay: 0.05 * Double(index))
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .padding(.top, Design.Spacing.s)
                        .padding(.bottom, 130)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide)).capitalized)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Colors.accentPrimary)

            HStack(alignment: .firstTextBaseline) {
                Text(selectedDate.formatted(.dateTime.day()))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Design.Colors.textSecondary)

                Spacer()

                // Today button
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(Design.Animation.smooth) {
                            selectedDate = Date()
                        }
                    } label: {
                        Text(L.today)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Design.Colors.accentPrimary)
                            .padding(.horizontal, Design.Spacing.s)
                            .padding(.vertical, Design.Spacing.xxs + 2)
                            .soloGlass(tint: Color.blue.opacity(0.15), shape: .capsule)
                    }
                }
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.top, Design.Spacing.m)
        .padding(.bottom, Design.Spacing.s)
        .scaleEffect(isAnimatingDate ? 0.98 : 1.0, anchor: .leading)
        .opacity(isAnimatingDate ? 0.7 : 1.0)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let days = weekDays(around: selectedDate)

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        DayCell(
                            date: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                            hasAppointments: hasAppointments(on: day)
                        ) {
                            HapticManager.selection()
                            withAnimation(Design.Animation.smooth) {
                                isAnimatingDate = true
                                selectedDate = day
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation { isAnimatingDate = false }
                            }
                        }
                        .id(day)
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
                .padding(.vertical, 12)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
        .padding(.horizontal, Design.Spacing.xxs)
        .soloGlass(tint: Color.blue.opacity(0.08), shape: .roundedRect(Design.Radius.xl))
        .padding(.horizontal, Design.Spacing.s)
    }

    // MARK: - Summary Pill

    private var summaryPill: some View {
        HStack(spacing: Design.Spacing.m) {
            Label("\(todayAppointments.count) \(L.appointmentsCount)", systemImage: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.Colors.textSecondary)

            Spacer()

            let completed = todayAppointments.filter { $0.status == .completed }.count
            if completed > 0 {
                Label("\(completed) \(L.completedCount)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Design.Colors.accentSuccess)
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.s)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .capsule)
        .padding(.horizontal, Design.Spacing.m)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Design.Spacing.m) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Design.Colors.textTertiary.opacity(0.5))

            VStack(spacing: Design.Spacing.xxs) {
                Text(L.noUpcomingAppointments)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Design.Colors.textSecondary)

                Text(L.clientBookingsHint)
                    .font(.system(size: 14))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.xxl)
        .soloGlass(tint: Color.white.opacity(0.03), shape: .roundedRect(Design.Radius.xl))
    }

    // MARK: - Helpers

    private func weekDays(around date: Date) -> [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        for offset in -14...14 {
            if let day = calendar.date(byAdding: .day, value: offset, to: date) {
                days.append(day)
            }
        }
        return days
    }

    private func hasAppointments(on date: Date) -> Bool {
        appointments.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
