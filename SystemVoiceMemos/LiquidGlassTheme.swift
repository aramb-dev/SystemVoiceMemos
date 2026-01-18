//
//  LiquidGlassTheme.swift
//  SystemVoiceMemos
//
//  Liquid Glass Design System for macOS Tahoe
//

import SwiftUI

// MARK: - Liquid Glass Material

struct LiquidGlassMaterial: ViewModifier {
    var intensity: Double = 1.0
    var hasBorder: Bool = true
    var hasInnerShadow: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base material
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(intensity))

                    // Subtle inner highlight
                    if hasInnerShadow {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.clear,
                                        Color.black.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay {
                if hasBorder {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
    }
}

extension View {
    func liquidGlass(intensity: Double = 1.0, hasBorder: Bool = true, hasInnerShadow: Bool = false) -> some View {
        modifier(LiquidGlassMaterial(intensity: intensity, hasBorder: hasBorder, hasInnerShadow: hasInnerShadow))
    }
}

// MARK: - Liquid Glass Shadow

struct LiquidGlassShadow: ViewModifier {
    var depth: GlassDepth = .medium

    enum GlassDepth {
        case shallow, medium, deep
    }

    var shadowColor: Color {
        switch depth {
        case .shallow: return .black.opacity(0.05)
        case .medium: return .black.opacity(0.08)
        case .deep: return .black.opacity(0.12)
        }
    }

    var shadowRadius: CGFloat {
        switch depth {
        case .shallow: return 8
        case .medium: return 12
        case .deep: return 20
        }
    }

    var shadowOffset: CGFloat {
        switch depth {
        case .shallow: return 2
        case .medium: return 6
        case .deep: return 10
        }
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
            .shadow(color: Color.white.opacity(0.1), radius: 1, y: -1)
    }
}

extension View {
    func liquidGlassShadow(depth: LiquidGlassShadow.GlassDepth = .medium) -> some View {
        modifier(LiquidGlassShadow(depth: depth))
    }
}

// MARK: - Liquid Glass Button

struct LiquidGlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isProminent {
                        // Prominent button with gradient
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: buttonGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        // Secondary glass button
                        Capsule()
                            .fill(.regularMaterial)
                    }

                    // Hover highlight
                    if configuration.isPressed {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    }
                }
            )
            .overlay {
                if !isProminent {
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var buttonGradientColors: [Color] {
        if isDestructive {
            return [Color.red.opacity(0.9), Color.red.opacity(0.7)]
        }
        return [
            Color.accentColor.opacity(0.9),
            Color.accentColor.opacity(0.7)
        ]
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle { LiquidGlassButtonStyle() }
    static var liquidGlassProminent: LiquidGlassButtonStyle { LiquidGlassButtonStyle(isProminent: true) }
    static var liquidGlassDestructive: LiquidGlassButtonStyle { LiquidGlassButtonStyle(isProminent: true, isDestructive: true) }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var depth: LiquidGlassShadow.GlassDepth = .medium

    init(padding: CGFloat = 16, depth: LiquidGlassShadow.GlassDepth = .medium, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.depth = depth
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)

                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.black.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .liquidGlassShadow(depth: depth)
    }
}

// MARK: - Liquid Glass Icon Button

struct LiquidGlassIconButton: View {
    let icon: String
    let action: () -> Void
    var isActive: Bool = false
    var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        if isActive {
                            Circle()
                                .fill(Color.accentColor)
                        } else {
                            Circle()
                                .fill(.regularMaterial)
                        }
                    }
                )
                .overlay {
                    if !isActive {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    VStack(spacing: 32) {
        // Cards
        HStack(spacing: 16) {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shallow")
                        .font(.headline)
                    Text("Light depth shadow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LiquidGlassCard(depth: .deep) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deep")
                        .font(.headline)
                    Text("Heavy depth shadow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        // Buttons
        HStack(spacing: 12) {
            Button("Secondary") {}
                .buttonStyle(.liquidGlass)

            Button("Primary") {}
                .buttonStyle(.liquidGlassProminent)
                .foregroundStyle(.white)

            Button("Delete") {}
                .buttonStyle(.liquidGlassDestructive)
                .foregroundStyle(.white)
        }

        // Icon Buttons
        HStack(spacing: 12) {
            LiquidGlassIconButton(icon: "play.fill", action: {})
            LiquidGlassIconButton(icon: "pause.fill", action: {}, isActive: true)
            LiquidGlassIconButton(icon: "stop.fill", action: {})
        }

        // Panel
        VStack(alignment: .leading, spacing: 12) {
            Text("Panel with Glass Effect")
                .font(.headline)
            Text("This panel uses the liquid glass modifier with subtle borders and shadows.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .liquidGlass(hasBorder: true, hasInnerShadow: true)
        .liquidGlassShadow(depth: .medium)
        .frame(width: 280)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        ZStack {
            Color.black
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -100, y: -100)
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 100, y: 100)
        }
    )
}
