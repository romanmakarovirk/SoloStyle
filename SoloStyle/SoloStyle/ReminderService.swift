//
//  ReminderService.swift
//  SoloStyle
//
//  Smart reminders with message templates
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Reminder Templates

enum ReminderTemplate: CaseIterable, Identifiable {
    case dayBefore
    case hourBefore
    case confirmation
    case thankYou
    case missYou

    var id: String { title }

    var title: String {
        switch self {
        case .dayBefore: return L.templateDayBefore
        case .hourBefore: return L.templateHourBefore
        case .confirmation: return L.templateConfirmation
        case .thankYou: return L.templateThankYou
        case .missYou: return L.templateMissYou
        }
    }

    var icon: String {
        switch self {
        case .dayBefore: return "calendar.badge.clock"
        case .hourBefore: return "clock"
        case .confirmation: return "checkmark.circle"
        case .thankYou: return "heart"
        case .missYou: return "hand.wave"
        }
    }

    var color: Color {
        switch self {
        case .dayBefore: return .blue
        case .hourBefore: return .orange
        case .confirmation: return .green
        case .thankYou: return .pink
        case .missYou: return .purple
        }
    }

    func generateMessage(clientName: String, serviceName: String, date: Date, businessName: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: date)
        let business = businessName ?? L.ourSalon

        switch self {
        case .dayBefore:
            return L.reminderDayBefore(client: clientName, service: serviceName, date: dateStr, business: business)

        case .hourBefore:
            return L.reminderHourBefore(client: clientName, service: serviceName)

        case .confirmation:
            return L.reminderConfirmation(client: clientName, service: serviceName, date: dateStr)

        case .thankYou:
            return L.reminderThankYou(client: clientName, service: serviceName, business: business)

        case .missYou:
            return L.reminderMissYou(client: clientName, service: serviceName, business: business)
        }
    }
}

// MARK: - Send Reminder View

struct SendReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var masters: [Master]

    let appointment: Appointment

    @State private var selectedTemplate: ReminderTemplate = .dayBefore
    @State private var customMessage = ""
    @State private var useCustomMessage = false
    @State private var isSending = false

    private var master: Master? { masters.first }

    private var generatedMessage: String {
        selectedTemplate.generateMessage(
            clientName: appointment.client?.name ?? "Client",
            serviceName: appointment.service?.name ?? "Service",
            date: appointment.date,
            businessName: master?.businessName
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Appointment summary
                        appointmentSummary
                            .animateOnAppear(delay: 0.1)

                        // Template selection
                        templateSelection
                            .animateOnAppear(delay: 0.2)

                        // Message preview
                        messagePreview
                            .animateOnAppear(delay: 0.3)

                        // Send buttons
                        sendButtons
                            .animateOnAppear(delay: 0.4)
                    }
                    .padding(Design.Spacing.m)
                }
            }
            .navigationTitle(L.sendReminder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
        }
    }

    private var appointmentSummary: some View {
        GlassCard(tint: Color.blue.opacity(0.1)) {
            HStack(spacing: Design.Spacing.m) {
                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text(appointment.client?.name ?? "Unknown")
                        .font(Design.Typography.headline)

                    Text(appointment.service?.name ?? "Service")
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textSecondary)

                    Text(appointment.date, style: .date)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "bell.badge")
                    .font(.system(size: 32))
                    .foregroundStyle(Design.Colors.accentPrimary)
            }
        }
    }

    private var templateSelection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.messageTemplate)
                .font(Design.Typography.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Design.Spacing.s) {
                    ForEach(ReminderTemplate.allCases) { template in
                        TemplateChip(
                            template: template,
                            isSelected: selectedTemplate == template && !useCustomMessage
                        ) {
                            HapticManager.selection()
                            withAnimation {
                                selectedTemplate = template
                                useCustomMessage = false
                            }
                        }
                    }

                    // Custom option
                    Button {
                        HapticManager.selection()
                        withAnimation {
                            useCustomMessage = true
                        }
                    } label: {
                        HStack(spacing: Design.Spacing.xs) {
                            Image(systemName: "pencil")
                            Text(L.custom)
                        }
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(useCustomMessage ? .white : Design.Colors.textSecondary)
                        .padding(.horizontal, Design.Spacing.m)
                        .padding(.vertical, Design.Spacing.s)
                        .background(
                            Capsule()
                                .fill(useCustomMessage ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
                        )
                    }
                }
            }
        }
    }

    private var messagePreview: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                Text(L.messagePreview)
                    .font(Design.Typography.headline)

                Spacer()

                Text("\(currentMessage.count) \(L.chars)")
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }

            if useCustomMessage {
                TextField(L.typeYourMessage, text: $customMessage, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(Design.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .fill(Design.Colors.backgroundSecondary)
                    )
            } else {
                Text(generatedMessage)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textPrimary)
                    .padding(Design.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .fill(Design.Colors.backgroundSecondary)
                    )
            }
        }
    }

    private var sendButtons: some View {
        VStack(spacing: Design.Spacing.m) {
            if let phone = appointment.client?.phone {
                HStack(spacing: Design.Spacing.m) {
                    // SMS
                    GlassButton(title: L.sms, icon: "message.fill", style: .secondary, isFullWidth: true) {
                        sendSMS(to: phone)
                    }

                    // WhatsApp
                    GlassButton(title: L.whatsapp, icon: "bubble.left.fill", isFullWidth: true) {
                        sendWhatsApp(to: phone)
                    }
                }
            } else {
                Text(L.noPhoneNumber)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(Design.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .fill(Design.Colors.backgroundSecondary)
                    )
            }

            // Copy to clipboard
            GlassButton(title: L.copyMessage, icon: "doc.on.doc", style: .secondary, isFullWidth: true) {
                UIPasteboard.general.string = currentMessage
                HapticManager.notification(.success)
            }
        }
    }

    private var currentMessage: String {
        useCustomMessage ? customMessage : generatedMessage
    }

    private func sendSMS(to phone: String) {
        let sanitizedMessage = InputValidator.sanitize(currentMessage)
        if let url = InputValidator.safeSMSURL(phone, body: sanitizedMessage) {
            UIApplication.shared.open(url)
            HapticManager.impact(.medium)
            dismiss()
        }
    }

    private func sendWhatsApp(to phone: String) {
        guard InputValidator.isValidPhone(phone) else { return }
        let cleanPhone = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        let sanitizedMessage = InputValidator.sanitize(currentMessage)
        guard let encodedMessage = sanitizedMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(cleanPhone)?text=\(encodedMessage)") else { return }
        UIApplication.shared.open(url)
        HapticManager.impact(.medium)
        dismiss()
    }
}

struct TemplateChip: View {
    let template: ReminderTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.xs) {
                Image(systemName: template.icon)
                Text(template.title)
            }
            .font(Design.Typography.subheadline)
            .foregroundStyle(isSelected ? .white : Design.Colors.textSecondary)
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.s)
            .background(
                Capsule()
                    .fill(isSelected ? template.color : Design.Colors.backgroundSecondary)
            )
        }
    }
}

// MARK: - Upcoming Reminders View

struct UpcomingRemindersView: View {
    @Query(
        filter: #Predicate<Appointment> { $0.statusRaw == "scheduled" },
        sort: \Appointment.date
    ) private var upcomingAppointments: [Appointment]

    @State private var selectedAppointment: Appointment?

    private var tomorrowAppointments: [Appointment] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return upcomingAppointments.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }
    }

    private var needsReminder: [Appointment] {
        upcomingAppointments.filter { !$0.reminderSent }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                if upcomingAppointments.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: L.noUpcomingAppointments,
                        subtitle: L.scheduleToRemind
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Design.Spacing.l) {
                            // Tomorrow section
                            if !tomorrowAppointments.isEmpty {
                                reminderSection(title: L.tomorrow, appointments: tomorrowAppointments, urgent: true)
                            }

                            // Needs reminder section
                            if !needsReminder.isEmpty {
                                reminderSection(title: L.needsReminder, appointments: needsReminder, urgent: false)
                            }

                            // All upcoming
                            reminderSection(title: L.allUpcoming, appointments: upcomingAppointments, urgent: false)
                        }
                        .padding(Design.Spacing.m)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(L.reminders)
            .sheet(item: $selectedAppointment) { appointment in
                SendReminderView(appointment: appointment)
            }
        }
    }

    private func reminderSection(title: String, appointments: [Appointment], urgent: Bool) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            HStack {
                Text(title)
                    .font(Design.Typography.headline)

                if urgent {
                    Text("\(appointments.count)")
                        .font(Design.Typography.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: Capsule())
                }
            }

            ForEach(appointments, id: \.id) { appointment in
                ReminderAppointmentCard(appointment: appointment) {
                    selectedAppointment = appointment
                }
            }
        }
    }
}

struct ReminderAppointmentCard: View {
    let appointment: Appointment
    let onSendReminder: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: Design.Spacing.m) {
                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text(appointment.client?.name ?? "Unknown")
                        .font(Design.Typography.headline)

                    Text(appointment.service?.name ?? "Service")
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textSecondary)

                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(appointment.date, style: .date)
                        Text(L.atTime)
                        Text(appointment.date, style: .time)
                    }
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textTertiary)
                }

                Spacer()

                VStack(spacing: Design.Spacing.xs) {
                    if appointment.reminderSent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Design.Colors.accentSuccess)
                        Text(L.sent)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.accentSuccess)
                    } else {
                        Button {
                            HapticManager.impact(.medium)
                            onSendReminder()
                        } label: {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 24))
                                .foregroundStyle(Design.Colors.accentPrimary)
                        }
                        Text(L.sendAction)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.accentPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Local Notification Manager

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // Request notification permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // Check current authorization status
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // Schedule a reminder 1 hour before appointment
    func scheduleReminder(for appointment: Appointment) {
        guard let client = appointment.client else { return }

        let content = UNMutableNotificationContent()
        content.title = L.upcomingAppointmentNotif
        content.body = L.appointmentInOneHour(client: client.name, service: appointment.service?.name ?? L.appointments)
        content.sound = .default
        content.categoryIdentifier = "APPOINTMENT_REMINDER"

        // Trigger 1 hour before
        guard let triggerDate = Calendar.current.date(byAdding: .hour, value: -1, to: appointment.date) else { return }

        // Don't schedule if the trigger time is in the past
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "appointment-\(appointment.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // Cancel reminder for a specific appointment
    func cancelReminder(for appointment: Appointment) {
        center.removePendingNotificationRequests(withIdentifiers: ["appointment-\(appointment.id.uuidString)"])
    }

    // Cancel all reminders
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }
}

#Preview {
    UpcomingRemindersView()
        .modelContainer(for: Appointment.self, inMemory: true)
}
