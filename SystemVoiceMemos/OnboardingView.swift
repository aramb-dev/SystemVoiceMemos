//
//  OnboardingView.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 01/13/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppConstants.UserDefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding = false
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    
    enum OnboardingStep {
        case welcome
        case permissions
        case completion
    }
    
    var body: some View {
        ZStack {
            // Animated Gradient Background with liquid-like effect
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.15),
                        Color(red: 0.1, green: 0.15, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Liquid glass ambient orbs
                Group {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.15),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: -150, y: -100)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.12),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 350, height: 350)
                        .blur(radius: 70)
                        .offset(x: 150, y: 100)

                    // Subtle streak
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 200, height: 600)
                        .blur(radius: 60)
                        .offset(x: 100, y: 0)
                }
            }

            VStack(spacing: 0) {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .permissions:
                    permissionsView
                case .completion:
                    completionView
                }
            }
            .frame(maxWidth: 800, maxHeight: 600)
            .background(
                ZStack {
                    // Main glass card
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Inner highlight for depth
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
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
                .overlay {
                    // Border with gradient
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
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
            )
            .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
            .shadow(color: .white.opacity(0.05), radius: 1, y: -1)
            .padding(40)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionManager.checkPermissions()
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Welcome to SystemVoiceMemos")
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Capture your Mac's system audio with professional quality and ease.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring()) {
                    currentStep = .permissions
                }
            } label: {
                Text("Begin Setup")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            // Inner highlight
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 12, y: 6)
                    .shadow(color: Color.white.opacity(0.1), radius: 1, y: -1)
            }
            .buttonStyle(.plain)
            
            Spacer()
                .frame(height: 40)
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity.combined(with: .move(edge: .leading))))
    }
    
    // MARK: - Permissions View
    
    private var permissionsView: some View {
        VStack(spacing: 40) {
            Text("Permissions")
                .font(.system(size: 36, weight: .bold))
            
            VStack(spacing: 20) {
                PermissionCard(
                    title: "Screen Recording",
                    description: "Required to capture system audio stream (no video is recorded).",
                    icon: "record.circle",
                    isAuthorized: permissionManager.isScreenRecordingAuthorized,
                    action: { permissionManager.requestScreenRecordingPermission() }
                )
                
                PermissionCard(
                    title: "Microphone Access",
                    description: "Required if you wish to record external audio devices.",
                    icon: "mic.fill",
                    isAuthorized: permissionManager.isAudioAuthorized,
                    action: {
                        Task {
                            await permissionManager.requestAudioPermission()
                        }
                    }
                )
            }
            .padding(.horizontal, 60)
            
            Button {
                withAnimation(.spring()) {
                    currentStep = .completion
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    permissionManager.isScreenRecordingAuthorized
                                        ? LinearGradient(
                                            colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                )

                            // Inner highlight
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
                    .shadow(color: permissionManager.isScreenRecordingAuthorized ? Color.accentColor.opacity(0.2) : .clear, radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(!permissionManager.isScreenRecordingAuthorized)
            
            if !permissionManager.isScreenRecordingAuthorized {
                Text("Screen Recording permission is essential for capturing system audio.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 60)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(LinearGradient(colors: [.green, .blue], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: currentStep)
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 40, weight: .bold))
                
                Text("SystemVoiceMemos is ready to capture your world. All recordings are stored locally and privately on your Mac.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            // Inner highlight
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 12, y: 6)
                    .shadow(color: Color.white.opacity(0.1), radius: 1, y: -1)
            }
            .buttonStyle(.plain)
            
            Spacer()
                .frame(height: 40)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let isAuthorized: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(isAuthorized ? .green : .blue)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.bordered)
                    .tint(.blue)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)

                // Subtle inner highlight
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isAuthorized
                                ? [Color.green.opacity(0.3), Color.green.opacity(0.15)]
                                : [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let x = rect.minX
        let y = rect.minY
        
        path.move(to: CGPoint(x: x + width * 0.5, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y + height * 0.25))
        path.addLine(to: CGPoint(x: x + width, y: y + height * 0.75))
        path.addLine(to: CGPoint(x: x + width * 0.5, y: y + height))
        path.addLine(to: CGPoint(x: x, y: y + height * 0.75))
        path.addLine(to: CGPoint(x: x, y: y + height * 0.25))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    OnboardingView()
}