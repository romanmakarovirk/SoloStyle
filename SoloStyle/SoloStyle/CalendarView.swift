//
//  CalendarView.swift
//  SoloStyle
//
//  Beautiful calendar with swipe gestures and animations
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appointment.date) private var appointments: [Appointment]

    @State private var selectedDate = Date()
    @State private var showingAddAppointment = false
    @State private var isAnimatingDate = false
    @State private var showingDeleteConfirmation = false
    @State private var appointmentToDelete: Appointment?

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Animated Date Header
                    dateHeader
                        .animateOnAppear()

                    // Week Strip
                    weekStrip
                        .animateOnAppear(delay: 0.1)

                    // Appointments
                    ScrollView {
                        LazyVStack(spacing: Design.Spacing.s) {
                            let todayAppointments = appointments.filter {
                                Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                            }

                            if todayAppointments.isEmpty {
                                EmptyStateView(
                                    icon: "calendar.badge.plus",
                                    title: "No appointments",
                                    subtitle: "Your schedule is clear for this day",
                                    actionTitle: "Add Appointment"
                                ) {
                                    showingAddAppointment = true
                                }
                                .animateOnAppear(delay: 0.2)
                            } else {
                                ForEach(Array(todayAppointments.enumerated()), id: \.element.id) { index, appointment in
                                    AppointmentRow(appointment: appointment, onDelete: {
                                        appointmentToDelete = appointment
                                        showingDeleteConfirmation = true
                                    })
                                    .animateOnAppear(delay: 0.1 * Double(index))
                                }
                            }
                        }
                        .padding(Design.Spacing.m)
                        .padding(.bottom, 120)
                    }
                }

                // FAB - raised higher to avoid tab bar
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        GlassFAB(icon: "plus") {
                            showingAddAppointment = true
                        }
                        .padding(.trailing, Design.Spacing.l)
                        .padding(.bottom, 140)
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddAppointment) {
                AddAppointmentView(selectedDate: selectedDate)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Удалить запись?", isPresented: $showingDeleteConfirmation) {
                Button("Отмена", role: .cancel) { appointmentToDelete = nil }
                Button("Удалить", role: .destructive) {
                    if let appointment = appointmentToDelete {
                        NotificationManager.shared.cancelReminder(for: appointment)
                        modelContext.delete(appointment)
                        StatsCache.shared.invalidate()
                    }
                    appointmentToDelete = nil
                }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            // Previous button
            GlassIconButton(icon: "chevron.left") {
                moveDate(by: -1)
            }

            Spacer()

            // Date display with animation
            VStack(spacing: Design.Spacing.xxs) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textSecondary)

                Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(Design.Typography.title2)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .contentTransition(.numericText())
            }
            .scaleEffect(isAnimatingDate ? 0.95 : 1.0)
            .opacity(isAnimatingDate ? 0.7 : 1.0)
            .onTapGesture {
                HapticManager.impact(.light)
                withAnimation(Design.Animation.smooth) {
                    selectedDate = Date()
                }
            }

            Spacer()

            // Next button
            GlassIconButton(icon: "chevron.right") {
                moveDate(by: 1)
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.s)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let days = weekDays(around: selectedDate)

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Design.Spacing.xs) {
                    ForEach(days, id: \.self) { day in
                        DayCell(
                            date: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                            hasAppointments: hasAppointments(on: day)
                        ) {
                            HapticManager.selection()
                            withAnimation(Design.Animation.smooth) {
                                selectedDate = day
                            }
                        }
                        .id(day)
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
        .padding(.vertical, Design.Spacing.s)
    }

    // MARK: - Helpers

    private func moveDate(by days: Int) {
        withAnimation(Design.Animation.quick) {
            isAnimatingDate = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Design.Animation.smooth) {
                selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
                isAnimatingDate = false
            }
        }
    }

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

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasAppointments: Bool
    let action: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Design.Spacing.xxs) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(Design.Typography.caption2)
                    .foregroundStyle(isSelected ? .white : Design.Colors.textTertiary)

                Text(date.formatted(.dateTime.day()))
                    .font(Design.Typography.headline)
                    .foregroundStyle(isSelected ? .white : (isToday ? Design.Colors.accentPrimary : Design.Colors.textPrimary))

                // Appointment indicator
                Circle()
                    .fill(hasAppointments ? (isSelected ? .white : Design.Colors.accentPrimary) : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 44, height: 70)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Design.Radius.m)
                        .fill(Design.Colors.accentPrimary)
                } else if isToday {
                    RoundedRectangle(cornerRadius: Design.Radius.m)
                        .strokeBorder(Design.Colors.accentPrimary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Design.Animation.bouncy, value: isSelected)
    }
}

// MARK: - Appointment Row

struct AppointmentRow: View {
    @Environment(\.modelContext) private var modelContext
    let appointment: Appointment
    var onDelete: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        SwipeActionCard(
            onDelete: {
                HapticManager.notification(.warning)
                onDelete?()
            },
            onEdit: {
                // Edit functionality handled by sheet
            }
        ) {
            VStack(spacing: Design.Spacing.s) {
                // Main content
                HStack(spacing: Design.Spacing.m) {
                    // Time column
                    VStack(spacing: Design.Spacing.xxs) {
                        Text(appointment.formattedTime)
                            .font(Design.Typography.headline)
                            .foregroundStyle(Design.Colors.textPrimary)

                        if let service = appointment.service {
                            Text("\(service.duration)m")
                                .font(Design.Typography.caption2)
                                .foregroundStyle(Design.Colors.textTertiary)
                        }
                    }
                    .frame(width: 60)

                    // Colored bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(statusColor)
                        .frame(width: 4)

                    // Details
                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                        Text(appointment.client?.name ?? "Unknown Client")
                            .font(Design.Typography.headline)
                            .foregroundStyle(Design.Colors.textPrimary)

                        if let service = appointment.service {
                            Text(service.name)
                                .font(Design.Typography.subheadline)
                                .foregroundStyle(Design.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Status badge
                    StatusBadge(status: appointment.status)
                }

                // Expandable details
                if isExpanded {
                    Divider()
                        .padding(.vertical, Design.Spacing.xs)

                    HStack(spacing: Design.Spacing.m) {
                        if let phone = appointment.client?.phone {
                            ActionChip(icon: "phone.fill", title: "Call") {
                                if let url = InputValidator.safePhoneURL(phone) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if let phone = appointment.client?.phone {
                            ActionChip(icon: "message.fill", title: "Message") {
                                if let url = InputValidator.safeSMSURL(phone) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if appointment.status == .scheduled {
                            ActionChip(icon: "play.fill", title: "Start") {
                                LiveActivityManager.shared.startActivity(
                                    clientName: appointment.client?.name ?? "Client",
                                    serviceName: appointment.service?.name ?? "Service",
                                    durationMinutes: appointment.service?.duration ?? 60
                                )
                                HapticManager.impact(.medium)
                            }

                            ActionChip(icon: "checkmark", title: "Complete") {
                                withAnimation {
                                    appointment.status = .completed
                                    // Update client's totalSpent
                                    if let client = appointment.client, let price = appointment.service?.price {
                                        client.totalSpent += price
                                    }
                                }
                                StatsCache.shared.invalidate()
                                // End Live Activity if active
                                if LiveActivityManager.shared.isActivityActive {
                                    LiveActivityManager.shared.endActivity()
                                }
                                HapticManager.notification(.success)
                            }

                            ActionChip(icon: "xmark", title: "Cancel") {
                                withAnimation {
                                    appointment.status = .cancelled
                                }
                                StatsCache.shared.invalidate()
                                HapticManager.notification(.warning)
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onTapGesture {
            HapticManager.impact(.light)
            withAnimation(Design.Animation.smooth) {
                isExpanded.toggle()
            }
        }
    }

    private var statusColor: Color {
        switch appointment.status {
        case .scheduled: Design.Colors.accentPrimary
        case .completed: Design.Colors.accentSuccess
        case .cancelled: Design.Colors.textTertiary
        case .noShow: Design.Colors.accentError
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: AppointmentStatus

    var body: some View {
        Text(statusText)
            .font(Design.Typography.caption2)
            .fontWeight(.medium)
            .foregroundStyle(statusColor)
            .padding(.horizontal, Design.Spacing.xs)
            .padding(.vertical, Design.Spacing.xxs)
            .background(statusColor.opacity(0.15), in: Capsule())
    }

    private var statusText: String {
        switch status {
        case .scheduled: "Scheduled"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        case .noShow: "No Show"
        }
    }

    private var statusColor: Color {
        switch status {
        case .scheduled: Design.Colors.accentPrimary
        case .completed: Design.Colors.accentSuccess
        case .cancelled: Design.Colors.textTertiary
        case .noShow: Design.Colors.accentError
        }
    }
}

// MARK: - Action Chip

struct ActionChip: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: Design.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(Design.Typography.caption2)
            }
            .foregroundStyle(Design.Colors.accentPrimary)
            .padding(.horizontal, Design.Spacing.s)
            .padding(.vertical, Design.Spacing.xs)
            .background(Design.Colors.accentPrimary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Appointment View

struct AddAppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var clients: [Client]
    @Query(filter: #Predicate<Service> { $0.isActive }) private var services: [Service]

    let selectedDate: Date

    @State private var selectedClient: Client?
    @State private var selectedService: Service?
    @State private var appointmentTime: Date
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showingPastDateWarning = false

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date()) + 1
        _appointmentTime = State(initialValue: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Time Selection
                        VStack(alignment: .leading, spacing: Design.Spacing.s) {
                            Label("Date & Time", systemImage: "clock")
                                .font(Design.Typography.headline)
                                .foregroundStyle(Design.Colors.textPrimary)
                                .padding(.horizontal, Design.Spacing.m)

                            DatePicker(
                                "",
                                selection: $appointmentTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .tint(Design.Colors.accentPrimary)
                            .padding(Design.Spacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: Design.Radius.l)
                                    .fill(Design.Colors.backgroundSecondary.opacity(0.5))
                            )
                            .padding(.horizontal, Design.Spacing.m)
                        }
                        .animateOnAppear()

                        // Service Selection
                        VStack(alignment: .leading, spacing: Design.Spacing.s) {
                            Label("Service", systemImage: "scissors")
                                .font(Design.Typography.headline)
                                .foregroundStyle(Design.Colors.textPrimary)

                            if services.isEmpty {
                                EmptyStateView(
                                    icon: "scissors",
                                    title: "No services",
                                    subtitle: "Add services in your profile first"
                                )
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Design.Spacing.s) {
                                    ForEach(services, id: \.id) { service in
                                        ServiceSelectionCard(
                                            service: service,
                                            isSelected: selectedService?.id == service.id
                                        ) {
                                            HapticManager.selection()
                                            withAnimation(Design.Animation.smooth) {
                                                selectedService = service
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .animateOnAppear(delay: 0.1)

                        // Client Selection
                        VStack(alignment: .leading, spacing: Design.Spacing.s) {
                            Label("Client", systemImage: "person")
                                .font(Design.Typography.headline)
                                .foregroundStyle(Design.Colors.textPrimary)

                            if clients.isEmpty {
                                EmptyStateView(
                                    icon: "person.badge.plus",
                                    title: "No clients",
                                    subtitle: "Add your first client"
                                )
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Design.Spacing.s) {
                                        ForEach(clients, id: \.id) { client in
                                            ClientChip(
                                                client: client,
                                                isSelected: selectedClient?.id == client.id
                                            ) {
                                                HapticManager.selection()
                                                withAnimation(Design.Animation.smooth) {
                                                    selectedClient = client
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .animateOnAppear(delay: 0.2)

                        // Notes
                        VStack(alignment: .leading, spacing: Design.Spacing.s) {
                            Label("Notes", systemImage: "note.text")
                                .font(Design.Typography.headline)
                                .foregroundStyle(Design.Colors.textPrimary)

                            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(Design.Spacing.s)
                                .background(Design.Colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: Design.Radius.m))
                        }
                        .animateOnAppear(delay: 0.3)
                    }
                    .padding(Design.Spacing.m)
                    .padding(.bottom, Design.Spacing.xxl)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    GlassButton(title: "Save", icon: "checkmark", isLoading: isSaving) {
                        saveAppointment()
                    }
                    .disabled(selectedService == nil || selectedClient == nil)
                }
            }
            .alert("Прошедшая дата", isPresented: $showingPastDateWarning) {
                Button("Отмена", role: .cancel) { }
                Button("Создать всё равно") {
                    performSave()
                }
            } message: {
                Text("Выбранная дата уже прошла. Создать запись на прошлое время?")
            }
        }
    }

    private func saveAppointment() {
        // Check if date is in the past
        if appointmentTime < Date() {
            showingPastDateWarning = true
            return
        }

        performSave()
    }

    private func performSave() {
        isSaving = true
        HapticManager.impact(.medium)

        let appointment = Appointment(
            date: appointmentTime,
            service: selectedService,
            client: selectedClient
        )
        appointment.notes = notes.isEmpty ? nil : InputValidator.sanitize(notes)

        modelContext.insert(appointment)
        StatsCache.shared.invalidate() // Invalidate stats cache

        // Schedule push notification reminder (1 hour before)
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            NotificationManager.shared.scheduleReminder(for: appointment)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Service Selection Card

struct ServiceSelectionCard: View {
    let service: Service
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                Text(service.name)
                    .font(Design.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .lineLimit(1)

                HStack {
                    Text(service.formattedPrice)
                        .font(Design.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(Design.Colors.accentPrimary)

                    Spacer()

                    Text(service.formattedDuration)
                        .font(Design.Typography.caption2)
                        .foregroundStyle(Design.Colors.textTertiary)
                }
            }
            .padding(Design.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius.m)
                    .fill(isSelected ? Design.Colors.accentPrimary.opacity(0.1) : Design.Colors.backgroundSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .strokeBorder(isSelected ? Design.Colors.accentPrimary : .clear, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(Design.Animation.bouncy, value: isSelected)
    }
}

// MARK: - Client Chip

struct ClientChip: View {
    let client: Client
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.xs) {
                Circle()
                    .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.accentPrimary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(client.initials)
                            .font(Design.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSelected ? .white : Design.Colors.accentPrimary)
                    }

                Text(client.name)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textPrimary)
            }
            .padding(.horizontal, Design.Spacing.s)
            .padding(.vertical, Design.Spacing.xs)
             .background {
                Capsule()
                    .fill(isSelected ? Design.Colors.accentPrimary.opacity(0.15) : Design.Colors.backgroundSecondary)
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? Design.Colors.accentPrimary : .clear, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Design.Animation.bouncy, value: isSelected)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
