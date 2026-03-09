//
//  ClientMainView.swift
//  SoloStyle
//
//  Simplified client interface — AI search, bookings, profile
//

import SwiftUI

// MARK: - Client Tab

enum ClientTab: String, CaseIterable, Identifiable {
    case search
    case bookings
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: L.tabSearch
        case .bookings: L.tabMyBookings
        case .profile: L.tabProfile
        }
    }

    var icon: String {
        switch self {
        case .search: "sparkles"
        case .bookings: "calendar"
        case .profile: "person.circle"
        }
    }
}

// MARK: - Client Main View

struct ClientMainView: View {
    @State private var selectedTab: ClientTab = .search
    @State private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()

            // Content
            ZStack {
                ClientSearchTab()
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)

                ClientBookingsTab()
                    .opacity(selectedTab == .bookings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .bookings)

                ClientProfileTab()
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }

            // Tab bar
            VStack {
                Spacer()
                ClientTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - Client Tab Bar

private struct ClientTabBar: View {
    @Binding var selectedTab: ClientTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ClientTab.allCases) { tab in
                Button {
                    HapticManager.selection()
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)

                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.s)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.bottom, Design.Spacing.xs)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.xl))
        .padding(.horizontal, Design.Spacing.m)
        .padding(.bottom, Design.Spacing.xs)
    }
}

// MARK: - Search Tab (AI-powered)

private struct ClientSearchTab: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [MasterResult] = []
    @State private var aiAnswer: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.l) {
                // Header
                VStack(spacing: Design.Spacing.xs) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(Design.Colors.accentPrimary)
                        Text(L.aiAssistant)
                            .font(Design.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    Text(L.findMasterSubtitle)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Design.Spacing.l)
                .padding(.top, Design.Spacing.xl)

                // Search input
                HStack(spacing: Design.Spacing.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Design.Colors.textTertiary)

                    TextField(L.describeService, text: $searchText)
                        .foregroundStyle(.white)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }

                    if isSearching {
                        ProgressView()
                            .tint(.white)
                    } else if !searchText.isEmpty {
                        Button {
                            performSearch()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Design.Colors.accentPrimary)
                        }
                    }
                }
                .padding(Design.Spacing.m)
                .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
                .padding(.horizontal, Design.Spacing.l)

                // AI Answer
                if let answer = aiAnswer {
                    VStack(alignment: .leading, spacing: Design.Spacing.s) {
                        HStack(spacing: Design.Spacing.xs) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Design.Colors.accentPrimary)
                            Text(L.aiAssistant)
                                .font(Design.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }

                        Text(answer)
                            .font(Design.Typography.body)
                            .foregroundStyle(Design.Colors.textSecondary)
                    }
                    .padding(Design.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .soloGlass(tint: Color.blue.opacity(0.05), shape: .roundedRect(Design.Radius.l))
                    .padding(.horizontal, Design.Spacing.l)
                }

                // Results
                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: Design.Spacing.s) {
                        Text(L.foundMasters)
                            .font(Design.Typography.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Design.Spacing.l)

                        ForEach(searchResults) { master in
                            ClientMasterCard(master: master)
                                .padding(.horizontal, Design.Spacing.l)
                        }
                    }
                }

                // Quick suggestions when empty
                if searchResults.isEmpty && aiAnswer == nil {
                    VStack(spacing: Design.Spacing.m) {
                        Text(L.popularQueries)
                            .font(Design.Typography.subheadline)
                            .foregroundStyle(Design.Colors.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Design.Spacing.s) {
                            QuickSearchChip(text: "💇 \(L.queryHaircut)") { searchText = L.queryHaircut; performSearch() }
                            QuickSearchChip(text: "💅 \(L.queryManicure)") { searchText = L.queryManicure; performSearch() }
                            QuickSearchChip(text: "💆 \(L.queryMassage)") { searchText = L.queryMassage; performSearch() }
                            QuickSearchChip(text: "🧴 \(L.querySkincare)") { searchText = L.querySkincare; performSearch() }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.l)
                    .padding(.top, Design.Spacing.xl)
                }

                // Bottom padding for tab bar
                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        aiAnswer = nil
        searchResults = []

        Task {
            do {
                let response = try await NetworkManager.shared.searchMasters(
                    query: searchText,
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude
                )
                aiAnswer = response.answer
                searchResults = response.masters
            } catch {
                aiAnswer = L.authError
            }
            isSearching = false
        }
    }
}

// MARK: - Quick Search Chip

private struct QuickSearchChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Design.Typography.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Spacing.s)
                .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.m))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Master Result Card (Client view)

private struct ClientMasterCard: View {
    let master: MasterResult

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(master.masterName)
                        .font(Design.Typography.headline)
                        .foregroundStyle(.white)

                    Text(master.serviceName)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.accentPrimary)
                }

                Spacer()

                Text(master.formattedPrice)
                    .font(Design.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            HStack(spacing: Design.Spacing.m) {
                Label(master.formattedDistance, systemImage: "location")
                Label("⭐ \(String(format: "%.1f", master.rating))", systemImage: "")
                Label(L.yearsExp(master.experience), systemImage: "briefcase")
            }
            .font(Design.Typography.caption1)
            .foregroundStyle(Design.Colors.textTertiary)

            // Book button
            Button {
                // TODO: Open booking sheet
                HapticManager.selection()
            } label: {
                Text(L.bookAppointment)
                    .font(Design.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.s)
                    .background(Design.Colors.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Design.Radius.m))
            }
            .buttonStyle(.plain)
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.l))
    }
}

// MARK: - Bookings Tab

private struct ClientBookingsTab: View {
    var body: some View {
        VStack(spacing: Design.Spacing.l) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(Design.Colors.textTertiary)

            Text(L.noUpcomingAppointments)
                .font(Design.Typography.headline)
                .foregroundStyle(.white)

            Text(L.clientBookingsHint)
                .font(Design.Typography.body)
                .foregroundStyle(Design.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Profile Tab

private struct ClientProfileTab: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.l) {
                // Avatar & Name
                VStack(spacing: Design.Spacing.m) {
                    // Telegram avatar
                    if let photoUrl = authManager.currentUser?.photoUrl,
                       let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            profilePlaceholder
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        profilePlaceholder
                    }

                    VStack(spacing: 4) {
                        Text(authManager.currentUser?.firstName ?? "")
                            .font(Design.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        if let username = authManager.currentUser?.username {
                            Text("@\(username)")
                                .font(Design.Typography.subheadline)
                                .foregroundStyle(Design.Colors.textTertiary)
                        }
                    }
                }
                .padding(.top, 60)

                // Role badge
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: "sparkles")
                    Text(L.roleClient)
                }
                .font(Design.Typography.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal, Design.Spacing.m)
                .padding(.vertical, Design.Spacing.xs)
                .soloGlass(tint: Color.orange.opacity(0.1), shape: .capsule)

                Spacer(minLength: Design.Spacing.xl)

                // Logout
                Button {
                    authManager.logout()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(L.logout)
                    }
                    .font(Design.Typography.body)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.m)
                    .soloGlass(tint: Color.red.opacity(0.05), shape: .roundedRect(Design.Radius.l))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Design.Spacing.l)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Design.Colors.accentPrimary.opacity(0.2))
                .frame(width: 80, height: 80)

            Text(String((authManager.currentUser?.firstName ?? "?").prefix(1)))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Design.Colors.accentPrimary)
        }
    }
}
