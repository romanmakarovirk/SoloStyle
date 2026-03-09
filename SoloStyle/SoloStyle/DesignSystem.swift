//
//  DesignSystem.swift
//  SoloStyle
//
//  Design tokens for iOS 26 Liquid Glass
//  Premium design system with animations
//

import SwiftUI

enum Design {
    // MARK: - Colors
    enum Colors {
        // Backgrounds
        static let backgroundPrimary = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let backgroundTertiary = Color(.tertiarySystemBackground)

        // Text
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)

        // Accents
        static let accentPrimary = Color.blue
        static let accentSuccess = Color.green
        static let accentWarning = Color.orange
        static let accentError = Color.red

        // Glass
        static let glassTint = Color.white.opacity(0.1)
        static let glassTintAccent = Color.blue.opacity(0.15)

        // Gradients
        static let premiumGradient = LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let sunriseGradient = LinearGradient(
            colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let caption1 = Font.caption
        static let caption2 = Font.caption2
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.6)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)

        // Page transitions
        static let pageTransition = AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )

        static let fadeScale = AnyTransition.scale(scale: 0.95).combined(with: .opacity)
    }

    // MARK: - Shadows
    enum Shadow {
        static func soft(color: Color = .black.opacity(0.1)) -> some View {
            EmptyView()
        }

        static let cardShadow = (color: Color.black.opacity(0.08), radius: CGFloat(12), y: CGFloat(4))
        static let buttonShadow = (color: Color.blue.opacity(0.3), radius: CGFloat(8), y: CGFloat(4))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card shadow
    func cardShadow() -> some View {
        self.shadow(
            color: Design.Shadow.cardShadow.color,
            radius: Design.Shadow.cardShadow.radius,
            y: Design.Shadow.cardShadow.y
        )
    }

    /// Apply button shadow
    func buttonShadow() -> some View {
        self.shadow(
            color: Design.Shadow.buttonShadow.color,
            radius: Design.Shadow.buttonShadow.radius,
            y: Design.Shadow.buttonShadow.y
        )
    }

    /// Animate appearance
    func animateOnAppear(delay: Double = 0) -> some View {
        self.modifier(AppearAnimationModifier(delay: delay))
    }

    /// Subtle animate appearance (smaller offset for less dramatic entry)
    func animateOnAppearSubtle(delay: Double = 0) -> some View {
        self.modifier(SubtleAppearAnimationModifier(delay: delay))
    }

    /// Shake animation for errors
    func shake(_ shake: Bool) -> some View {
        self.modifier(ShakeModifier(shake: shake))
    }
}

// MARK: - iOS 26 Liquid Glass
// Using native SwiftUI .glassEffect() modifier
// GlassEffectContainer from SwiftUI provides morphing and grouping

// MARK: - Animation Modifiers

struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(Design.Animation.smooth.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

struct SubtleAppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 6)
            .animation(Design.Animation.smooth.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

struct ShakeModifier: ViewModifier {
    let shake: Bool
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: shake) { _, newValue in
                if newValue {
                    withAnimation(.linear(duration: 0.05).repeatCount(5)) {
                        shakeOffset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Int
    let font: Font

    @State private var animatedValue: Int = 0

    var body: some View {
        Text("\(animatedValue)")
            .font(font)
            .contentTransition(.numericText())
            .onChange(of: value) { _, newValue in
                withAnimation(Design.Animation.smooth) {
                    animatedValue = newValue
                }
            }
            .onAppear {
                animatedValue = value
            }
    }
}

// MARK: - Parallax Header

struct ParallaxHeader<Content: View>: View {
    let height: CGFloat
    let content: Content

    init(height: CGFloat = 300, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let isScrollingUp = minY > 0

            content
                .frame(width: geometry.size.width, height: height + (isScrollingUp ? minY : 0))
                .offset(y: isScrollingUp ? -minY : 0)
                .clipped()
        }
        .frame(height: height)
    }
}

// MARK: - Morphing Shape

struct MorphingShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let wave = sin(progress * .pi * 2) * 10

        path.move(to: CGPoint(x: 0, y: height * 0.5 + wave))
        path.addQuadCurve(
            to: CGPoint(x: width, y: height * 0.5 - wave),
            control: CGPoint(x: width * 0.5, y: height * 0.5 + wave * 2)
        )
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Input Validation

enum InputValidator {
    /// Validates email format
    static func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return true } // Empty is OK (optional field)
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    /// Validates phone number (allows common formats)
    static func isValidPhone(_ phone: String) -> Bool {
        guard !phone.isEmpty else { return true } // Empty is OK (optional field)
        // Remove common formatting characters
        let cleaned = phone.replacingOccurrences(of: "[\\s\\-\\(\\)\\.]", with: "", options: .regularExpression)
        // Should contain only digits and optionally start with +
        let phoneRegex = #"^\+?[0-9]{7,15}$"#
        return cleaned.range(of: phoneRegex, options: .regularExpression) != nil
    }

    /// Sanitizes input string - removes potentially dangerous characters
    static func sanitize(_ input: String) -> String {
        // Remove control characters and limit length
        let maxLength = 500
        let sanitized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]", with: "", options: .regularExpression)
        return String(sanitized.prefix(maxLength))
    }

    /// Validates name (non-empty, reasonable length)
    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 100
    }

    /// Validates price input
    static func isValidPrice(_ price: String) -> Bool {
        guard !price.isEmpty else { return false }
        guard let value = Decimal(string: price) else { return false }
        return value >= 0 && value <= 99999
    }
    
    /// Creates a safe phone URL
    static func safePhoneURL(_ phone: String) -> URL? {
        guard isValidPhone(phone) else { return nil }
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return URL(string: "tel:\(cleaned)")
    }
    
    /// Creates a safe SMS URL
    static func safeSMSURL(_ phone: String, body: String? = nil) -> URL? {
        guard isValidPhone(phone) else { return nil }
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        var components = URLComponents(string: "sms:\(cleaned)")
        if let body = body, !body.isEmpty {
            let sanitizedBody = sanitize(body)
            components?.queryItems = [URLQueryItem(name: "body", value: sanitizedBody)]
        }
        return components?.url
    }
    
    /// Creates a safe email URL
    static func safeEmailURL(_ email: String, subject: String? = nil, body: String? = nil) -> URL? {
        guard isValidEmail(email) else { return nil }
        var components = URLComponents(string: "mailto:\(email)")
        var queryItems: [URLQueryItem] = []
        if let subject = subject, !subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: sanitize(subject)))
        }
        if let body = body, !body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: sanitize(body)))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
}
