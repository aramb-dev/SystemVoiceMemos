//
//  GlassBackground.swift
//  SystemVoiceMemos
//

import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Base material with subtle gradient
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // Inner highlight for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            // Subtle border highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03),
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

struct ThinGlassBackground: View {
    var cornerRadius: CGFloat = 16
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - View Extension

extension View {
    func glassBackground(cornerRadius: CGFloat = 20) -> some View {
        self.background(GlassBackground(cornerRadius: cornerRadius))
    }
    
    func thinGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(ThinGlassBackground(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Glass Background")
            .padding()
            .glassBackground()
        
        Text("Thin Glass Background")
            .padding()
            .thinGlassBackground()
    }
    .padding()
    .background(Color.gray)
}
