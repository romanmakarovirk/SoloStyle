//
//  ProfileView.swift
//  SoloStyle
//
//  Master profile and services with premium UX
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var masters: [Master]
    @Query(filter: #Predicate<Service> { $0.isActive }) private var services: [Service]
    private let statsCache = StatsCache.shared

    @State private var showingEditProfile = false
    @State private var showingAddService = false
    @State private var showingShareSheet = false
    @State private var showingAnalytics = false
    @State private var showingExport = false
    @State private var copiedLink = false
    @State private var selectedService: Service?

    private var master: Master? { masters.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                RefreshableScrollView(onRefresh: {
                    statsCache.invalidate()
                    statsCache.refreshIfNeeded(context: modelContext)
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }) {
                    VStack(spacing: Design.Spacing.l) {
                        // Hero Card — avatar, name, stats
                        heroCard
                            .animateOnAppear(delay: 0.05)

                        // Earnings Dashboard
                        earningsDashboard
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.15)

                        // Quick Actions
                        quickActionsStrip
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.2)

                        // Services
                        servicesSection
                            .animateOnAppear(delay: 0.25)

                        // Work Schedule
                        if master?.workSchedule != nil {
                            workScheduleSection
                                .padding(.horizontal, Design.Spacing.m)
                                .animateOnAppear(delay: 0.3)
                        }

                        // Booking Link
                        if let master {
                            bookingLinkCard(master)
                                .padding(.horizontal, Design.Spacing.m)
                                .animateOnAppear(delay: 0.35)
                        }
                    }
                    .padding(.vertical, Design.Spacing.m)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(L.profile)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.selection()
                        showingEditProfile = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Design.Colors.accentPrimary)
                    }
                }
            }
            .onAppear {
                statsCache.refreshIfNeeded(context: modelContext)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(master: master)
            }
            .sheet(isPresented: $showingAddService) {
                AddServiceView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showingExport) {
                ExportDataView()
            }
            .sheet(item: $selectedService) { service in
                EditServiceView(service: service)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        GlassCard(tint: Color.blue.opacity(0.08)) {
            VStack(spacing: 0) {
                // Top: Avatar + Info
                HStack(spacing: Design.Spacing.m) {
                    // Avatar with online pulse
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatar(name: master?.name ?? "?", size: 80)

                        // Online status dot
                        ZStack {
                            Circle()
                                .fill(Design.Colors.accentSuccess)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(Design.Colors.backgroundPrimary, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                        Text(master?.name ?? L.yourName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Design.Colors.textPrimary)

                        if let businessName = master?.businessName, !businessName.isEmpty {
                            HStack(spacing: Design.Spacing.xxs) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 11))
                                Text(businessName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Design.Colors.textSecondary)
                        }

                        if let master {
                            HStack(spacing: Design.Spacing.xxs) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                Text("\(L.memberSince) \(master.createdAt.formatted(.dateTime.month(.abbreviated).year()))")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Design.Colors.textTertiary)
                            .padding(.top, 2)
                        }
                    }

                    Spacer()
                }

                // Divider
                Rectangle()
                    .fill(Design.Colors.textTertiary.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.vertical, Design.Spacing.m)

                // Bottom: Stats row with large numbers
                HStack(spacing: 0) {
                    heroStat(
                        value: "\(statsCache.clientCount)",
                        label: L.clients,
                        icon: "person.2.fill",
                        color: .blue
                    )

                    // Separator
                    Rectangle()
                        .fill(Design.Colors.textTertiary.opacity(0.2))
                        .frame(width: 0.5, height: 36)

                    heroStat(
                        value: "\(statsCache.appointmentCount)",
                        label: L.appointments,
                        icon: "calendar.badge.checkmark",
                        color: .green
                    )

                    // Separator
                    Rectangle()
                        .fill(Design.Colors.textTertiary.opacity(0.2))
                        .frame(width: 0.5, height: 36)

                    heroStat(
                        value: "\(services.count)",
                        label: L.services,
                        icon: "scissors",
                        color: .purple
                    )
                }
            }
        }
        .padding(.horizontal, Design.Spacing.m)
    }

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Design.Spacing.xxs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Earnings Dashboard

    private var earningsDashboard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Colors.accentSuccess)
                    Text(L.earnings)
                        .font(Design.Typography.headline)
                }
                Spacer()
            }

            HStack(spacing: Design.Spacing.s) {
                // This Month
                EarningsCard(
                    title: L.thisMonth,
                    amount: statsCache.thisMonthEarnings,
                    icon: "calendar",
                    color: .green
                )

                // This Year
                EarningsCard(
                    title: L.thisYear,
                    amount: statsCache.thisYearEarnings,
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsStrip: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.quickActions)
                .font(Design.Typography.headline)

            HStack(spacing: Design.Spacing.s) {
                ProfileQuickAction(icon: "chart.pie.fill", label: L.viewAnalytics, color: .orange) {
                    HapticManager.impact(.light)
                    showingAnalytics = true
                }

                ProfileQuickAction(icon: "square.and.arrow.up.fill", label: L.shareProfile, color: .blue) {
                    HapticManager.impact(.light)
                    if let master {
                        shareBookingLink(master)
                    }
                }

                ProfileQuickAction(icon: "doc.text.fill", label: L.exportLabel, color: .purple) {
                    HapticManager.impact(.light)
                    showingExport = true
                }
            }
        }
    }

    // MARK: - Services Section

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: "scissors")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                    Text(L.myServices)
                        .font(Design.Typography.headline)
                }

                Spacer()

                Button {
                    HapticManager.impact(.light)
                    showingAddService = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Design.Colors.accentPrimary)
                }
            }
            .padding(.horizontal, Design.Spacing.m)

            if services.isEmpty {
                emptyServicesCard
                    .padding(.horizontal, Design.Spacing.m)
            } else {
                VStack(spacing: Design.Spacing.xs) {
                    ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                        ServiceListItem(service: service) {
                            HapticManager.selection()
                            selectedService = service
                        }
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
            }
        }
    }

    private var emptyServicesCard: some View {
        GlassCard(tint: Color.purple.opacity(0.05)) {
            VStack(spacing: Design.Spacing.m) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "scissors")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.purple.opacity(0.5))
                }

                VStack(spacing: Design.Spacing.xxs) {
                    Text(L.noServicesYet)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Design.Colors.textSecondary)

                    Text(L.addServicesClients)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    HapticManager.impact(.medium)
                    showingAddService = true
                } label: {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L.addService)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Design.Spacing.l)
                    .padding(.vertical, Design.Spacing.s)
                    .background(Design.Colors.accentPrimary, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.s)
        }
    }

    // MARK: - Work Schedule

    private var workScheduleSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack(spacing: Design.Spacing.xs) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(L.workSchedule)
                    .font(Design.Typography.headline)
            }

            if let schedule = master?.workSchedule {
                GlassCard(tint: Color.orange.opacity(0.05), padding: Design.Spacing.s) {
                    VStack(spacing: Design.Spacing.xxs) {
                        ScheduleDayBar(day: "Пн", start: schedule.mondayStart, end: schedule.mondayEnd, isOff: false)
                        ScheduleDayBar(day: "Вт", start: schedule.tuesdayStart, end: schedule.tuesdayEnd, isOff: false)
                        ScheduleDayBar(day: "Ср", start: schedule.wednesdayStart, end: schedule.wednesdayEnd, isOff: false)
                        ScheduleDayBar(day: "Чт", start: schedule.thursdayStart, end: schedule.thursdayEnd, isOff: false)
                        ScheduleDayBar(day: "Пт", start: schedule.fridayStart, end: schedule.fridayEnd, isOff: false)
                        ScheduleDayBar(day: "Сб", start: schedule.saturdayStart, end: schedule.saturdayEnd, isOff: false)
                        ScheduleDayBar(day: "Вс", start: 0, end: 0, isOff: schedule.sundayOff)
                    }
                }
            }
        }
    }

    // MARK: - Booking Link

    private func bookingLinkCard(_ master: Master) -> some View {
        GlassCard(tint: Color.green.opacity(0.08)) {
            VStack(spacing: Design.Spacing.m) {
                HStack(spacing: Design.Spacing.s) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Design.Colors.accentSuccess)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.bookingLink)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Design.Colors.textPrimary)
                        Text(L.shareWithClients)
                            .font(.system(size: 12))
                            .foregroundStyle(Design.Colors.textSecondary)
                    }

                    Spacer()

                    if copiedLink {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Design.Colors.accentSuccess)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Link display
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Colors.textTertiary)
                    Text("solostyle.app/book/\(master.publicSlug)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Design.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(Design.Spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.s)
                        .fill(Design.Colors.backgroundPrimary.opacity(0.5))
                )

                // Action buttons
                HStack(spacing: Design.Spacing.s) {
                    Button {
                        copyBookingLink(master)
                    } label: {
                        HStack(spacing: Design.Spacing.xs) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .medium))
                            Text(L.copyLink)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Design.Colors.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.s)
                        .soloGlass(tint: Color.blue.opacity(0.1), interactive: true, shape: .capsule)
                    }

                    Button {
                        shareBookingLink(master)
                    } label: {
                        HStack(spacing: Design.Spacing.xs) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium))
                            Text(L.share)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.s)
                        .background(Design.Colors.accentSuccess, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func copyBookingLink(_ master: Master) {
        UIPasteboard.general.string = "https://solostyle.app/book/\(master.publicSlug)"
        HapticManager.notification(.success)
        withAnimation(Design.Animation.smooth) {
            copiedLink = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(Design.Animation.smooth) {
                copiedLink = false
            }
        }
    }

    private func shareBookingLink(_ master: Master) {
        HapticManager.impact(.medium)
        showingShareSheet = true
    }
}

// MARK: - Profile Quick Action Button

struct ProfileQuickAction: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Design.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.m)
            .soloGlass(tint: color.opacity(0.08), interactive: true, shape: .roundedRect(Design.Radius.l))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Schedule Day Bar

struct ScheduleDayBar: View {
    let day: String
    let start: Int
    let end: Int
    let isOff: Bool

    var body: some View {
        HStack(spacing: Design.Spacing.s) {
            Text(day)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isOff ? Design.Colors.textTertiary : Design.Colors.textPrimary)
                .frame(width: 24, alignment: .leading)

            if isOff {
                Capsule()
                    .fill(Design.Colors.textTertiary.opacity(0.15))
                    .frame(height: 8)
                    .overlay(alignment: .center) {
                        Text(L.closed)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
            } else {
                // Visual time bar (0-24h range)
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let barStart = totalWidth * CGFloat(start) / 24.0
                    let barWidth = totalWidth * CGFloat(end - start) / 24.0

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Design.Colors.textTertiary.opacity(0.1))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(barWidth, 4), height: 8)
                            .offset(x: barStart)
                    }
                }
                .frame(height: 8)

                Text("\(start):00–\(end):00")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Design.Colors.textSecondary)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Earnings Card

struct EarningsCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color

    private var formattedAmount: String {
        CurrencyFormat.localized.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    var body: some View {
        GlassCard(tint: color.opacity(0.08), padding: Design.Spacing.m) {
            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .soloGlass(tint: color.opacity(0.15), shape: .circle)

                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Design.Colors.textSecondary)
                }

                Text(formattedAmount)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Service List Item

struct ServiceListItem: View {
    let service: Service
    let onTap: () -> Void

    // Deterministic color based on service name
    private var serviceColor: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .green, .red, .indigo]
        return palette[abs(service.name.hashValue) % palette.count]
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Design.Spacing.m) {
                // Colored icon
                Image(systemName: "scissors")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(serviceColor)
                    .frame(width: 40, height: 40)
                    .soloGlass(tint: serviceColor.opacity(0.15), shape: .roundedRect(Design.Radius.m))

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)

                    HStack(spacing: Design.Spacing.xs) {
                        Label(service.formattedDuration, systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }

                Spacer()

                // Price
                Text(service.formattedPrice)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(serviceColor)

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

// MARK: - Profile Avatar

// ProfileAvatar is defined in GlassComponents.swift with Liquid Glass effect

// MARK: - Profile Stat Card (kept for potential external use)

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        GlassCard(padding: Design.Spacing.s) {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(value)
                    .font(Design.Typography.title3)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text(label)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Service Card

struct ServiceCard: View {
    let service: Service
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Design.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "scissors")
                        .font(.system(size: 20))
                        .foregroundStyle(Design.Colors.accentPrimary)
                }

                VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                    Text(service.name)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Design.Spacing.xs) {
                        Label(service.formattedDuration, systemImage: "clock")
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textSecondary)
                    }
                }

                Spacer()

                Text(service.formattedPrice)
                    .font(Design.Typography.title3)
                    .foregroundStyle(Design.Colors.accentPrimary)
            }
            .padding(Design.Spacing.m)
            .frame(width: 150, height: 160)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.l)
                    .fill(Design.Colors.backgroundSecondary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.l)
                    .stroke(Design.Colors.glassTint, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Empty Services Card

struct EmptyServicesCard: View {
    let onAdd: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: Design.Spacing.m) {
                Image(systemName: "scissors")
                    .font(.system(size: 40))
                    .foregroundStyle(Design.Colors.textTertiary)

                Text(L.noServicesYet)
                    .font(Design.Typography.headline)
                    .foregroundStyle(Design.Colors.textSecondary)

                Text(L.addServicesClients)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                GlassButton(title: L.addService, icon: "plus") {
                    onAdd()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Design.Spacing.m)
        }
    }
}

// MARK: - Add Service Card

struct AddServiceCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            onTap()
        }) {
            VStack(spacing: Design.Spacing.s) {
                ZStack {
                    Circle()
                        .stroke(Design.Colors.accentPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Design.Colors.accentPrimary)
                }

                Text(L.addService)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.accentPrimary)
            }
            .frame(width: 150, height: 160)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.l)
                    .stroke(Design.Colors.accentPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Work Day Row

enum DayOfWeek: String, CaseIterable {
    case monday = "Mon"
    case tuesday = "Tue"
    case wednesday = "Wed"
    case thursday = "Thu"
    case friday = "Fri"
    case saturday = "Sat"
    case sunday = "Sun"

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

struct WorkDayRow: View {
    let day: DayOfWeek
    let isWorking: Bool

    var body: some View {
        HStack {
            Text(L.dayName(day.fullName))
                .font(Design.Typography.body)
                .foregroundStyle(isWorking ? Design.Colors.textPrimary : Design.Colors.textTertiary)

            Spacer()

            if isWorking {
                Text("9:00 AM - 6:00 PM")
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textSecondary)
            } else {
                Text(L.closed)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textTertiary)
            }

            Circle()
                .fill(isWorking ? Design.Colors.accentSuccess : Design.Colors.textTertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, Design.Spacing.xxs)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let master: Master?

    @State private var name = ""
    @State private var businessName = ""
    @State private var isLoading = false
    @State private var showingImagePicker = false
    @State private var showingPhotoOptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Avatar
                        ProfileAvatar(name: name.isEmpty ? "?" : name, size: 100)
                            .padding(.top, Design.Spacing.l)
                            .animateOnAppear(delay: 0.1)

                        Button {
                            HapticManager.selection()
                            showingPhotoOptions = true
                        } label: {
                            Label(L.changePhoto, systemImage: "camera.fill")
                                .font(Design.Typography.subheadline)
                                .foregroundStyle(Design.Colors.accentPrimary)
                        }
                        .animateOnAppear(delay: 0.2)
                        .confirmationDialog(L.choosePhoto, isPresented: $showingPhotoOptions) {
                            Button(L.takePhoto) {
                                HapticManager.selection()
                                showingImagePicker = true
                            }
                            Button(L.chooseFromLibrary) {
                                HapticManager.selection()
                                showingImagePicker = true
                            }
                            Button(L.cancel, role: .cancel) {}
                        }

                        VStack(spacing: Design.Spacing.m) {
                            FormField(title: L.name, placeholder: L.yourNamePlaceholder, text: $name, icon: "person")
                                .animateOnAppear(delay: 0.3)

                            FormField(title: L.businessName, placeholder: L.businessNameOptional, text: $businessName, icon: "building.2")
                                .animateOnAppear(delay: 0.4)
                        }
                        .padding(.horizontal, Design.Spacing.m)
                    }
                }
            }
            .navigationTitle(master == nil ? L.createProfile : L.editProfile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: L.save, style: .primary, isLoading: isLoading) {
                        saveProfile()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let master {
                    name = master.name
                    businessName = master.businessName ?? ""
                }
            }
        }
    }

    private func saveProfile() {
        guard InputValidator.isValidName(name) else {
            HapticManager.notification(.error)
            return
        }

        isLoading = true
        HapticManager.impact(.medium)

        let sanitizedName = InputValidator.sanitize(name)
        let sanitizedBusinessName = InputValidator.sanitize(businessName)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let master {
                master.name = sanitizedName
                master.businessName = sanitizedBusinessName.isEmpty ? nil : sanitizedBusinessName
            } else {
                let newMaster = Master(name: sanitizedName, businessName: sanitizedBusinessName.isEmpty ? nil : sanitizedBusinessName)
                modelContext.insert(newMaster)
            }
            HapticManager.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Add Service View

struct AddServiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var price = ""
    @State private var duration = 30
    @State private var isLoading = false

    private let durations = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Service preview
                        ServicePreviewCard(name: name, price: price, duration: duration)
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.1)

                        VStack(spacing: Design.Spacing.m) {
                            FormField(title: L.serviceName, placeholder: L.serviceNamePlaceholder, text: $name, icon: "scissors")
                                .animateOnAppear(delay: 0.2)

                            FormField(title: L.priceField, placeholder: "30", text: $price, icon: "dollarsign", keyboardType: .decimalPad)
                                .animateOnAppear(delay: 0.3)

                            // Duration picker
                            VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                                Text(L.duration)
                                    .font(Design.Typography.caption1)
                                    .foregroundStyle(Design.Colors.textSecondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: Design.Spacing.xs) {
                                    ForEach(durations, id: \.self) { mins in
                                        DurationChip(
                                            minutes: mins,
                                            isSelected: duration == mins
                                        ) {
                                            withAnimation(Design.Animation.smooth) {
                                                duration = mins
                                            }
                                            HapticManager.selection()
                                        }
                                    }
                                }
                            }
                            .animateOnAppear(delay: 0.4)
                        }
                        .padding(.horizontal, Design.Spacing.m)
                    }
                    .padding(.top, Design.Spacing.m)
                }
            }
            .navigationTitle(L.addService)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: L.save, style: .primary, isLoading: isLoading) {
                        saveService()
                    }
                    .disabled(name.isEmpty || price.isEmpty)
                }
            }
        }
    }

    private func saveService() {
        guard InputValidator.isValidName(name) else {
            HapticManager.notification(.error)
            return
        }
        guard InputValidator.isValidPrice(price), let priceValue = Decimal(string: price) else {
            HapticManager.notification(.error)
            return
        }

        isLoading = true
        HapticManager.impact(.medium)

        let sanitizedName = InputValidator.sanitize(name)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let service = Service(name: sanitizedName, price: priceValue, duration: duration)
            modelContext.insert(service)
            StatsCache.shared.invalidate()
            HapticManager.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Service Preview Card

struct ServicePreviewCard: View {
    let name: String
    let price: String
    let duration: Int

    var body: some View {
        GlassCard(tint: Color.purple.opacity(0.1)) {
            VStack(spacing: Design.Spacing.s) {
                Text(L.preview)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textTertiary)

                HStack {
                    ZStack {
                        Circle()
                            .fill(Design.Colors.accentPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "scissors")
                            .font(.system(size: 20))
                            .foregroundStyle(Design.Colors.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? L.serviceName : name)
                            .font(Design.Typography.headline)
                            .foregroundStyle(name.isEmpty ? Design.Colors.textTertiary : Design.Colors.textPrimary)

                        Text(durationText)
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textSecondary)
                    }

                    Spacer()

                    Text(priceText)
                        .font(Design.Typography.title3)
                        .foregroundStyle(Design.Colors.accentPrimary)
                }
            }
        }
    }

    private var durationText: String {
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(duration) min"
    }

    private var priceText: String {
        if let value = Decimal(string: price) {
            return "$\(value)"
        }
        return "$0"
    }
}

// MARK: - Duration Chip

struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(displayText)
                .font(Design.Typography.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Design.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.m)
                        .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
                )
        }
        .buttonStyle(.plain)
    }

    private var displayText: String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Edit Service View

struct EditServiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let service: Service

    @State private var name: String
    @State private var price: String
    @State private var duration: Int
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false

    private let durations = [15, 30, 45, 60, 90, 120]

    init(service: Service) {
        self.service = service
        _name = State(initialValue: service.name)
        _price = State(initialValue: "\(service.price)")
        _duration = State(initialValue: service.duration)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        ServicePreviewCard(name: name, price: price, duration: duration)
                            .padding(.horizontal, Design.Spacing.m)

                        VStack(spacing: Design.Spacing.m) {
                            FormField(title: L.serviceName, placeholder: L.serviceNamePlaceholder, text: $name, icon: "scissors")

                            FormField(title: L.priceField, placeholder: "30", text: $price, icon: "dollarsign", keyboardType: .decimalPad)

                            VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                                Text(L.duration)
                                    .font(Design.Typography.caption1)
                                    .foregroundStyle(Design.Colors.textSecondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: Design.Spacing.xs) {
                                    ForEach(durations, id: \.self) { mins in
                                        DurationChip(
                                            minutes: mins,
                                            isSelected: duration == mins
                                        ) {
                                            withAnimation(Design.Animation.smooth) {
                                                duration = mins
                                            }
                                            HapticManager.selection()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)

                        // Delete button
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L.deleteService, systemImage: "trash")
                                .font(Design.Typography.body)
                                .foregroundStyle(Design.Colors.accentError)
                        }
                        .padding(.top, Design.Spacing.l)
                    }
                    .padding(.top, Design.Spacing.m)
                }
            }
            .navigationTitle(L.editService)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: L.save, style: .primary, isLoading: isLoading) {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || price.isEmpty)
                }
            }
            .alert(L.deleteServiceQ, isPresented: $showingDeleteConfirmation) {
                Button(L.cancel, role: .cancel) { }
                Button(L.delete, role: .destructive) {
                    deleteService()
                }
            } message: {
                Text(L.actionCannotBeUndone)
            }
        }
    }

    private func saveChanges() {
        guard InputValidator.isValidName(name) else {
            HapticManager.notification(.error)
            return
        }
        guard InputValidator.isValidPrice(price), let priceValue = Decimal(string: price) else {
            HapticManager.notification(.error)
            return
        }

        isLoading = true
        HapticManager.impact(.medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            service.name = InputValidator.sanitize(name)
            service.price = priceValue
            service.duration = duration
            HapticManager.notification(.success)
            dismiss()
        }
    }

    private func deleteService() {
        HapticManager.notification(.warning)
        modelContext.delete(service)
        StatsCache.shared.invalidate()
        dismiss()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Master.self, Service.self], inMemory: true)
}
