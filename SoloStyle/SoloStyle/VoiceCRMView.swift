//
//  VoiceCRMView.swift
//  SoloStyle
//
//  Voice CRM — create clients and appointments by voice
//

import SwiftUI
import SwiftData

// MARK: - Voice CRM State

enum VoiceCRMState: Equatable {
    case idle
    case recording
    case processing
    case preview
    case success
    case error(String)
}

// MARK: - Voice CRM View

struct VoiceCRMView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Service> { $0.isActive }) private var services: [Service]

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var state: VoiceCRMState = .idle
    @State private var parsedResponse: VoiceCRMResponse?
    @State private var pulseAnimation = false

    // Editable preview fields
    @State private var editClientName = ""
    @State private var editPhone = ""
    @State private var editServiceName = ""
    @State private var editDate = Date()
    @State private var editPrice = ""
    @State private var editNotes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        switch state {
                        case .idle:
                            idleView
                        case .recording:
                            recordingView
                        case .processing:
                            processingView
                        case .preview:
                            previewView
                        case .success:
                            successView
                        case .error(let msg):
                            errorView(msg)
                        }
                    }
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.top, Design.Spacing.l)
                    .padding(.bottom, Design.Spacing.xxl)
                }
            }
            .navigationTitle(L.voiceCRM)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.impact(.light)
                        speechRecognizer.reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }
            }
            .onAppear {
                speechRecognizer.requestAuthorization()
            }
            .onDisappear {
                speechRecognizer.reset()
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer().frame(height: Design.Spacing.xl)

            // Mic button
            micButton
                .animateOnAppear()

            // Hint
            Text(L.vcTapToSpeak)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Design.Colors.textPrimary)
                .animateOnAppear(delay: 0.05)

            // Example
            Text(L.vcExample)
                .font(.system(size: 14))
                .foregroundStyle(Design.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.Spacing.l)
                .animateOnAppear(delay: 0.1)

            Spacer().frame(height: Design.Spacing.m)

            // Quick templates
            quickTemplates
                .animateOnAppear(delay: 0.15)
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer().frame(height: Design.Spacing.l)

            // Animated mic
            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Design.Colors.accentError.opacity(0.2 - Double(i) * 0.06), lineWidth: 2)
                        .frame(width: CGFloat(120 + i * 30), height: CGFloat(120 + i * 30))
                        .scaleEffect(pulseAnimation ? 1.15 : 0.95)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: pulseAnimation
                        )
                }

                micButtonRecording
            }
            .onAppear { pulseAnimation = true }
            .onDisappear { pulseAnimation = false }

            // Listening label
            HStack(spacing: Design.Spacing.xs) {
                Circle()
                    .fill(Design.Colors.accentError)
                    .frame(width: 8, height: 8)
                Text(L.vcListening)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Design.Colors.accentError)
            }

            // Live transcript
            if !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(.system(size: 16))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .padding(Design.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.l))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Stop hint
            Text(L.vcTapToStop)
                .font(.system(size: 14))
                .foregroundStyle(Design.Colors.textTertiary)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(Design.Colors.accentPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Design.Colors.accentPrimary)
            }

            Text(L.vcProcessing)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Design.Colors.textPrimary)

            // Show transcript
            if !speechRecognizer.transcript.isEmpty {
                Text("«\(speechRecognizer.transcript)»")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.l)
            }
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: Design.Spacing.l) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Design.Colors.accentSuccess)
                Text(L.vcPreviewTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Design.Colors.textPrimary)
                Spacer()
            }
            .animateOnAppear()

            // Editable fields
            VStack(spacing: Design.Spacing.s) {
                previewField(icon: "person.fill", label: L.vcClientName, text: $editClientName, color: .blue)
                previewField(icon: "scissors", label: L.vcServiceName, text: $editServiceName, color: .purple)
                previewDateField
                previewField(icon: "rublesign.circle", label: L.vcPrice, text: $editPrice, color: .green, keyboard: .decimalPad)
                previewField(icon: "phone.fill", label: L.vcPhone, text: $editPhone, color: .orange, keyboard: .phonePad)
                previewField(icon: "text.quote", label: L.vcNotes, text: $editNotes, color: .mint)
            }
            .animateOnAppear(delay: 0.05)

            // Buttons
            VStack(spacing: Design.Spacing.s) {
                // Save
                Button {
                    saveRecord()
                } label: {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L.vcSaveRecord)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.l)
                            .fill(editClientName.isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Design.Colors.accentPrimary, Design.Colors.accentPrimary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )))
                    )
                }
                .disabled(editClientName.isEmpty)

                // Retry
                Button {
                    resetToIdle()
                } label: {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text(L.vcRetry)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Design.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.s)
                }
            }
            .animateOnAppear(delay: 0.1)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Design.Colors.accentSuccess.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Design.Colors.accentSuccess)
            }
            .animateOnAppear()

            VStack(spacing: Design.Spacing.xs) {
                Text(L.vcSaved)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(L.vcSavedMsg)
                    .font(.system(size: 15))
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .animateOnAppear(delay: 0.1)

            Spacer().frame(height: Design.Spacing.m)

            VStack(spacing: Design.Spacing.s) {
                Button {
                    resetToIdle()
                } label: {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                        Text(L.vcRetry)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.m)
                    .glassEffect(.regular.tint(Color.blue.opacity(0.1)), in: .rect(cornerRadius: Design.Radius.l))
                }

                Button {
                    HapticManager.impact(.light)
                    dismiss()
                } label: {
                    Text(L.great)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Design.Colors.textSecondary)
                }
            }
            .animateOnAppear(delay: 0.2)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Design.Colors.accentError.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Design.Colors.accentError)
            }

            VStack(spacing: Design.Spacing.xs) {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.l)
            }

            Button {
                resetToIdle()
            } label: {
                HStack(spacing: Design.Spacing.xs) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text(L.vcRetry)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.vertical, Design.Spacing.m)
                .background(
                    Capsule()
                        .fill(Design.Colors.accentPrimary)
                )
            }
        }
    }

    // MARK: - Mic Buttons

    private var micButton: some View {
        Button {
            HapticManager.impact(.medium)
            startRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(Design.Colors.accentPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "mic.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 90, height: 90)
                    .glassEffect(.regular.tint(Color.blue.opacity(0.2)), in: .circle)
            }
        }
    }

    private var micButtonRecording: some View {
        Button {
            HapticManager.impact(.medium)
            stopAndProcess()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 90, height: 90)
                .background(
                    Circle()
                        .fill(Design.Colors.accentError)
                        .shadow(color: Design.Colors.accentError.opacity(0.4), radius: 16, y: 4)
                )
                .glassEffect(.regular.tint(Color.red.opacity(0.2)), in: .circle)
        }
    }

    // MARK: - Quick Templates

    private var quickTemplates: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.vcExample)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.Colors.textTertiary)
                .padding(.horizontal, Design.Spacing.xxs)

            let templates = [
                ("person.fill", "Запиши Анну на стрижку завтра в 15:00"),
                ("scissors", "Маникюр для Ольги в пятницу в 12:00, цена 2000"),
                ("phone.fill", "Клиент Марина, телефон +79991234567, массаж в субботу"),
            ]

            ForEach(Array(templates.enumerated()), id: \.offset) { _, template in
                Button {
                    speechRecognizer.transcript = template.1
                    stopAndProcess()
                } label: {
                    HStack(spacing: Design.Spacing.s) {
                        Image(systemName: template.0)
                            .font(.system(size: 13))
                            .foregroundStyle(Design.Colors.accentPrimary)
                            .frame(width: 28, height: 28)
                            .glassEffect(.regular.tint(Color.blue.opacity(0.1)), in: .circle)

                        Text(template.1)
                            .font(.system(size: 13))
                            .foregroundStyle(Design.Colors.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                    .padding(.horizontal, Design.Spacing.s)
                    .padding(.vertical, Design.Spacing.s)
                    .glassEffect(.regular.tint(Color.white.opacity(0.03)), in: .rect(cornerRadius: Design.Radius.m))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preview Field

    private func previewField(
        icon: String,
        label: String,
        text: Binding<String>,
        color: Color,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: Design.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(color.opacity(0.15)), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Design.Colors.textTertiary)

                TextField(label, text: text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Design.Colors.textPrimary)
                    .keyboardType(keyboard)
            }
        }
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.s)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.m))
    }

    private var previewDateField: some View {
        HStack(spacing: Design.Spacing.s) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(Color.orange.opacity(0.15)), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.vcDate + " / " + L.vcTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Design.Colors.textTertiary)

                DatePicker("", selection: $editDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Design.Colors.accentPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.s)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .rect(cornerRadius: Design.Radius.m))
    }

    // MARK: - Actions

    private func startRecording() {
        guard speechRecognizer.isAuthorized else {
            speechRecognizer.requestAuthorization()
            if !speechRecognizer.isAuthorized {
                withAnimation(Design.Animation.smooth) {
                    state = .error(L.vcMicDenied)
                }
            }
            return
        }

        do {
            try speechRecognizer.startRecording()
            withAnimation(Design.Animation.smooth) {
                state = .recording
            }
        } catch {
            withAnimation(Design.Animation.smooth) {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func stopAndProcess() {
        speechRecognizer.stopRecording()
        let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            withAnimation(Design.Animation.smooth) {
                state = .error(L.vcNoData)
            }
            return
        }

        withAnimation(Design.Animation.smooth) {
            state = .processing
        }

        Task {
            // Try server first, fall back to local parsing
            var entities: ParsedEntity?

            do {
                let response = try await NetworkManager.shared.parseVoiceCRM(text: transcript)
                parsedResponse = response
                entities = response.entities
            } catch {
                // Fallback: parse locally with regex
                print("[VoiceCRM] Server error: \(error). Using local parser.")
                entities = localParse(transcript)
            }

            guard let entities else {
                withAnimation(Design.Animation.smooth) {
                    state = .error(L.vcNoData)
                }
                HapticManager.notification(.error)
                return
            }

            // Populate editable fields
            editClientName = entities.clientName ?? ""
            editPhone = entities.phone ?? ""
            editServiceName = entities.serviceName ?? ""
            editPrice = entities.price.map { String(format: "%.0f", $0) } ?? ""
            editNotes = entities.notes ?? ""

            // Parse date/time
            editDate = parseDateTime(date: entities.date, time: entities.time)

            withAnimation(Design.Animation.smooth) {
                state = .preview
            }
            HapticManager.notification(.success)
        }
    }

    private func saveRecord() {
        let clientName = editClientName.trimmingCharacters(in: .whitespaces)
        guard !clientName.isEmpty else { return }

        HapticManager.impact(.medium)

        // Create or find client
        let client = Client(
            name: InputValidator.sanitize(clientName),
            phone: editPhone.isEmpty ? nil : editPhone
        )
        modelContext.insert(client)

        // Find or create service
        let serviceName = editServiceName.trimmingCharacters(in: .whitespaces)
        var selectedService: Service?
        if !serviceName.isEmpty {
            // Try to match existing service
            selectedService = services.first { $0.name.lowercased() == serviceName.lowercased() }

            if selectedService == nil {
                // Create new service with parsed price
                let price = Decimal(string: editPrice) ?? 0
                let newService = Service(name: InputValidator.sanitize(serviceName), price: price, duration: 60)
                modelContext.insert(newService)
                selectedService = newService
            }
        }

        // Create appointment
        let appointment = Appointment(
            date: editDate,
            service: selectedService,
            client: client
        )
        appointment.notes = editNotes.isEmpty ? nil : InputValidator.sanitize(editNotes)
        modelContext.insert(appointment)

        StatsCache.shared.invalidate()

        // Schedule reminder
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            NotificationManager.shared.scheduleReminder(for: appointment)
        }

        HapticManager.notification(.success)

        withAnimation(Design.Animation.smooth) {
            state = .success
        }
    }

    private func resetToIdle() {
        speechRecognizer.reset()
        parsedResponse = nil
        editClientName = ""
        editPhone = ""
        editServiceName = ""
        editDate = Date()
        editPrice = ""
        editNotes = ""

        withAnimation(Design.Animation.smooth) {
            state = .idle
        }
    }

    // MARK: - Local Fallback Parser

    /// Regex-based local parser — works offline when server is unavailable
    private func localParse(_ text: String) -> ParsedEntity {
        let lower = text.lowercased()

        // ── Name: first capitalized word or after "клиент/запиши/записать"
        var name: String?
        let namePatterns = [
            #"(?:запиши|записать|клиент|клиентка)\s+([А-ЯЁ][а-яё]+)"#,
            #"^([А-ЯЁ][а-яё]+)\s"#
        ]
        for pattern in namePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let captured = text[match]
                // Extract the name part (after keyword)
                let words = captured.split(separator: " ")
                if let last = words.last {
                    name = String(last)
                    break
                }
            }
        }
        // Broader fallback: find first capitalized Russian word
        if name == nil, let match = text.range(of: #"[А-ЯЁ][а-яё]{2,}"#, options: .regularExpression) {
            name = String(text[match])
        }

        // ── Phone
        var phone: String?
        if let match = text.range(of: #"\+?\d[\d\s\-]{9,}"#, options: .regularExpression) {
            phone = text[match].filter { $0.isNumber || $0 == "+" }
        }

        // ── Service
        var service: String?
        let serviceKeywords: [(String, String)] = [
            ("стрижк", "Стрижка"), ("маникюр", "Маникюр"), ("педикюр", "Педикюр"),
            ("массаж", "Массаж"), ("окрашиван", "Окрашивание"), ("макияж", "Макияж"),
            ("бров", "Оформление бровей"), ("укладк", "Укладка"),
            ("наращиван", "Наращивание"), ("мелирован", "Мелирование"),
            ("эпиляц", "Эпиляция"), ("чистк", "Чистка лица"),
        ]
        for (key, label) in serviceKeywords {
            if lower.contains(key) {
                service = label
                break
            }
        }

        // ── Price
        var price: Double?
        if let match = text.range(of: #"(?:цена|за|стоимость|прайс)\s*(\d+)"#, options: .regularExpression) {
            let sub = String(text[match])
            if let num = sub.range(of: #"\d+"#, options: .regularExpression) {
                price = Double(sub[num])
            }
        } else if let match = text.range(of: #"(\d{3,})\s*(?:руб|₽|р\.?)"#, options: .regularExpression) {
            let sub = String(text[match])
            if let num = sub.range(of: #"\d+"#, options: .regularExpression) {
                price = Double(sub[num])
            }
        }

        // ── Date
        var dateStr: String?
        let calendar = Calendar.current
        let today = Date()

        if lower.contains("сегодня") {
            dateStr = formatDate(today)
        } else if lower.contains("завтра") {
            if let d = calendar.date(byAdding: .day, value: 1, to: today) { dateStr = formatDate(d) }
        } else if lower.contains("послезавтра") {
            if let d = calendar.date(byAdding: .day, value: 2, to: today) { dateStr = formatDate(d) }
        } else {
            let weekdays: [(String, Int)] = [
                ("понедельник", 2), ("вторник", 3), ("сред", 4),
                ("четверг", 5), ("пятниц", 6), ("суббот", 7), ("воскресен", 1)
            ]
            for (keyword, weekday) in weekdays {
                if lower.contains(keyword) {
                    if let d = nextWeekday(weekday, from: today) { dateStr = formatDate(d) }
                    break
                }
            }
        }

        // ── Time
        var timeStr: String?
        // "в 15:00", "в 15 00", "в 15"
        if let match = text.range(of: #"в\s+(\d{1,2})[:\s]?(\d{2})?"#, options: .regularExpression) {
            let sub = String(text[match])
            let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let hourStr = nums.first, var hour = Int(hourStr) {
                let minute = nums.count > 1 ? (Int(nums[1]) ?? 0) : 0
                // Convert single-digit hours to PM for salon context (3 -> 15)
                if hour >= 1 && hour <= 8 { hour += 12 }
                timeStr = String(format: "%02d:%02d", hour, minute)
            }
        }

        return ParsedEntity(
            clientName: name,
            phone: phone,
            serviceName: service,
            date: dateStr,
            time: timeStr,
            price: price,
            notes: nil
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func nextWeekday(_ weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let current = calendar.component(.weekday, from: date)
        var daysToAdd = weekday - current
        if daysToAdd <= 0 { daysToAdd += 7 }
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }

    // MARK: - Date Parsing

    private func parseDateTime(date dateStr: String?, time timeStr: String?) -> Date {
        let calendar = Calendar.current
        var result = Date()

        if let dateStr, let parsedDate = ISO8601DateFormatter().date(from: dateStr + "T00:00:00Z") {
            // Use parsed date but keep current time zone
            let components = calendar.dateComponents([.year, .month, .day], from: parsedDate)
            if let dateOnly = calendar.date(from: components) {
                result = dateOnly
            }
        } else if let dateStr {
            // Try simple date format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let d = formatter.date(from: dateStr) {
                result = d
            }
        }

        if let timeStr {
            let parts = timeStr.split(separator: ":").compactMap { Int($0) }
            if parts.count >= 2 {
                let comps = calendar.dateComponents([.year, .month, .day], from: result)
                if let dateWithTime = calendar.date(
                    from: DateComponents(
                        year: comps.year,
                        month: comps.month,
                        day: comps.day,
                        hour: parts[0],
                        minute: parts[1]
                    )
                ) {
                    result = dateWithTime
                }
            }
        }

        return result
    }
}

#Preview {
    VoiceCRMView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
