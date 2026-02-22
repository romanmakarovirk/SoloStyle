//
//  SoloStyleWidget.swift
//  SoloStyleWidget
//
//  Home Screen Widgets for quick access
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Timeline Entry

struct SoloStyleEntry: TimelineEntry {
    let date: Date
    let todayAppointments: Int
    let upcomingAppointments: [(clientName: String, serviceName: String, time: Date)]
    let weekRevenue: Decimal
    let nextAppointmentTime: Date?
}

// MARK: - Widget Provider

struct SoloStyleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SoloStyleEntry {
        SoloStyleEntry(
            date: Date(),
            todayAppointments: 5,
            upcomingAppointments: [
                ("Anna Smith", "Haircut", Date().addingTimeInterval(3600)),
                ("John Doe", "Coloring", Date().addingTimeInterval(7200)),
                ("Sarah Wilson", "Styling", Date().addingTimeInterval(10800))
            ],
            weekRevenue: 1250,
            nextAppointmentTime: Date().addingTimeInterval(3600)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SoloStyleEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SoloStyleEntry>) -> ()) {
        // Create a timeline entry for now
        let currentDate = Date()
        let entry = SoloStyleEntry(
            date: currentDate,
            todayAppointments: 3,
            upcomingAppointments: [],
            weekRevenue: 850,
            nextAppointmentTime: nil
        )

        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: SoloStyleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scissors")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("SoloStyle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.todayAppointments)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Today's Appointments")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let nextTime = entry.nextAppointmentTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("Next: \(nextTime, style: .time)")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: SoloStyleEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scissors")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    Text("SoloStyle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.todayAppointments)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Appointments")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .padding(.vertical, 8)

            // Right side - upcoming list
            VStack(alignment: .leading, spacing: 6) {
                Text("Upcoming")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if entry.upcomingAppointments.isEmpty {
                    Text("No appointments")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxHeight: .infinity)
                } else {
                    ForEach(entry.upcomingAppointments.prefix(3), id: \.time) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.clientName)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)

                                Text(item.time, style: .time)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: SoloStyleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "scissors")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                Text("SoloStyle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Stats row
            HStack(spacing: 16) {
                StatBox(value: "\(entry.todayAppointments)", label: "Today", icon: "calendar", color: .blue)
                StatBox(value: formatCurrency(entry.weekRevenue), label: "This Week", icon: "dollarsign.circle", color: .green)
            }

            Divider()

            // Upcoming appointments
            Text("Today's Schedule")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            if entry.upcomingAppointments.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No appointments today")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.upcomingAppointments.prefix(4), id: \.time) { item in
                    HStack(spacing: 12) {
                        VStack {
                            Text(item.time, style: .time)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(width: 50)

                        Rectangle()
                            .fill(.blue)
                            .frame(width: 3)
                            .cornerRadius(1.5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.clientName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Text(item.serviceName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(.ultraThinMaterial, for: .widget)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Main Widget

@main
struct SoloStyleWidget: Widget {
    let kind: String = "SoloStyleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoloStyleProvider()) { entry in
            SoloStyleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SoloStyle")
        .description("Quick view of your appointments and schedule")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SoloStyleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SoloStyleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    SoloStyleWidget()
} timeline: {
    SoloStyleEntry(
        date: Date(),
        todayAppointments: 5,
        upcomingAppointments: [],
        weekRevenue: 1250,
        nextAppointmentTime: Date().addingTimeInterval(3600)
    )
}

#Preview("Medium", as: .systemMedium) {
    SoloStyleWidget()
} timeline: {
    SoloStyleEntry(
        date: Date(),
        todayAppointments: 5,
        upcomingAppointments: [
            ("Anna Smith", "Haircut", Date().addingTimeInterval(3600)),
            ("John Doe", "Coloring", Date().addingTimeInterval(7200)),
            ("Sarah Wilson", "Styling", Date().addingTimeInterval(10800))
        ],
        weekRevenue: 1250,
        nextAppointmentTime: Date().addingTimeInterval(3600)
    )
}

#Preview("Large", as: .systemLarge) {
    SoloStyleWidget()
} timeline: {
    SoloStyleEntry(
        date: Date(),
        todayAppointments: 5,
        upcomingAppointments: [
            ("Anna Smith", "Haircut", Date().addingTimeInterval(3600)),
            ("John Doe", "Coloring", Date().addingTimeInterval(7200)),
            ("Sarah Wilson", "Styling", Date().addingTimeInterval(10800)),
            ("Mike Brown", "Beard Trim", Date().addingTimeInterval(14400))
        ],
        weekRevenue: 1250,
        nextAppointmentTime: Date().addingTimeInterval(3600)
    )
}
