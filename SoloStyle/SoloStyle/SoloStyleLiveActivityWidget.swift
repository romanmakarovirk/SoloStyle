//
//  SoloStyleLiveActivityWidget.swift
//  SoloStyle
//
//  Dynamic Island & Lock Screen UI for Live Activities
//
//  NOTE: This file should be included in the Widget Extension target (NOT the main app target).
//  To set up:
//  1. In Xcode: File → New → Target → Widget Extension
//  2. Move this file to the widget extension target
//  3. Also include LiveActivityManager.swift's SoloStyleActivityAttributes in the widget target
//  4. Set "Supports Live Activities = YES" in the main app's Info.plist
//
//  For now, this file is excluded from compilation in the main target.
//  When you create the Widget Extension, add this file to that target's "Compile Sources".
//

/*

import WidgetKit
import SwiftUI

struct SoloStyleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SoloStyleActivityAttributes.self) { context in
            // Lock Screen / Banner view
            HStack(spacing: 12) {
                // Client avatar circle
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    let initials = context.attributes.clientName
                        .split(separator: " ")
                        .prefix(2)
                        .compactMap { $0.first.map(String.init) }
                        .joined()

                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.clientName)
                        .font(.subheadline.bold())
                    Text(context.attributes.serviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(context.state.minutesRemaining)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("min left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.clientName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(context.attributes.serviceName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.minutesRemaining) min")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        Text(context.state.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                        .padding(.horizontal, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(context.attributes.startTime, style: .time)
                            .font(.caption2)
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.endTime, style: .time)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                let initials = context.attributes.clientName
                    .split(separator: " ")
                    .prefix(2)
                    .compactMap { $0.first.map(String.init) }
                    .joined()
                Text(initials)
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(context.state.minutesRemaining)m")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.blue)
            } minimal: {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }
}

*/
