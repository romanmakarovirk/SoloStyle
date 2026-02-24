//
//  AnalyticsView.swift
//  SoloStyle
//
//  Analytics dashboard with charts and insights
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appointments: [Appointment]
    @Query private var clients: [Client]
    @Query private var services: [Service]

    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Period selector
                        periodSelector
                            .animateOnAppear(delay: 0.1)

                        // Revenue card
                        revenueCard
                            .animateOnAppear(delay: 0.15)

                        // Revenue chart
                        revenueChart
                            .animateOnAppear(delay: 0.2)

                        // Top services
                        topServicesSection
                            .animateOnAppear(delay: 0.25)

                        // Client insights
                        clientInsights
                            .animateOnAppear(delay: 0.3)

                        // Appointments stats
                        appointmentStats
                            .animateOnAppear(delay: 0.35)
                    }
                    .padding(Design.Spacing.m)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(L.analytics)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportDataView()
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: Design.Spacing.xs) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Button {
                    HapticManager.selection()
                    withAnimation(Design.Animation.smooth) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.title)
                        .font(Design.Typography.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .foregroundStyle(selectedPeriod == period ? .white : Design.Colors.textSecondary)
                        .padding(.horizontal, Design.Spacing.m)
                        .padding(.vertical, Design.Spacing.s)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
                        )
                }
            }
        }
    }

    // MARK: - Revenue Card

    private var revenueCard: some View {
        let revenue = calculateRevenue(for: selectedPeriod)
        let previousRevenue = calculateRevenue(for: selectedPeriod, previous: true)
        let changeDecimal = previousRevenue > 0 ? ((revenue - previousRevenue) / previousRevenue) * 100 : Decimal(0)
        let change = NSDecimalNumber(decimal: changeDecimal).doubleValue

        return GlassCard(tint: Color.green.opacity(0.1)) {
            VStack(spacing: Design.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                        Text(L.revenue)
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textSecondary)

                        Text(formatCurrency(revenue))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Design.Colors.textPrimary)
                    }

                    Spacer()

                    if change != 0 {
                        HStack(spacing: Design.Spacing.xxs) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.1f%%", abs(change)))
                        }
                        .font(Design.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(change > 0 ? Design.Colors.accentSuccess : Design.Colors.accentError)
                        .padding(.horizontal, Design.Spacing.s)
                        .padding(.vertical, Design.Spacing.xs)
                        .background(
                            Capsule()
                                .fill((change > 0 ? Design.Colors.accentSuccess : Design.Colors.accentError).opacity(0.15))
                        )
                    }
                }

                HStack(spacing: Design.Spacing.l) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(filteredAppointments.count)")
                            .font(Design.Typography.title3)
                            .fontWeight(.semibold)
                        Text(L.appointments)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatCurrency(revenue / Decimal(max(1, filteredAppointments.count))))
                            .font(Design.Typography.title3)
                            .fontWeight(.semibold)
                        Text(L.avgTicket)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(completedAppointments.count)")
                            .font(Design.Typography.title3)
                            .fontWeight(.semibold)
                        Text(L.completed)
                            .font(Design.Typography.caption2)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Revenue Chart

    private var revenueChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Design.Spacing.m) {
                Text(L.revenueTrend)
                    .font(Design.Typography.headline)

                if chartData.isEmpty {
                    Text(L.noDataForPeriod)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Design.Spacing.xl)
                } else {
                    Chart(chartData) { item in
                        BarMark(
                            x: .value("Date", item.label),
                            y: .value("Revenue", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Design.Colors.accentPrimary, Design.Colors.accentPrimary.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            if let amount = value.as(Decimal.self) {
                                AxisValueLabel {
                                    Text(formatCurrencyShort(amount))
                                        .font(Design.Typography.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Top Services

    private var topServicesSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.topServices)
                .font(Design.Typography.headline)

            if topServices.isEmpty {
                GlassCard {
                    Text(L.noServicesData)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.m)
                }
            } else {
                ForEach(Array(topServices.prefix(5).enumerated()), id: \.offset) { index, item in
                    TopServiceRow(rank: index + 1, serviceName: item.name, count: item.count, revenue: item.revenue)
                }
            }
        }
    }

    // MARK: - Client Insights

    private var clientInsights: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.clientInsights)
                .font(Design.Typography.headline)

            HStack(spacing: Design.Spacing.s) {
                InsightCard(
                    icon: "person.badge.plus",
                    value: "\(newClientsCount)",
                    label: L.newClients,
                    color: .green
                )

                InsightCard(
                    icon: "arrow.counterclockwise",
                    value: "\(returningClientsCount)",
                    label: L.returning,
                    color: .blue
                )

                InsightCard(
                    icon: "crown.fill",
                    value: "\(vipClientsCount)",
                    label: "VIP+",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Appointment Stats

    private var appointmentStats: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.appointmentStatus)
                .font(Design.Typography.headline)

            GlassCard {
                VStack(spacing: Design.Spacing.m) {
                    AppointmentStatusRow(status: .completed, count: statusCount(.completed), total: filteredAppointments.count)
                    Divider()
                    AppointmentStatusRow(status: .scheduled, count: statusCount(.scheduled), total: filteredAppointments.count)
                    Divider()
                    AppointmentStatusRow(status: .cancelled, count: statusCount(.cancelled), total: filteredAppointments.count)
                    Divider()
                    AppointmentStatusRow(status: .noShow, count: statusCount(.noShow), total: filteredAppointments.count)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredAppointments: [Appointment] {
        let calendar = Calendar.current
        let now = Date()

        return appointments.filter { appointment in
            switch selectedPeriod {
            case .day:
                return calendar.isDateInToday(appointment.date)
            case .week:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                return appointment.date >= weekAgo && appointment.date <= now
            case .month:
                guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return false }
                return appointment.date >= monthAgo && appointment.date <= now
            case .year:
                guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) else { return false }
                return appointment.date >= yearAgo && appointment.date <= now
            }
        }
    }

    private var completedAppointments: [Appointment] {
        filteredAppointments.filter { $0.status == .completed }
    }

    private var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let grouped: [String: Decimal]

        switch selectedPeriod {
        case .day:
            grouped = Dictionary(grouping: completedAppointments) { appointment in
                let hour = calendar.component(.hour, from: appointment.date)
                return String(format: "%02d:00", hour)
            }.mapValues { apps in
                apps.compactMap { $0.service?.price }.reduce(0, +)
            }
        case .week:
            grouped = Dictionary(grouping: completedAppointments) { appointment in
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return formatter.string(from: appointment.date)
            }.mapValues { apps in
                apps.compactMap { $0.service?.price }.reduce(0, +)
            }
        case .month:
            grouped = Dictionary(grouping: completedAppointments) { appointment in
                let week = calendar.component(.weekOfMonth, from: appointment.date)
                return "W\(week)"
            }.mapValues { apps in
                apps.compactMap { $0.service?.price }.reduce(0, +)
            }
        case .year:
            grouped = Dictionary(grouping: completedAppointments) { appointment in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return formatter.string(from: appointment.date)
            }.mapValues { apps in
                apps.compactMap { $0.service?.price }.reduce(0, +)
            }
        }

        return grouped.map { ChartDataPoint(label: $0.key, value: $0.value) }
            .sorted { $0.label < $1.label }
    }

    private var topServices: [(name: String, count: Int, revenue: Decimal)] {
        let serviceStats = Dictionary(grouping: completedAppointments) { $0.service?.name ?? "Unknown" }
            .map { name, apps in
                (name: name, count: apps.count, revenue: apps.compactMap { $0.service?.price }.reduce(0, +))
            }
            .sorted { $0.revenue > $1.revenue }
        return serviceStats
    }

    private var newClientsCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch selectedPeriod {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        return clients.filter { $0.createdAt >= startDate }.count
    }

    private var returningClientsCount: Int {
        clients.filter { $0.completedVisits > 1 }.count
    }

    private var vipClientsCount: Int {
        clients.filter { $0.loyaltyTier == .vip || $0.loyaltyTier == .elite }.count
    }

    // MARK: - Helpers

    private func calculateRevenue(for period: AnalyticsPeriod, previous: Bool = false) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        var endDate: Date

        switch period {
        case .day:
            endDate = previous ? calendar.date(byAdding: .day, value: -1, to: now)! : now
            startDate = calendar.startOfDay(for: endDate)
        case .week:
            endDate = previous ? calendar.date(byAdding: .day, value: -7, to: now)! : now
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            endDate = previous ? calendar.date(byAdding: .month, value: -1, to: now)! : now
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .year:
            endDate = previous ? calendar.date(byAdding: .year, value: -1, to: now)! : now
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate)!
        }

        return appointments
            .filter { $0.date >= startDate && $0.date <= endDate && $0.status == .completed }
            .compactMap { $0.service?.price }
            .reduce(0, +)
    }

    private func statusCount(_ status: AppointmentStatus) -> Int {
        filteredAppointments.filter { $0.status == status }.count
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = L.currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? (L.currencyCode == "RUB" ? "0 ₽" : "$0")
    }

    private func formatCurrencyShort(_ amount: Decimal) -> String {
        let num = NSDecimalNumber(decimal: amount).doubleValue
        let isRub = L.currencyCode == "RUB"
        if num >= 1000 {
            return isRub ? String(format: "%.1fК ₽", num / 1000) : String(format: "$%.1fK", num / 1000)
        }
        return isRub ? String(format: "%.0f ₽", num) : String(format: "$%.0f", num)
    }
}

// MARK: - Supporting Types

enum AnalyticsPeriod: CaseIterable {
    case day, week, month, year

    var title: String {
        switch self {
        case .day: return L.periodDay
        case .week: return L.periodWeek
        case .month: return L.periodMonth
        case .year: return L.periodYear
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Decimal
}

// MARK: - Supporting Views

struct TopServiceRow: View {
    let rank: Int
    let serviceName: String
    let count: Int
    let revenue: Decimal

    var body: some View {
        GlassCard(padding: Design.Spacing.s) {
            HStack(spacing: Design.Spacing.m) {
                Text("#\(rank)")
                    .font(Design.Typography.headline)
                    .foregroundStyle(rank <= 3 ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(serviceName)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)

                    Text(L.bookingsCount(count))
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }

                Spacer()

                Text(formatCurrency(revenue))
                    .font(Design.Typography.headline)
                    .foregroundStyle(Design.Colors.accentSuccess)
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = L.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? (L.currencyCode == "RUB" ? "0 ₽" : "$0")
    }
}

struct InsightCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        GlassCard(tint: color.opacity(0.1), padding: Design.Spacing.s) {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(value)
                    .font(Design.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(label)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AppointmentStatusRow: View {
    let status: AppointmentStatus
    let count: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)

            Text(status.rawValue.capitalized)
                .font(Design.Typography.body)
                .foregroundStyle(Design.Colors.textPrimary)

            Spacer()

            Text("\(count)")
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textPrimary)

            Text(String(format: "%.0f%%", percentage * 100))
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textTertiary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var appointments: [Appointment]

    @State private var exportType: ExportType = .clients
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: Design.Spacing.l) {
                    // Export type selection
                    VStack(alignment: .leading, spacing: Design.Spacing.s) {
                        Text(L.whatToExport)
                            .font(Design.Typography.headline)

                        ForEach(ExportType.allCases, id: \.self) { type in
                            ExportTypeRow(type: type, isSelected: exportType == type) {
                                HapticManager.selection()
                                exportType = type
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.m)

                    Spacer()

                    // Export button
                    GlassButton(title: L.exportToCSV, icon: "square.and.arrow.up", isFullWidth: true, isLoading: isExporting) {
                        exportData()
                    }
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.bottom, Design.Spacing.l)
                }
                .padding(.top, Design.Spacing.l)
            }
            .navigationTitle(L.exportData)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportData() {
        isExporting = true
        HapticManager.impact(.medium)

        DispatchQueue.global(qos: .userInitiated).async {
            let csv: String
            let filename: String

            switch exportType {
            case .clients:
                csv = generateClientsCSV()
                filename = "solostyle_clients.csv"
            case .appointments:
                csv = generateAppointmentsCSV()
                filename = "solostyle_appointments.csv"
            case .revenue:
                csv = generateRevenueCSV()
                filename = "solostyle_revenue.csv"
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            do {
                try csv.write(to: tempURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    isExporting = false
                    exportedFileURL = tempURL
                    showingShareSheet = true
                    HapticManager.notification(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    HapticManager.notification(.error)
                }
            }
        }
    }

    private func generateClientsCSV() -> String {
        var csv = "Name,Phone,Email,Visits,Total Spent,Loyalty Tier,Created At\n"
        for client in clients {
            let row = "\"\(client.name)\",\"\(client.phone ?? "")\",\"\(client.email ?? "")\",\(client.completedVisits),\(client.totalSpent),\(client.loyaltyTier.rawValue),\(client.createdAt)\n"
            csv += row
        }
        return csv
    }

    private func generateAppointmentsCSV() -> String {
        var csv = "Date,Client,Service,Price,Status\n"
        for appointment in appointments.sorted(by: { $0.date > $1.date }) {
            let row = "\"\(appointment.formattedDate)\",\"\(appointment.client?.name ?? "Unknown")\",\"\(appointment.service?.name ?? "Unknown")\",\(appointment.service?.price ?? 0),\(appointment.status.rawValue)\n"
            csv += row
        }
        return csv
    }

    private func generateRevenueCSV() -> String {
        let completed = appointments.filter { $0.status == .completed }
        let grouped = Dictionary(grouping: completed) { appointment -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: appointment.date)
        }

        var csv = "Month,Appointments,Revenue\n"
        for (month, apps) in grouped.sorted(by: { $0.key > $1.key }) {
            let revenue = apps.compactMap { $0.service?.price }.reduce(0, +)
            csv += "\(month),\(apps.count),\(revenue)\n"
        }
        return csv
    }
}

enum ExportType: CaseIterable {
    case clients, appointments, revenue

    var title: String {
        switch self {
        case .clients: return L.exportClients
        case .appointments: return L.exportAppointments
        case .revenue: return L.exportRevenue
        }
    }

    var icon: String {
        switch self {
        case .clients: return "person.2"
        case .appointments: return "calendar"
        case .revenue: return "chart.bar"
        }
    }

    var description: String {
        switch self {
        case .clients: return L.exportClientsDesc
        case .appointments: return L.exportAppointmentsDesc
        case .revenue: return L.exportRevenueDesc
        }
    }
}

struct ExportTypeRow: View {
    let type: ExportType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.m) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(Design.Typography.headline)
                        .foregroundStyle(Design.Colors.textPrimary)

                    Text(type.description)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
            }
            .padding(Design.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.m)
                    .fill(isSelected ? Design.Colors.accentPrimary.opacity(0.1) : Design.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .strokeBorder(isSelected ? Design.Colors.accentPrimary : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [Appointment.self, Client.self, Service.self], inMemory: true)
}
