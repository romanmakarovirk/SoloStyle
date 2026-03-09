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
                        GlassSearchBar(text: $searchText, placeholder: L.searchByNamePhoneEmail)
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
                        EmptyStateView(
                            icon: "person.2.fill",
                            title: L.noClientsYet,
                            subtitle: L.addFirstClient,
                            actionTitle: L.addClient,
                            action: { showingAddClient = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(y: -40)
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
            .navigationTitle(L.clients)
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
            .alert(L.deleteClient, isPresented: $showingDeleteConfirmation) {
                Button(L.cancel, role: .cancel) { clientToDelete = nil }
                Button(L.delete, role: .destructive) {
                    if let client = clientToDelete {
                        deleteClient(client)
                    }
                    clientToDelete = nil
                }
            } message: {
                Text(L.deleteClientMessage)
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
                        Section(L.sortBy) {
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
        // Compute all filter counts in one pass instead of 4 separate filters
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        var recentCount = 0, frequentCount = 0, newCount = 0
        for c in clients {
            if c.appointments.isEmpty { newCount += 1 }
            if c.appointments.count >= 3 { frequentCount += 1 }
            if c.appointments.contains(where: { $0.date > thirtyDaysAgo }) { recentCount += 1 }
        }
        let counts: [ClientFilter: Int] = [.all: clients.count, .recent: recentCount, .frequent: frequentCount, .new: newCount]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Design.Spacing.xs) {
                ForEach(ClientFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: counts[filter] ?? 0
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
            StatPill(value: clients.count, label: L.total)
            StatPill(value: filteredClients.count, label: L.showing)

            Spacer()

            if !debouncedSearchText.isEmpty {
                Button {
                    withAnimation { 
                        searchText = ""
                        debouncedSearchText = ""
                    }
                } label: {
                    Label(L.clear, systemImage: "xmark.circle.fill")
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }
            }
        }
    }

    private var noResultsView: some View {
        GlassCard(tint: Color.white.opacity(0.05)) {
            VStack(spacing: Design.Spacing.m) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Design.Colors.textTertiary)

                Text(L.noResultsFor(debouncedSearchText))
                    .font(Design.Typography.headline)
                    .foregroundStyle(Design.Colors.textSecondary)

                Text(L.tryDifferentSearch)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.l)
        }
    }

    // MARK: - Helpers

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
        case .all: return L.filterAll
        case .recent: return L.filterRecent
        case .frequent: return L.filterFrequent
        case .new: return L.filterNew
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
        case .name: return L.sortName
        case .visits: return L.sortMostVisits
        case .recent: return L.sortRecentlyActive
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
                                .fill(Color.white.opacity(isSelected ? 0.25 : 0.12))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : Design.Colors.textSecondary)
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.xs)
            .soloGlass(tint: isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), shape: .capsule)
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
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.xxs)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .capsule)
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
                            Text(L.newLabel)
                                .font(Design.Typography.caption2)
                                .foregroundStyle(Design.Colors.accentSuccess)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .padding(Design.Spacing.s)
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
            .soloGlass(tint: tier.color.opacity(0.7), shape: .circle)
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
                                    ContactRow(icon: "phone.fill", title: L.phone, value: phone) {
                                        if let url = InputValidator.safePhoneURL(phone) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }

                                if let email = client.email {
                                    if client.phone != nil {
                                        Divider()
                                    }
                                    ContactRow(icon: "envelope.fill", title: L.email, value: email) {
                                        if let url = InputValidator.safeEmailURL(email) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }

                                if client.phone == nil && client.email == nil {
                                    Text(L.noContactInfo)
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
                                label: L.completed
                            )

                            StatCard(
                                icon: "clock",
                                value: lastVisitText,
                                label: L.lastVisit
                            )

                            StatCard(
                                icon: "dollarsign.circle.fill",
                                value: client.formattedTotalSpent,
                                label: L.totalSpent
                            )
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .animateOnAppear(delay: 0.4)

                        // Recent appointments
                        if !client.appointments.isEmpty {
                            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                                Text(L.recentAppointments)
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
                                QuickActionButton(icon: "phone.fill", title: L.call, color: .green) {
                                    if let url = InputValidator.safePhoneURL(phone) {
                                        UIApplication.shared.open(url)
                                    }
                                }

                                QuickActionButton(icon: "message.fill", title: L.message, color: .blue) {
                                    if let url = InputValidator.safeSMSURL(phone) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }

                            if let email = client.email {
                                QuickActionButton(icon: "envelope.fill", title: L.email, color: .orange) {
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
            .navigationTitle(L.clientDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
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
        return L.never
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
                        Text(L.loyaltyStatus)
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
                        Text("\(client.completedVisits) \(L.visits)")
                            .font(Design.Typography.headline)
                            .foregroundStyle(Design.Colors.textPrimary)

                        if let toNext = client.visitsToNextTier {
                            Text(L.toNextTier(toNext))
                                .font(Design.Typography.caption1)
                                .foregroundStyle(Design.Colors.textSecondary)
                        } else {
                            Text(L.maxTier)
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
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.s))
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
            .soloGlass(tint: color.opacity(0.1), interactive: true, shape: .roundedRect(Design.Radius.m))
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
                            FormField(title: L.name, placeholder: L.clientName, text: $name, icon: "person")
                            FormField(title: L.phone, placeholder: L.phonePlaceholder, text: $phone, icon: "phone", keyboardType: .phonePad)
                            FormField(title: L.email, placeholder: L.emailPlaceholder, text: $email, icon: "envelope", keyboardType: .emailAddress)
                        }
                        .padding(.horizontal, Design.Spacing.m)
                    }
                }
            }
            .navigationTitle(L.editClient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: L.save, style: .primary) {
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
                            FormField(title: L.name, placeholder: L.clientName, text: $name, icon: "person")
                                .animateOnAppear(delay: 0.2)

                            FormField(title: L.phone, placeholder: L.phonePlaceholder, text: $phone, icon: "phone", keyboardType: .phonePad)
                                .animateOnAppear(delay: 0.3)

                            FormField(title: L.email, placeholder: L.emailPlaceholder, text: $email, icon: "envelope", keyboardType: .emailAddress)
                                .animateOnAppear(delay: 0.4)
                        }
                        .padding(.horizontal, Design.Spacing.m)

                        // Tip
                        if !name.isEmpty && phone.isEmpty && email.isEmpty {
                            TipCard(
                                icon: "lightbulb.fill",
                                text: L.contactInfoTip
                            )
                            .padding(.horizontal, Design.Spacing.m)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationTitle(L.newClient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: L.save, style: .primary, isLoading: isLoading) {
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
