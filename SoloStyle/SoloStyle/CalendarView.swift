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
    @State private var showingVoiceCRM = false

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
                                    AppointmentRow(appointment: appointment, onDelete: {
                                        appointmentToDelete = appointment
                                        showingDeleteConfirmation = true
                                    })
                                    .animateOnAppear(delay: 0.05 * Double(index))
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)
                        .padding(.top, Design.Spacing.s)
                        .padding(.bottom, 130)
                    }
                }

                // FABs
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: Design.Spacing.s) {
                            // Mic FAB — Voice CRM
                            Button {
                                HapticManager.impact(.medium)
                                showingVoiceCRM = true
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 46, height: 46)
                                    .background(
                                        Circle()
                                            .fill(Design.Colors.accentSuccess)
                                            .shadow(color: Design.Colors.accentSuccess.opacity(0.35), radius: 10, y: 4)
                                    )
                                    .glassEffect(.regular.tint(Color.green.opacity(0.3)), in: .circle)
                            }

                            // Plus FAB — manual add
                            Button {
                                HapticManager.impact(.medium)
                                showingAddAppointment = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(Design.Colors.accentPrimary)
                                            .shadow(color: Design.Colors.accentPrimary.opacity(0.35), radius: 12, y: 6)
                                    )
                                    .glassEffect(.regular.tint(Color.blue.opacity(0.3)), in: .circle)
                            }
                        }
                        .padding(.trailing, Design.Spacing.l)
                        .padding(.bottom, 130)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddAppointment) {
                AddAppointmentView(selectedDate: selectedDate)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingVoiceCRM) {
                VoiceCRMView()
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
                        Text("Сегодня")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Design.Colors.accentPrimary)
                            .padding(.horizontal, Design.Spacing.s)
                            .padding(.vertical, Design.Spacing.xxs + 2)
                            .glassEffect(.regular.tint(Color.blue.opacity(0.15)), in: .capsule)
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
                .padding(.vertical, 6) // extra room so scaled selected cell isn't clipped
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
        .padding(.vertical, Design.Spacing.xs)
        .padding(.horizontal, Design.Spacing.xxs)
        .glassEffect(.regular.tint(Color.blue.opacity(0.08)), in: .rect(cornerRadius: Design.Radius.xl))
        .padding(.horizontal, Design.Spacing.s)
    }

    // MARK: - Summary Pill

    private var summaryPill: some View {
        HStack(spacing: Design.Spacing.m) {
            Label("\(todayAppointments.count) записей", systemImage: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.Colors.textSecondary)

            Spacer()

            let completed = todayAppointments.filter { $0.status == .completed }.count
            if completed > 0 {
                Label("\(completed) готово", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Design.Colors.accentSuccess)
            }
        }
        .padding(.horizontal, Design.Spacing.m)
        .padding(.vertical, Design.Spacing.s)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .capsule)
        .padding(.horizontal, Design.Spacing.m)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Design.Spacing.m) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Design.Colors.textTertiary.opacity(0.5))

            VStack(spacing: Design.Spacing.xxs) {
                Text("Нет записей")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Design.Colors.textSecondary)

                Text("Этот день свободен")
                    .font(.system(size: 14))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.xxl)
        .glassEffect(.regular.tint(Color.white.opacity(0.03)), in: .rect(cornerRadius: Design.Radius.xl))
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
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Design.Colors.textTertiary)

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: isSelected ? 18 : 16, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : (isToday ? Design.Colors.accentPrimary : Design.Colors.textPrimary))

                // Indicator dot
                Circle()
                    .fill(hasAppointments ? (isSelected ? .white : Design.Colors.accentPrimary) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 70)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Design.Colors.accentPrimary)
                        .shadow(color: Design.Colors.accentPrimary.opacity(0.3), radius: 8, y: 2)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Design.Colors.accentPrimary.opacity(0.4), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: Design.Spacing.m) {
                // Time
                VStack(spacing: 2) {
                    Text(appointment.formattedTime)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Design.Colors.textPrimary)

                    if let service = appointment.service {
                        Text("\(service.duration) мин")
                            .font(.system(size: 11))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }
                .frame(width: 54)

                // Color accent line
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor)
                    .frame(width: 3, height: 38)

                // Client & service
                VStack(alignment: .leading, spacing: 3) {
                    Text(appointment.client?.name ?? "Клиент")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.Colors.textPrimary)

                    if let service = appointment.service {
                        Text(service.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Design.Colors.textSecondary)
                    }
                }

                Spacer()

                // Status
                StatusBadge(status: appointment.status)
            }

            // Expandable actions
            if isExpanded {
                Rectangle()
                    .fill(Design.Colors.textTertiary.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.vertical, Design.Spacing.s)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Design.Spacing.xs) {
                        if let phone = appointment.client?.phone {
                            ActionChip(icon: "phone.fill", title: "Звонок") {
                                if let url = InputValidator.safePhoneURL(phone) {
                                    UIApplication.shared.open(url)
                                }
                            }

                            ActionChip(icon: "message.fill", title: "SMS") {
                                if let url = InputValidator.safeSMSURL(phone) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if appointment.status == .scheduled {
                            ActionChip(icon: "play.fill", title: "Старт", tint: .green) {
                                LiveActivityManager.shared.startActivity(
                                    clientName: appointment.client?.name ?? "Клиент",
                                    serviceName: appointment.service?.name ?? "Услуга",
                                    durationMinutes: appointment.service?.duration ?? 60
                                )
                                HapticManager.impact(.medium)
                            }

                            ActionChip(icon: "checkmark", title: "Готово", tint: .green) {
                                withAnimation {
                                    appointment.status = .completed
                                    if let client = appointment.client, let price = appointment.service?.price {
                                        client.totalSpent += price
                                    }
                                }
                                StatsCache.shared.invalidate()
                                if LiveActivityManager.shared.isActivityActive {
                                    LiveActivityManager.shared.endActivity()
                                }
                                HapticManager.notification(.success)
                            }

                            ActionChip(icon: "xmark", title: "Отмена", tint: .red) {
                                withAnimation {
                                    appointment.status = .cancelled
                                }
                                StatsCache.shared.invalidate()
                                HapticManager.notification(.warning)
                            }
                        }

                        // Delete
                        ActionChip(icon: "trash", title: "Удалить", tint: .red) {
                            HapticManager.notification(.warning)
                            onDelete?()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Design.Spacing.m)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.l))
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, Design.Spacing.xs)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var statusText: String {
        switch status {
        case .scheduled: "Ожидает"
        case .completed: "Готово"
        case .cancelled: "Отменён"
        case .noShow: "Неявка"
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
    var tint: Color = Design.Colors.accentPrimary
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Design.Spacing.s)
            .padding(.vertical, 7)
            .background(tint.opacity(0.1), in: Capsule())
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
    @State private var currentStep = 0 // 0=time, 1=service, 2=client, 3=notes
    @State private var showingNewClient = false
    @State private var newClientName = ""
    @State private var newClientPhone = ""

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date()) + 1
        _appointmentTime = State(initialValue: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate)
    }

    private var canSave: Bool {
        selectedService != nil && selectedClient != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {

                        // Step indicators
                        stepIndicator
                            .padding(.top, Design.Spacing.s)
                            .animateOnAppear()

                        // Date & Time — compact inline picker
                        sectionCard(delay: 0) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Design.Colors.accentPrimary)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.blue.opacity(0.15)), in: .circle)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Дата и время")
                                        .font(Design.Typography.caption1)
                                        .foregroundStyle(Design.Colors.textSecondary)

                                    DatePicker(
                                        "",
                                        selection: $appointmentTime,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(Design.Colors.accentPrimary)
                                }

                                Spacer()
                            }
                        }

                        // Service Selection
                        sectionCard(delay: 0.05) {
                            VStack(alignment: .leading, spacing: Design.Spacing.m) {
                                HStack {
                                    Image(systemName: "scissors")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.purple)
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(Color.purple.opacity(0.15)), in: .circle)

                                    Text("Услуга")
                                        .font(Design.Typography.caption1)
                                        .foregroundStyle(Design.Colors.textSecondary)

                                    Spacer()

                                    if let service = selectedService {
                                        Text(service.formattedPrice)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Design.Colors.accentPrimary)
                                    }
                                }

                                if services.isEmpty {
                                    Text("Добавьте услуги в профиле")
                                        .font(Design.Typography.subheadline)
                                        .foregroundStyle(Design.Colors.textTertiary)
                                } else {
                                    FlowLayout(spacing: Design.Spacing.xs) {
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
                        }

                        // Client Selection
                        sectionCard(delay: 0.1) {
                            VStack(alignment: .leading, spacing: Design.Spacing.m) {
                                HStack {
                                    Image(systemName: "person")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.orange)
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(Color.orange.opacity(0.15)), in: .circle)

                                    Text("Клиент")
                                        .font(Design.Typography.caption1)
                                        .foregroundStyle(Design.Colors.textSecondary)

                                    Spacer()

                                    // Quick add client button
                                    Button {
                                        HapticManager.impact(.light)
                                        withAnimation(Design.Animation.smooth) {
                                            showingNewClient.toggle()
                                            if !showingNewClient {
                                                newClientName = ""
                                                newClientPhone = ""
                                            }
                                        }
                                    } label: {
                                        Image(systemName: showingNewClient ? "xmark" : "plus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(showingNewClient ? Design.Colors.textTertiary : Design.Colors.accentPrimary)
                                            .frame(width: 30, height: 30)
                                            .glassEffect(
                                                .regular.tint(showingNewClient ? Color.gray.opacity(0.1) : Color.blue.opacity(0.15)),
                                                in: .circle
                                            )
                                    }
                                }

                                // Inline new client form
                                if showingNewClient {
                                    VStack(spacing: Design.Spacing.s) {
                                        HStack(spacing: Design.Spacing.s) {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Design.Colors.textTertiary)
                                                .frame(width: 20)

                                            TextField("Имя клиента", text: $newClientName)
                                                .font(Design.Typography.body)
                                                .textContentType(.name)
                                        }
                                        .padding(Design.Spacing.s)
                                        .background(
                                            RoundedRectangle(cornerRadius: Design.Radius.m)
                                                .fill(Design.Colors.backgroundPrimary.opacity(0.5))
                                        )

                                        HStack(spacing: Design.Spacing.s) {
                                            Image(systemName: "phone.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Design.Colors.textTertiary)
                                                .frame(width: 20)

                                            TextField("Телефон (необязательно)", text: $newClientPhone)
                                                .font(Design.Typography.body)
                                                .textContentType(.telephoneNumber)
                                                .keyboardType(.phonePad)
                                        }
                                        .padding(Design.Spacing.s)
                                        .background(
                                            RoundedRectangle(cornerRadius: Design.Radius.m)
                                                .fill(Design.Colors.backgroundPrimary.opacity(0.5))
                                        )

                                        Button {
                                            addNewClient()
                                        } label: {
                                            HStack(spacing: Design.Spacing.xs) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("Добавить")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Design.Spacing.s)
                                            .background(
                                                Capsule()
                                                    .fill(newClientName.trimmingCharacters(in: .whitespaces).isEmpty
                                                        ? Color.gray.opacity(0.3)
                                                        : Design.Colors.accentPrimary)
                                            )
                                        }
                                        .disabled(newClientName.trimmingCharacters(in: .whitespaces).isEmpty)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                // Existing clients list
                                if !clients.isEmpty {
                                    FlowLayout(spacing: Design.Spacing.xs) {
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
                                } else if !showingNewClient {
                                    Text("Нажмите + чтобы добавить клиента")
                                        .font(Design.Typography.subheadline)
                                        .foregroundStyle(Design.Colors.textTertiary)
                                }
                            }
                        }

                        // Notes
                        sectionCard(delay: 0.15) {
                            VStack(alignment: .leading, spacing: Design.Spacing.s) {
                                HStack {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.mint)
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(Color.mint.opacity(0.15)), in: .circle)

                                    Text("Заметки")
                                        .font(Design.Typography.caption1)
                                        .foregroundStyle(Design.Colors.textSecondary)

                                    Spacer()
                                }

                                TextField("Дополнительная информация...", text: $notes, axis: .vertical)
                                    .lineLimit(2...4)
                                    .font(Design.Typography.body)
                                    .padding(Design.Spacing.s)
                                    .background(
                                        RoundedRectangle(cornerRadius: Design.Radius.m)
                                            .fill(Design.Colors.backgroundPrimary.opacity(0.5))
                                    )
                            }
                        }

                        // Save button
                        Button {
                            saveAppointment()
                        } label: {
                            HStack(spacing: Design.Spacing.s) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text("Сохранить")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Design.Spacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: Design.Radius.l)
                                    .fill(canSave
                                        ? LinearGradient(colors: [Design.Colors.accentPrimary, Design.Colors.accentPrimary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                    )
                            )
                        }
                        .disabled(!canSave || isSaving)
                        .animateOnAppear(delay: 0.2)
                        .padding(.top, Design.Spacing.xs)
                    }
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.bottom, Design.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Новая запись")
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

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: Design.Spacing.xs) {
            stepDot(filled: true, label: "Время")
            stepLine
            stepDot(filled: selectedService != nil, label: "Услуга")
            stepLine
            stepDot(filled: selectedClient != nil, label: "Клиент")
        }
        .padding(.horizontal, Design.Spacing.xl)
    }

    private func stepDot(filled: Bool, label: String) -> some View {
        VStack(spacing: Design.Spacing.xxs) {
            Circle()
                .fill(filled ? Design.Colors.accentPrimary : Design.Colors.textTertiary.opacity(0.3))
                .frame(width: 10, height: 10)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(filled ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
        }
    }

    private var stepLine: some View {
        Rectangle()
            .fill(Design.Colors.textTertiary.opacity(0.2))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14) // align with dots
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(delay: Double, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Design.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.xl))
            .animateOnAppear(delay: delay)
    }

    // MARK: - Save Logic

    private func addNewClient() {
        let name = newClientName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        HapticManager.impact(.medium)

        let phone = newClientPhone.trimmingCharacters(in: .whitespaces)
        let client = Client(
            name: InputValidator.sanitize(name),
            phone: phone.isEmpty ? nil : phone
        )

        modelContext.insert(client)

        withAnimation(Design.Animation.smooth) {
            selectedClient = client
            showingNewClient = false
            newClientName = ""
            newClientPhone = ""
        }

        HapticManager.notification(.success)
    }

    private func saveAppointment() {
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
        StatsCache.shared.invalidate()

        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            NotificationManager.shared.scheduleReminder(for: appointment)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Flow Layout (wrapping tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Service Selection Card

struct ServiceSelectionCard: View {
    let service: Service
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.xs) {
                Text(service.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Design.Colors.textPrimary)

                Text(service.formattedDuration)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : Design.Colors.textTertiary)
            }
            .padding(.horizontal, Design.Spacing.s)
            .padding(.vertical, Design.Spacing.xs)
            .background {
                Capsule()
                    .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
            }
        }
        .buttonStyle(.plain)
        .animation(Design.Animation.smooth, value: isSelected)
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
                Text(client.initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? .white : Design.Colors.accentPrimary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.accentPrimary.opacity(0.15))
                    )

                Text(client.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Design.Colors.textPrimary)
            }
            .padding(.leading, Design.Spacing.xxs)
            .padding(.trailing, Design.Spacing.s)
            .padding(.vertical, Design.Spacing.xxs)
            .background {
                Capsule()
                    .fill(isSelected ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
            }
        }
        .buttonStyle(.plain)
        .animation(Design.Animation.smooth, value: isSelected)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
