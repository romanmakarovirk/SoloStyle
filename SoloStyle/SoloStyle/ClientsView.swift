//
//  ClientsView.swift
//  SoloStyle
//
//  Client management with search, filters, and animations
//

import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name, animation: .default) private var clients: [Client]

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var showingAddClient = false
    @State private var selectedFilter: ClientFilter = .all
    @State private var sortOrder: SortOrder = .name
    @State private var showingFilters = false
    @State private var selectedClient: Client?
    @State private var searchTask: Task<Void, Never>?
    @State private var showingDeleteConfirmation = false
    @State private var clientToDelete: Client?

    private var filteredClients: [Client] {
        var result = clients

        // Apply search filter (используем debouncedSearchText для оптимизации)
        if !debouncedSearchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                ($0.phone?.contains(debouncedSearchText) ?? false) ||
                ($0.email?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .recent:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            result = result.filter { client in
                client.appointments.contains { $0.date > thirtyDaysAgo }
            }
        case .frequent:
            result = result.filter { $0.appointments.count >= 3 }
        case .new:
            result = result.filter { $0.appointments.isEmpty }
        }

        // Apply sort order
        switch sortOrder {
        case .name:
            result.sort { $0.name < $1.name }
        case .visits:
            result.sort { $0.appointments.count > $1.appointments.count }
        case .recent:
            result.sort { client1, client2 in
                let date1 = client1.appointments.max(by: { $0.date < $1.date })?.date ?? .distantPast
                let date2 = client2.appointments.max(by: { $0.date < $1.date })?.date ?? .distantPast
                return date1 > date2
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar at top - always visible when we have clients
                    if !clients.isEmpty {
                        GlassSearchBar(text: $searchText, placeholder: "Search by name, phone, or email")
                            .padding(.horizontal, Design.Spacing.m)
                            .padding(.top, Design.Spacing.s)

                        // Filter chips
                        filterChipsRow
                            .padding(.horizontal, Design.Spacing.m)
                            .padding(.top, Design.Spacing.xs)

                        // Stats bar
                        statsBar
                            .padding(.horizontal, Design.Spacing.m)
                            .padding(.vertical, Design.Spacing.xs)
                    }

                    if clients.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "person.2.fill",
                            title: "No Clients Yet",
                            subtitle: "Add your first client to get started",
                            actionTitle: "Add Client",
                            action: { showingAddClient = true }
                        )
                        Spacer()
                    } else {
                        // Client list
                        RefreshableScrollView(onRefresh: {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }) {
                            LazyVStack(spacing: Design.Spacing.s) {
                                ForEach(Array(filteredClients.enumerated()), id: \.element.id) { index, client in
                                    ClientCard(client: client, onTap: {
                                        HapticManager.selection()
                                        selectedClient = client
                                    }, onDelete: {
                                        clientToDelete = client
                                        showingDeleteConfirmation = true
                                    })
                                    .animateOnAppear(delay: Double(index) * 0.05)
                                }

                                if filteredClients.isEmpty && !debouncedSearchText.isEmpty {
                                    noResultsView
                                }
                            }
                            .padding(Design.Spacing.m)
                            .padding(.bottom, 120)
                        }
                    }
                }

                // FAB - raised higher
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        GlassFAB(icon: "plus") {
                            HapticManager.impact(.medium)
                            showingAddClient = true
                        }
                        .padding(.trailing, Design.Spacing.l)
                        .padding(.bottom, 140)
                    }
                }
            }
            .navigationTitle("Clients")
            .onChange(of: searchText) { _, newValue in
                // Cancel previous task to avoid race conditions
                searchTask?.cancel()

                // Debounce поиска: обновляем debouncedSearchText через 300ms
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if searchText == newValue { // Проверяем, что значение не изменилось
                            debouncedSearchText = newValue
                        }
                    }
                }
            }
            .onAppear {
                debouncedSearchText = searchText
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .alert("Удалить клиента?", isPresented: $showingDeleteConfirmation) {
                Button("Отмена", role: .cancel) { clientToDelete = nil }
                Button("Удалить", role: .destructive) {
                    if let client = clientToDelete {
                        deleteClient(client)
                    }
                    clientToDelete = nil
                }
            } message: {
                Text("Это действие нельзя отменить. Все данные клиента будут удалены.")
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
            .sheet(item: $selectedClient) { client in
                ClientDetailView(client: client)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Sort By") {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    withAnimation { sortOrder = order }
                                    HapticManager.selection()
                                } label: {
                                    HStack {
                                        Text(order.title)
                                        Spacer()
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Design.Spacing.xs) {
                ForEach(ClientFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: countForFilter(filter)
                    ) {
                        withAnimation(Design.Animation.smooth) {
                            selectedFilter = filter
                        }
                        HapticManager.selection()
                    }
                }
            }
        }
    }

    private var statsBar: some View {
        HStack(spacing: Design.Spacing.m) {
            StatPill(value: clients.count, label: "Total")
            StatPill(value: filteredClients.count, label: "Showing")

            Spacer()

            if !debouncedSearchText.isEmpty {
                Button {
                    withAnimation { 
                        searchText = ""
                        debouncedSearchText = ""
                    }
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: Design.Spacing.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Design.Colors.textTertiary)

            Text("No results for \"\(debouncedSearchText)\"")
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textSecondary)

            Text("Try a different search term")
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.xxl)
    }

    // MARK: - Helpers

    private func countForFilter(_ filter: ClientFilter) -> Int {
        switch filter {
        case .all: return clients.count
        case .recent:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            return clients.filter { client in
                client.appointments.contains { $0.date > thirtyDaysAgo }
            }.count
        case .frequent:
            return clients.filter { $0.appointments.count >= 3 }.count
        case .new:
            return clients.filter { $0.appointments.isEmpty }.count
        }
    }

    private func deleteClient(_ client: Client) {
        HapticManager.notification(.warning)
        withAnimation {
            modelContext.delete(client)
            StatsCache.shared.invalidate() // Invalidate stats cache
        }
    }
}

// MARK: - Enums

enum ClientFilter: CaseIterable {
    case all, recent, frequent, new

    var title: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .frequent: return "Frequent"
        case .new: return "New"
        }
    }

    var icon: String {
        switch self {
        case .all: return "person.2"
        case .recent: return "clock"
        case .frequent: return "star"
        case .new: return "sparkles"
        }
    }
}

enum SortOrder: CaseIterable {
    case name, visits, recent

    var title: String {
        switch self {
        case .name: return "Name"
        case .visits: return "Most Visits"
        case .recent: return "Recently Active"
        }
    }
}

// MARK: - Components

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(Design.Typography.caption1)
                if count > 0 {
                    Text("\(count)")
                        .font(Design.Typography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Design.Colors.backgroundSecondary)
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : Design.Colors.textSecondary)
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: Design.Spacing.xxs) {
            Text("\(value)")
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
        }
    }
}

struct ClientCard: View {
    let client: Client
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

    var body: some View {
        SwipeActionCard(
            onDelete: onDelete,
            onEdit: onTap
        ) {
            Button(action: onTap) {
                HStack(spacing: Design.Spacing.m) {
                    // Avatar with loyalty badge
                    ZStack(alignment: .bottomTrailing) {
                        ClientAvatar(name: client.name, size: 50)
                        LoyaltyBadge(tier: client.loyaltyTier, size: .small)
                            .offset(x: 4, y: 4)
                    }

                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                        HStack(spacing: Design.Spacing.xs) {
                            Text(client.name)
                                .font(Design.Typography.headline)
                                .foregroundStyle(Design.Colors.textPrimary)

                            if client.loyaltyTier == .vip || client.loyaltyTier == .elite {
                                Text(client.loyaltyTier.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(client.loyaltyTier.color, in: Capsule())
                            }
                        }

                        HStack(spacing: Design.Spacing.s) {
                            if let phone = client.phone {
                                Label(phone, systemImage: "phone")
                                    .font(Design.Typography.caption1)
                                    .foregroundStyle(Design.Colors.textSecondary)
                            }

                            if let email = client.email {
                                Label(email, systemImage: "envelope")
                                    .font(Design.Typography.caption1)
                                    .foregroundStyle(Design.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Design.Spacing.xxs) {
                        HStack(spacing: Design.Spacing.xxs) {
                            Text("\(client.completedVisits)")
                                .font(Design.Typography.title3)
                                .foregroundStyle(Design.Colors.accentPrimary)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Design.Colors.accentPrimary)
                        }

                        if let lastVisit = client.lastVisitDate {
                            Text(lastVisit, style: .relative)
                                .font(Design.Typography.caption2)
                                .foregroundStyle(Design.Colors.textTertiary)
                        } else {
                            Text("New")
                                .font(Design.Typography.caption2)
                                .foregroundStyle(Design.Colors.accentSuccess)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .padding(Design.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.l)
                        .fill(Design.Colors.backgroundSecondary.opacity(0.5))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Loyalty Badge

struct LoyaltyBadge: View {
    let tier: LoyaltyTier
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 20
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 26
            case .large: return 36
            }
        }
    }

    var body: some View {
        Image(systemName: tier.icon)
            .font(.system(size: size.iconSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size.frameSize, height: size.frameSize)
            .background(tier.color, in: Circle())
            .overlay(
                Circle()
                    .stroke(Design.Colors.backgroundPrimary, lineWidth: 2)
            )
    }
}

struct ClientAvatar: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var gradientColors: [Color] {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360
        let hue2 = Double((hash + 40) % 360) / 360
        return [Color(hue: hue1, saturation: 0.6, brightness: 0.8),
                Color(hue: hue2, saturation: 0.6, brightness: 0.7)]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Design.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Client Detail View

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let client: Client

    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Header with loyalty badge
                        VStack(spacing: Design.Spacing.m) {
                            ZStack(alignment: .bottomTrailing) {
                                ClientAvatar(name: client.name, size: 100)
                                LoyaltyBadge(tier: client.loyaltyTier, size: .large)
                                    .offset(x: 8, y: 8)
                            }
                            .animateOnAppear(delay: 0.1)

                            VStack(spacing: Design.Spacing.xs) {
                                Text(client.name)
                                    .font(Design.Typography.title2)

                                // Loyalty tier label
                                HStack(spacing: Design.Spacing.xs) {
                                    Image(systemName: client.loyaltyTier.icon)
                                    Text(client.loyaltyTier.rawValue)
                                }
                                .font(Design.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(client.loyaltyTier.color)
                            }
                            .animateOnAppear(delay: 0.2)
                        }
                        .padding(.top, Design.Spacing.l)

                        // Loyalty Progress Card
                        LoyaltyProgressCard(client: client)
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.25)

                        // Contact info
                        GlassCard {
                            VStack(spacing: Design.Spacing.m) {
                                if let phone = client.phone {
                                    ContactRow(icon: "phone.fill", title: "Phone", value: phone) {
                                        if let url = InputValidator.safePhoneURL(phone) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }

                                if let email = client.email {
                                    if client.phone != nil {
                                        Divider()
                                    }
                                    ContactRow(icon: "envelope.fill", title: "Email", value: email) {
                                        if let url = InputValidator.safeEmailURL(email) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }

                                if client.phone == nil && client.email == nil {
                                    Text("No contact info")
                                        .font(Design.Typography.subheadline)
                                        .foregroundStyle(Design.Colors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .animateOnAppear(delay: 0.3)

                        // Stats
                        HStack(spacing: Design.Spacing.m) {
                            StatCard(
                                icon: "checkmark.circle.fill",
                                value: "\(client.completedVisits)",
                                label: "Completed"
                            )

                            StatCard(
                                icon: "clock",
                                value: lastVisitText,
                                label: "Last Visit"
                            )

                            StatCard(
                                icon: "dollarsign.circle.fill",
                                value: client.formattedTotalSpent,
                                label: "Total Spent"
                            )
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .animateOnAppear(delay: 0.4)

                        // Recent appointments
                        if !client.appointments.isEmpty {
                            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                                Text("Recent Appointments")
                                    .font(Design.Typography.headline)
                                    .padding(.horizontal, Design.Spacing.m)

                                ForEach(client.appointments.sorted(by: { $0.date > $1.date }).prefix(5), id: \.id) { appointment in
                                    AppointmentMiniCard(appointment: appointment)
                                        .padding(.horizontal, Design.Spacing.m)
                                }
                            }
                            .animateOnAppear(delay: 0.5)
                        }

                        // Quick actions
                        HStack(spacing: Design.Spacing.m) {
                            if let phone = client.phone {
                                QuickActionButton(icon: "phone.fill", title: "Call", color: .green) {
                                    if let url = InputValidator.safePhoneURL(phone) {
                                        UIApplication.shared.open(url)
                                    }
                                }

                                QuickActionButton(icon: "message.fill", title: "Message", color: .blue) {
                                    if let url = InputValidator.safeSMSURL(phone) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }

                            if let email = client.email {
                                QuickActionButton(icon: "envelope.fill", title: "Email", color: .orange) {
                                    if let url = InputValidator.safeEmailURL(email) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .animateOnAppear(delay: 0.6)
                    }
                    .padding(.bottom, Design.Spacing.xxl)
                }
            }
            .navigationTitle("Client Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditClientView(client: client)
            }
        }
    }

    private var lastVisitText: String {
        if let lastDate = client.lastVisitDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: lastDate, relativeTo: Date())
        }
        return "Never"
    }
}

// MARK: - Loyalty Progress Card

struct LoyaltyProgressCard: View {
    let client: Client

    var body: some View {
        GlassCard(tint: client.loyaltyTier.color.opacity(0.1)) {
            VStack(spacing: Design.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                        Text("Loyalty Status")
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textSecondary)

                        HStack(spacing: Design.Spacing.xs) {
                            Image(systemName: client.loyaltyTier.icon)
                                .foregroundStyle(client.loyaltyTier.color)
                            Text(client.loyaltyTier.rawValue)
                                .font(Design.Typography.headline)
                                .foregroundStyle(client.loyaltyTier.color)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Design.Spacing.xxs) {
                        Text("\(client.completedVisits) visits")
                            .font(Design.Typography.headline)
                            .foregroundStyle(Design.Colors.textPrimary)

                        if let toNext = client.visitsToNextTier {
                            Text("\(toNext) to next tier")
                                .font(Design.Typography.caption1)
                                .foregroundStyle(Design.Colors.textSecondary)
                        } else {
                            Text("Max tier!")
                                .font(Design.Typography.caption1)
                                .foregroundStyle(client.loyaltyTier.color)
                        }
                    }
                }

                // Progress bar
                if client.loyaltyTier != .elite {
                    LoyaltyProgressBar(client: client)
                }
            }
        }
    }
}

struct LoyaltyProgressBar: View {
    let client: Client

    private var progress: Double {
        let current = client.completedVisits
        let tier = client.loyaltyTier

        let currentMin = tier.minVisits
        let nextMin: Int
        switch tier {
        case .newbie: nextMin = LoyaltyTier.regular.minVisits
        case .regular: nextMin = LoyaltyTier.vip.minVisits
        case .vip: nextMin = LoyaltyTier.elite.minVisits
        case .elite: return 1.0
        }

        let range = nextMin - currentMin
        let prog = current - currentMin
        return min(1.0, Double(prog) / Double(range))
    }

    private var nextTier: LoyaltyTier {
        switch client.loyaltyTier {
        case .newbie: return .regular
        case .regular: return .vip
        case .vip: return .elite
        case .elite: return .elite
        }
    }

    var body: some View {
        VStack(spacing: Design.Spacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Design.Colors.backgroundSecondary)
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [client.loyaltyTier.color, nextTier.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Image(systemName: client.loyaltyTier.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(client.loyaltyTier.color)

                Spacer()

                Image(systemName: nextTier.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(nextTier.color)
            }
        }
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textTertiary)
                    Text(value)
                        .font(Design.Typography.body)
                        .foregroundStyle(Design.Colors.textPrimary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        GlassCard {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Design.Colors.accentPrimary)

                Text(value)
                    .font(Design.Typography.title3)
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(label)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AppointmentMiniCard: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Circle()
                .fill(appointment.status.color.opacity(0.2))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.service?.name ?? "Service")
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(appointment.date, style: .date)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textSecondary)
            }

            Spacer()

            Text(appointment.status.rawValue.capitalized)
                .font(Design.Typography.caption2)
                .foregroundStyle(appointment.status.color)
        }
        .padding(Design.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.s)
                .fill(Design.Colors.backgroundSecondary.opacity(0.5))
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Text(title)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Design.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.m)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Edit Client View

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    let client: Client

    @State private var name: String
    @State private var phone: String
    @State private var email: String

    init(client: Client) {
        self.client = client
        _name = State(initialValue: client.name)
        _phone = State(initialValue: client.phone ?? "")
        _email = State(initialValue: client.email ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        ClientAvatar(name: name, size: 80)
                            .padding(.top, Design.Spacing.l)

                        VStack(spacing: Design.Spacing.m) {
                            FormField(title: "Name", placeholder: "Client name", text: $name, icon: "person")
                            FormField(title: "Phone", placeholder: "+1 234 567 8900", text: $phone, icon: "phone", keyboardType: .phonePad)
                            FormField(title: "Email", placeholder: "email@example.com", text: $email, icon: "envelope", keyboardType: .emailAddress)
                        }
                        .padding(.horizontal, Design.Spacing.m)
                    }
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: "Save", style: .primary) {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var isFormValid: Bool {
        let nameValid = InputValidator.isValidName(name)
        let phoneValid = InputValidator.isValidPhone(phone)
        let emailValid = InputValidator.isValidEmail(email)
        return nameValid && phoneValid && emailValid
    }

    private func saveChanges() {
        // Validate inputs
        guard isFormValid else {
            HapticManager.notification(.error)
            return
        }

        // Sanitize inputs
        client.name = InputValidator.sanitize(name)
        client.phone = phone.isEmpty ? nil : InputValidator.sanitize(phone)
        client.email = email.isEmpty ? nil : InputValidator.sanitize(email)
        HapticManager.notification(.success)
        dismiss()
    }
}

// MARK: - Add Client View

struct AddClientView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Animated Avatar
                        ClientAvatar(name: name.isEmpty ? "?" : name, size: 80)
                            .padding(.top, Design.Spacing.l)
                            .animateOnAppear(delay: 0.1)

                        VStack(spacing: Design.Spacing.m) {
                            FormField(title: "Name", placeholder: "Client name", text: $name, icon: "person")
                                .animateOnAppear(delay: 0.2)

                            FormField(title: "Phone", placeholder: "+1 234 567 8900", text: $phone, icon: "phone", keyboardType: .phonePad)
                                .animateOnAppear(delay: 0.3)

                            FormField(title: "Email", placeholder: "email@example.com", text: $email, icon: "envelope", keyboardType: .emailAddress)
                                .animateOnAppear(delay: 0.4)
                        }
                        .padding(.horizontal, Design.Spacing.m)

                        // Tip
                        if !name.isEmpty && phone.isEmpty && email.isEmpty {
                            TipCard(
                                icon: "lightbulb.fill",
                                text: "Adding contact info helps you reach clients for appointment reminders"
                            )
                            .padding(.horizontal, Design.Spacing.m)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: "Save", style: .primary, isLoading: isLoading) {
                        saveClient()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var isFormValid: Bool {
        let nameValid = InputValidator.isValidName(name)
        let phoneValid = InputValidator.isValidPhone(phone)
        let emailValid = InputValidator.isValidEmail(email)
        return nameValid && phoneValid && emailValid
    }

    private func saveClient() {
        // Validate inputs
        guard isFormValid else {
            HapticManager.notification(.error)
            return
        }

        isLoading = true
        HapticManager.impact(.medium)

        // Sanitize inputs
        let sanitizedName = InputValidator.sanitize(name)
        let sanitizedPhone = InputValidator.sanitize(phone)
        let sanitizedEmail = InputValidator.sanitize(email)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let client = Client(
                name: sanitizedName,
                phone: sanitizedPhone.isEmpty ? nil : sanitizedPhone,
                email: sanitizedEmail.isEmpty ? nil : sanitizedEmail
            )
            modelContext.insert(client)
            StatsCache.shared.invalidate() // Invalidate stats cache
            HapticManager.notification(.success)
            dismiss()
        }
    }
}

#Preview {
    ClientsView()
        .modelContainer(for: Client.self, inMemory: true)
}
