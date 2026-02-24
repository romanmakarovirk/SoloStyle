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
    @State private var copiedLink = false
    @State private var selectedService: Service?

    private var master: Master? { masters.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                RefreshableScrollView(onRefresh: {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }) {
                    VStack(spacing: Design.Spacing.l) {
                        // Profile Header with parallax
                        profileHeader
                            .animateOnAppear(delay: 0.1)

                        // Stats row
                        statsRow
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.2)

                        // Earnings Dashboard
                        earningsSection
                            .padding(.horizontal, Design.Spacing.m)
                            .animateOnAppear(delay: 0.3)

                        // Services
                        servicesSection
                            .animateOnAppear(delay: 0.4)
                    }
                    .padding(.vertical, Design.Spacing.m)
                    .padding(.bottom, Design.Spacing.xxl)
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
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(master: master)
            }
            .sheet(isPresented: $showingAddService) {
                AddServiceView()
            }
            .sheet(item: $selectedService) { service in
                EditServiceView(service: service)
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        GlassCard(tint: Color.blue.opacity(0.1)) {
            VStack(spacing: Design.Spacing.m) {
                // Avatar with status
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(name: master?.name ?? "?", size: 100)

                    // Online status
                    Circle()
                        .fill(Design.Colors.accentSuccess)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Design.Colors.backgroundPrimary, lineWidth: 3)
                        )
                }

                VStack(spacing: Design.Spacing.xxs) {
                    Text(master?.name ?? L.yourName)
                        .font(Design.Typography.title2)
                        .foregroundStyle(Design.Colors.textPrimary)

                    if let businessName = master?.businessName {
                        HStack(spacing: Design.Spacing.xxs) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 12))
                            Text(businessName)
                        }
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textSecondary)
                    }
                }

            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Design.Spacing.m)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Design.Spacing.s) {
            ProfileStatCard(
                icon: "person.2.fill",
                value: "\(statsCache.clientCount)",
                label: L.clients,
                color: .blue
            )

            ProfileStatCard(
                icon: "calendar.badge.checkmark",
                value: "\(statsCache.appointmentCount)",
                label: L.appointments,
                color: .green
            )

            ProfileStatCard(
                icon: "scissors",
                value: "\(services.count)",
                label: L.services,
                color: .purple
            )
        }
        .onAppear {
            statsCache.refreshIfNeeded(context: modelContext)
        }
    }

    // MARK: - Earnings Section

    private var earningsSection: some View {
        VStack(spacing: Design.Spacing.s) {
            HStack {
                Text(L.earnings)
                    .font(Design.Typography.headline)
                Spacer()
            }

            HStack(spacing: Design.Spacing.s) {
                EarningsCard(
                    title: L.thisMonth,
                    amount: statsCache.thisMonthEarnings,
                    icon: "calendar",
                    color: .green
                )

                EarningsCard(
                    title: L.thisYear,
                    amount: statsCache.thisYearEarnings,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Booking Link

    private func bookingLinkCard(_ master: Master) -> some View {
        GlassCard(tint: Color.green.opacity(0.1)) {
            VStack(spacing: Design.Spacing.m) {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Design.Colors.accentSuccess)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.bookingLink)
                            .font(Design.Typography.headline)
                        Text(L.shareWithClients)
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textSecondary)
                    }

                    Spacer()
                }

                // Link display
                HStack {
                    Text("solostyle.app/book/\(master.publicSlug)")
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if copiedLink {
                        Label(L.copied, systemImage: "checkmark.circle.fill")
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.accentSuccess)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(Design.Spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.s)
                        .fill(Design.Colors.backgroundSecondary)
                )

                // Action buttons
                HStack(spacing: Design.Spacing.s) {
                    GlassButton(title: L.copyLink, icon: "doc.on.doc", style: .secondary, isFullWidth: true) {
                        copyBookingLink(master)
                    }

                    GlassButton(title: L.share, icon: "square.and.arrow.up", isFullWidth: true) {
                        shareBookingLink(master)
                    }
                }
            }
        }
    }

    private func copyBookingLink(_ master: Master) {
        UIPasteboard.general.string = "https://solostyle.app/book/\(master.publicSlug)"
        HapticManager.notification(.success)
        withAnimation {
            copiedLink = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedLink = false
            }
        }
    }

    private func shareBookingLink(_ master: Master) {
        HapticManager.impact(.medium)
        showingShareSheet = true
    }

    // MARK: - Services Section

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                Text(L.services)
                    .font(Design.Typography.headline)

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
                GlassCard(tint: Color.purple.opacity(0.05)) {
                    VStack(spacing: Design.Spacing.m) {
                        Image(systemName: "scissors")
                            .font(.system(size: 32))
                            .foregroundStyle(Design.Colors.textTertiary)

                        Text(L.noServicesYet)
                            .font(Design.Typography.subheadline)
                            .foregroundStyle(Design.Colors.textSecondary)

                        Button {
                            showingAddService = true
                        } label: {
                            Text(L.addService)
                                .font(Design.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Design.Spacing.l)
                                .padding(.vertical, Design.Spacing.s)
                                .background(Design.Colors.accentPrimary, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.m)
                }
                .padding(.horizontal, Design.Spacing.m)
            } else {
                VStack(spacing: Design.Spacing.xs) {
                    ForEach(services, id: \.id) { service in
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
}

// MARK: - Earnings Card

struct EarningsCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    var body: some View {
        GlassCard(tint: color.opacity(0.1), padding: Design.Spacing.m) {
            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)

                    Text(title)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }

                Text(formattedAmount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Service List Item (New minimal design)

struct ServiceListItem: View {
    let service: Service
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Design.Spacing.m) {
                // Icon
                Circle()
                    .fill(Design.Colors.accentPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "scissors")
                            .font(.system(size: 18))
                            .foregroundStyle(Design.Colors.accentPrimary)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)

                    Text(service.formattedDuration)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textTertiary)
                }

                Spacer()

                // Price
                Text(service.formattedPrice)
                    .font(Design.Typography.headline)
                    .foregroundStyle(Design.Colors.accentPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .padding(Design.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.m)
                    .fill(Design.Colors.backgroundSecondary.opacity(0.5))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Profile Avatar

// ProfileAvatar is defined in GlassComponents.swift with Liquid Glass effect

// MARK: - Profile Stat Card

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
                                // Camera functionality requires PhotoUI integration
                                // For now, redirect to photo library
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
        // Validate name
        guard InputValidator.isValidName(name) else {
            HapticManager.notification(.error)
            return
        }

        isLoading = true
        HapticManager.impact(.medium)

        // Sanitize inputs
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
        // Validate inputs
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

        // Sanitize name
        let sanitizedName = InputValidator.sanitize(name)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let service = Service(name: sanitizedName, price: priceValue, duration: duration)
            modelContext.insert(service)
            StatsCache.shared.invalidate() // Invalidate stats cache
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
        // Validate inputs
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
        StatsCache.shared.invalidate() // Invalidate stats cache
        dismiss()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Master.self, Service.self], inMemory: true)
}
