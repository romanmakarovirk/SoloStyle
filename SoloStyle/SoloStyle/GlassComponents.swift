//
//  GlassComponents.swift
//  SoloStyle
//
//  iOS 26 Liquid Glass UI Components
//  Using native .glassEffect() modifier
//

import SwiftUI

// MARK: - Haptic Feedback

enum HapticManager {
    // Reuse generators — creating new ones on every tap wastes allocations
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGen = UINotificationFeedbackGenerator()
    private static let selectionGen = UISelectionFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light:  lightImpact.impactOccurred()
        case .medium: mediumImpact.impactOccurred()
        case .heavy:  heavyImpact.impactOccurred()
        default:      mediumImpact.impactOccurred()
        }
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGen.notificationOccurred(type)
    }

    static func selection() {
        selectionGen.selectionChanged()
    }
}

// MARK: - Cross-version Glass Effect Shim

enum SoloGlassShape {
    case circle
    case capsule
    case roundedRect(CGFloat)
    case plain
}

extension View {
    @ViewBuilder
    func soloGlass(
        tint: Color = Color.white.opacity(0.1),
        interactive: Bool = false,
        shape: SoloGlassShape = .roundedRect(Design.Radius.l)
    ) -> some View {
        if #available(iOS 26, *) {
            _soloGlassNative(tint: tint, interactive: interactive, shape: shape)
        } else {
            _soloGlassFallback(tint: tint, shape: shape)
        }
    }

    @available(iOS 26, *)
    @ViewBuilder
    private func _soloGlassNative(tint: Color, interactive: Bool, shape: SoloGlassShape) -> some View {
        switch shape {
        case .circle:
            if interactive { self.glassEffect(.regular.tint(tint).interactive(), in: .circle) }
            else { self.glassEffect(.regular.tint(tint), in: .circle) }
        case .capsule:
            if interactive { self.glassEffect(.regular.tint(tint).interactive(), in: .capsule) }
            else { self.glassEffect(.regular.tint(tint), in: .capsule) }
        case .roundedRect(let r):
            if interactive { self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: r)) }
            else { self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: r)) }
        case .plain:
            if interactive { self.glassEffect(.regular.tint(tint).interactive()) }
            else { self.glassEffect(.regular.tint(tint)) }
        }
    }

    @ViewBuilder
    private func _soloGlassFallback(tint: Color, shape: SoloGlassShape) -> some View {
        switch shape {
        case .circle:
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        case .capsule:
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        case .roundedRect(let r):
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: r))
                .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        case .plain:
            self.background(.ultraThinMaterial)
        }
    }
}

// MARK: - Liquid Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var tint: Color
    var cornerRadius: CGFloat
    var padding: CGFloat
    var isInteractive: Bool

    @State private var isPressed = false

    init(
        tint: Color = Color.white.opacity(0.1),
        cornerRadius: CGFloat = Design.Radius.l,
        padding: CGFloat = Design.Spacing.m,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .soloGlass(tint: tint, shape: .roundedRect(cornerRadius))
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(Design.Animation.smooth, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                if isInteractive {
                    isPressed = pressing
                    if pressing { HapticManager.impact(.light) }
                }
            }, perform: {})
    }
}

// MARK: - Liquid Glass Button

struct GlassButton: View {
    let title: String
    var icon: String?
    var style: GlassButtonStyle = .primary
    var isFullWidth: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    enum GlassButtonStyle {
        case primary, secondary, destructive, prominent

        var tint: Color {
            switch self {
            case .primary: Color.blue.opacity(0.2)
            case .secondary: Color.white.opacity(0.1)
            case .destructive: Color.red.opacity(0.2)
            case .prominent: Color.blue.opacity(0.4)
            }
        }

        var foreground: Color {
            switch self {
            case .primary: .blue
            case .secondary: Design.Colors.textPrimary
            case .destructive: .red
            case .prominent: .white
            }
        }
    }

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            action()
        } label: {
            HStack(spacing: Design.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(style.foreground)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(Design.Typography.headline)
                }
            }
            .foregroundStyle(style.foreground)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, Design.Spacing.l)
            .padding(.vertical, Design.Spacing.s)
        }
        .soloGlass(tint: style.tint, interactive: true, shape: .capsule)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(Design.Animation.bouncy, value: isPressed)
        .disabled(isLoading)
    }
}

// MARK: - Liquid Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var tint: Color = Color.white.opacity(0.1)
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(Design.Colors.accentPrimary)
                .frame(width: size, height: size)
        }
        .soloGlass(tint: tint, interactive: true, shape: .circle)
    }
}

// MARK: - Tab Bar

enum Tab: String, CaseIterable, Identifiable {
    case calendar, clients, ai, profile, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: L.tabCalendar
        case .clients: L.tabClients
        case .ai: L.tabAI
        case .profile: L.tabProfile
        case .settings: L.tabSettings
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar.badge.clock"
        case .clients: "person.2"
        case .ai: "sparkles"
        case .profile: "person.circle"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .calendar: "calendar.badge.clock"
        case .clients: "person.2.fill"
        case .ai: "sparkles"
        case .profile: "person.circle.fill"
        case .settings: "gearshape.fill"
        }
    }

    var isAI: Bool {
        self == .ai
    }
}

struct GlassTabBar: View {
    @Binding var selectedTab: Tab
    @Namespace private var namespace

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    HStack(spacing: 0) {
                        ForEach(Tab.allCases) { tab in
                            TabBarItem(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                namespace: namespace
                            ) {
                                HapticManager.selection()
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.m)
                    .padding(.vertical, Design.Spacing.s)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        TabBarItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            namespace: namespace
                        ) {
                            HapticManager.selection()
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, Design.Spacing.m)
                .padding(.vertical, Design.Spacing.s)
            }
        }
        .soloGlass(tint: Color.white.opacity(0.1), shape: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, Design.Spacing.s)
        .padding(.bottom, 8)
    }
}

struct TabBarItem: View {
    let tab: Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    private var aiGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if tab.isAI {
                    // Special AI tab with gradient
                    Image(systemName: tab.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolEffect(.bounce.up, value: isSelected)
                        .foregroundStyle(isSelected ? AnyShapeStyle(aiGradient) : AnyShapeStyle(Design.Colors.textSecondary))
                        .frame(width: 62, height: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "tabBackground", in: namespace)
                            }
                        }
                } else {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .symbolEffect(.bounce, value: isSelected)
                        .frame(width: 62, height: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Design.Colors.accentPrimary.opacity(0.2))
                                    .matchedGeometryEffect(id: "tabBackground", in: namespace)
                            }
                        }
                }

                Text(tab.title)
                    .font(.system(size: 10))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(
                tab.isAI && isSelected
                    ? AnyShapeStyle(aiGradient)
                    : AnyShapeStyle(isSelected ? Design.Colors.accentPrimary : Design.Colors.textSecondary)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(TabBarItemGlassIDModifier(id: tab.id, namespace: namespace))
    }
}

// Helper to conditionally apply .glassEffectID only on iOS 26+
private struct TabBarItemGlassIDModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Floating Action Button (No flying circle)

struct GlassFAB: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            withAnimation(Design.Animation.bouncy) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
            }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(isPressed ? 90 : 0))
        }
        .soloGlass(tint: Color.blue.opacity(0.6), interactive: true, shape: .circle)
        .shadow(color: Design.Colors.accentPrimary.opacity(0.4), radius: 16, y: 8)
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Animated Form Field

struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Text(title)
                .font(Design.Typography.caption1)
                .foregroundStyle(isFocused ? Design.Colors.accentPrimary : Design.Colors.textSecondary)
                .animation(Design.Animation.smooth, value: isFocused)

            HStack(spacing: Design.Spacing.s) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(isFocused ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                        .frame(width: 24)
                        .symbolEffect(.bounce, value: isFocused)
                }

                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .focused($isFocused)

                if !text.isEmpty && isFocused {
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(Design.Animation.quick) {
                            text = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Design.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.m)
                    .fill(Design.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.Radius.m)
                            .strokeBorder(
                                isFocused ? Design.Colors.accentPrimary : .clear,
                                lineWidth: 2
                            )
                    )
            )
            .animation(Design.Animation.smooth, value: isFocused)
        }
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                Design.Colors.backgroundSecondary,
                Design.Colors.backgroundSecondary.opacity(0.5),
                Design.Colors.backgroundSecondary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 200 : -200)
        .animation(
            .linear(duration: 1.5).repeatForever(autoreverses: false),
            value: isAnimating
        )
        .onAppear { isAnimating = true }
    }
}

struct SkeletonCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: Design.Spacing.m) {
                Circle()
                    .fill(Design.Colors.backgroundSecondary)
                    .frame(width: 44, height: 44)
                    .overlay(ShimmerView())
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Design.Colors.backgroundSecondary)
                        .frame(width: 120, height: 16)
                        .overlay(ShimmerView())
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Design.Colors.backgroundSecondary)
                        .frame(width: 80, height: 12)
                        .overlay(ShimmerView())
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Design.Spacing.l) {
            ZStack {
                Circle()
                    .fill(Design.Colors.accentPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Design.Colors.accentPrimary.opacity(0.7))
            }

            VStack(spacing: Design.Spacing.s) {
                Text(title)
                    .font(Design.Typography.title3)
                    .foregroundStyle(Design.Colors.textPrimary)

                Text(subtitle)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.xl)
            }

            if let actionTitle, let action {
                GlassButton(title: actionTitle, icon: "plus", action: action)
                    .padding(.top, Design.Spacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.xxl)
    }
}

// MARK: - Toast Notification

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool

    enum ToastType {
        case success, error, info

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: Design.Colors.accentSuccess
            case .error: Design.Colors.accentError
            case .info: Design.Colors.accentPrimary
            }
        }
    }

    var body: some View {
        if isShowing {
            HStack(spacing: Design.Spacing.s) {
                Image(systemName: type.icon)
                    .foregroundStyle(type.color)

                Text(message)
                    .font(Design.Typography.subheadline)
                    .foregroundStyle(Design.Colors.textPrimary)
            }
            .padding(.horizontal, Design.Spacing.m)
            .padding(.vertical, Design.Spacing.s)
            .soloGlass(tint: type.color.opacity(0.15), shape: .capsule)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                HapticManager.notification(type == .error ? .error : .success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(Design.Animation.smooth) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Swipe Action Card

struct SwipeActionCard<Content: View>: View {
    let content: Content
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var showingActions = false

    init(
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: Design.Spacing.xs) {
                if let onEdit {
                    Button {
                        HapticManager.impact(.medium)
                        onEdit()
                        resetOffset()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Design.Colors.accentPrimary, in: RoundedRectangle(cornerRadius: Design.Radius.m))
                    }
                }

                if let onDelete {
                    Button {
                        HapticManager.notification(.warning)
                        onDelete()
                        resetOffset()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Design.Colors.accentError, in: RoundedRectangle(cornerRadius: Design.Radius.m))
                    }
                }
            }
            .padding(.trailing, Design.Spacing.s)
            .opacity(showingActions ? 1 : 0)

            GlassCard(isInteractive: true) {
                content
            }
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(Design.Animation.smooth) {
                            if value.translation.width < -80 {
                                offset = -140
                                showingActions = true
                                HapticManager.impact(.light)
                            } else {
                                resetOffset()
                            }
                        }
                    }
            )
        }
    }

    private func resetOffset() {
        withAnimation(Design.Animation.smooth) {
            offset = 0
            showingActions = false
        }
    }
}

// MARK: - Refreshable Scroll View

struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void

    init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            HapticManager.impact(.medium)
            await onRefresh()
        }
    }
}

// MARK: - Segmented Picker with Glass Effect

struct GlassSegmentedPicker<T: Hashable & CaseIterable & CustomStringConvertible>: View where T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    @Namespace private var namespace

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    HStack(spacing: 4) {
                        ForEach(Array(T.allCases), id: \.self) { item in
                            Button {
                                HapticManager.selection()
                                withAnimation(Design.Animation.smooth) {
                                    selection = item
                                }
                            } label: {
                                Text(item.description)
                                    .font(Design.Typography.subheadline)
                                    .fontWeight(selection == item ? .semibold : .regular)
                                    .foregroundStyle(selection == item ? Design.Colors.accentPrimary : Design.Colors.textSecondary)
                                    .padding(.horizontal, Design.Spacing.m)
                                    .padding(.vertical, Design.Spacing.xs)
                            }
                            .soloGlass(
                                tint: selection == item ? Color.blue.opacity(0.15) : Color.clear,
                                shape: .capsule
                            )
                            .glassEffectID(String(describing: item), in: namespace)
                        }
                    }
                    .padding(4)
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(T.allCases), id: \.self) { item in
                        Button {
                            HapticManager.selection()
                            withAnimation(Design.Animation.smooth) {
                                selection = item
                            }
                        } label: {
                            Text(item.description)
                                .font(Design.Typography.subheadline)
                                .fontWeight(selection == item ? .semibold : .regular)
                                .foregroundStyle(selection == item ? Design.Colors.accentPrimary : Design.Colors.textSecondary)
                                .padding(.horizontal, Design.Spacing.m)
                                .padding(.vertical, Design.Spacing.xs)
                        }
                        .soloGlass(
                            tint: selection == item ? Color.blue.opacity(0.15) : Color.clear,
                            shape: .capsule
                        )
                    }
                }
                .padding(4)
            }
        }
        .soloGlass(tint: Color.white.opacity(0.05), shape: .plain)
    }
}

// MARK: - Glass Chip / Tag

struct GlassChip: View {
    let title: String
    var icon: String?
    var isSelected: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            HapticManager.selection()
            action?()
        } label: {
            HStack(spacing: Design.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(Design.Typography.caption1)
            }
            .foregroundStyle(isSelected ? .white : Design.Colors.textSecondary)
            .padding(.horizontal, Design.Spacing.s)
            .padding(.vertical, Design.Spacing.xs)
        }
        .soloGlass(tint: isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), shape: .capsule)
    }
}

// MARK: - Glass Search Bar

struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Design.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused ? Design.Colors.accentPrimary : Design.Colors.textTertiary)
                .symbolEffect(.bounce, value: isFocused)

            TextField(placeholder, text: $text)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    HapticManager.impact(.light)
                    withAnimation(Design.Animation.quick) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Design.Colors.textTertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(Design.Spacing.s)
        .soloGlass(tint: Color.white.opacity(0.1), shape: .capsule)
        .animation(Design.Animation.smooth, value: isFocused)
    }
}

// MARK: - Glass Action Sheet Item

struct GlassActionItem: View {
    let title: String
    let icon: String
    var tint: Color = Design.Colors.accentPrimary
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            action()
        } label: {
            HStack(spacing: Design.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isDestructive ? .red : tint)
                    .frame(width: 32)

                Text(title)
                    .font(Design.Typography.body)
                    .foregroundStyle(isDestructive ? .red : Design.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .padding(Design.Spacing.m)
        }
        .soloGlass(tint: Color.white.opacity(0.05), interactive: true, shape: .roundedRect(Design.Radius.m))
    }
}

// MARK: - Glass Toggle

struct GlassToggle: View {
    let title: String
    var subtitle: String?
    var icon: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Design.Colors.accentPrimary)
                    .frame(width: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(Design.Colors.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Design.Colors.accentPrimary)
                .labelsHidden()
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.m))
        .onChange(of: isOn) { _, _ in
            HapticManager.selection()
        }
    }
}

// MARK: - Profile Avatar

struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 60
    var showStatus: Bool = false

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .soloGlass(tint: Color.blue.opacity(0.4), shape: .circle)
        .overlay(alignment: .bottomTrailing) {
            if showStatus {
                Circle()
                    .fill(Design.Colors.accentSuccess)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(Design.Colors.backgroundPrimary, lineWidth: 2)
                    )
            }
        }
    }
}

// MARK: - Glass Info Row

struct GlassInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = Design.Colors.accentPrimary

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(title)
                .font(Design.Typography.subheadline)
                .foregroundStyle(Design.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Design.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(Design.Colors.textPrimary)
        }
        .padding(Design.Spacing.m)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.m))
    }
}

// MARK: - Stat Card

struct GlassStatCard: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = Design.Colors.accentPrimary

    var body: some View {
        VStack(spacing: Design.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(tint)

            Text(value)
                .font(Design.Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(Design.Colors.textPrimary)

            Text(label)
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Design.Spacing.m)
        .soloGlass(tint: tint.opacity(0.1), shape: .roundedRect(Design.Radius.l))
    }
}

// MARK: - Cached Async Image

/// In-memory image cache to avoid re-downloading profile photos on every view appear.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    private static var cache: NSCache<NSURL, UIImage> {
        let c = _imageCache
        return c
    }

    var body: some View {
        if let uiImage {
            content(Image(uiImage: uiImage))
        } else {
            placeholder()
                .task(id: url) {
                    if let cached = Self.cache.object(forKey: url as NSURL) {
                        self.uiImage = cached
                        return
                    }
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let img = UIImage(data: data) else { return }
                    Self.cache.setObject(img, forKey: url as NSURL)
                    self.uiImage = img
                }
        }
    }
}

/// Shared image cache singleton (NSCache is thread-safe)
private let _imageCache: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.countLimit = 50
    return cache
}()
