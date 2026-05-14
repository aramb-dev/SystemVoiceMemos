//
//  MicSetupGuideView.swift
//  SystemVoiceMemos
//
//  One-time per-version guide that walks users through the microphone
//  features introduced in this release (mic tracks, mute/unmute, source
//  selection).  Shown automatically after What's New when upgrading.
//

import AVFoundation
import SwiftUI

struct MicSetupGuideView: View {
    let onDone: () -> Void

    @StateObject private var permissionManager = PermissionManager.shared
    @State private var currentStep: Step = .intro
    @State private var navigatingForward = true

    enum Step: Int, CaseIterable {
        case intro = 0
        case permissions = 1
        case features = 2
        case done = 3
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                stepContent
                    .transition(slideTransition)
            }
            .frame(maxWidth: 680, maxHeight: 560)
            .background(glassCard)
            .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
            .padding(40)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionManager.checkPermissions()
        }
    }

    // MARK: - Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .intro:       introStep
        case .permissions: permissionsStep
        case .features:    featuresStep
        case .done:        doneStep
        }
    }

    private func advance() {
        let all = Step.allCases
        guard let idx = all.firstIndex(of: currentStep), idx + 1 < all.count else {
            onDone()
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            navigatingForward = true
            currentStep = all[idx + 1]
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: navigatingForward ? .move(edge: .trailing).combined(with: .opacity) : .move(edge: .leading).combined(with: .opacity),
            removal:   navigatingForward ? .move(edge: .leading).combined(with: .opacity)  : .move(edge: .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.blue.opacity(0.35), Color.clear], center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 12) {
                Text("Microphone Recording is Here")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Record your mic alongside system audio, mute it on the fly during recording, and choose exactly which tracks to capture and export.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button("Let's Set It Up") { advance() }
                .buttonStyle(GlassCapsuleButtonStyle())

            Spacer().frame(height: 32)
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 32) {
            Text("Microphone Access")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 48)

            Text("System Voice Memos needs microphone permission to record external audio.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            VStack(spacing: 16) {
                micPermissionCard
                sourceInfoCard
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Continue") { advance() }
                .buttonStyle(GlassCapsuleButtonStyle(
                    tintColor: .accentColor,
                    horizontalPadding: 60
                ))

            Spacer().frame(height: 32)
        }
    }

    private var micPermissionCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(permissionManager.isAudioAuthorized ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: permissionManager.isAudioAuthorized ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 22))
                    .foregroundColor(permissionManager.isAudioAuthorized ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Microphone")
                    .font(.headline)
                Text(permissionManager.isAudioAuthorized ? "Permission granted" : "Tap Grant to allow access")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !permissionManager.isAudioAuthorized {
                Button(AVCaptureDevice.authorizationStatus(for: .audio) == .denied ? "Settings" : "Grant") {
                    if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
                        permissionManager.openMicrophoneSettings()
                    } else {
                        Task { await permissionManager.requestAudioPermission() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
        )
    }

    private var sourceInfoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recording Source")
                    .font(.headline)
                Text("In Settings, choose \u{201c}Mic + System Audio\u{201d} to capture both tracks at once.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
        )
    }

    private var featuresStep: some View {
        VStack(spacing: 0) {
            Text("What You Can Do")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 48)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 18) {
                featureRow(
                    icon: "mic.fill",
                    tint: .blue,
                    title: "Record Mic + System Audio",
                    detail: "Enable \u{201c}Include Microphone\u{201d} in Settings to capture both simultaneously as separate tracks."
                )
                featureRow(
                    icon: "mic.slash.fill",
                    tint: .orange,
                    title: "Mute Mic on the Fly",
                    detail: "Tap the mic button in the recording toolbar to mute your microphone mid-recording. The recording continues uninterrupted — your system audio track is unaffected."
                )
                featureRow(
                    icon: "waveform.and.mic",
                    tint: .purple,
                    title: "Play & Export Each Track",
                    detail: "In playback, use the track sliders to control system audio and mic levels independently, or export them as separate files."
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Got It") { advance() }
                .buttonStyle(GlassCapsuleButtonStyle(
                    tintColor: .accentColor,
                    horizontalPadding: 60
                ))

            Spacer().frame(height: 32)
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(LinearGradient(colors: [.green, .blue], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: currentStep)

            VStack(spacing: 12) {
                Text("All Set!")
                    .font(.system(size: 38, weight: .bold))

                Text("Your microphone is ready to use. Start a new recording to try it out.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }

            Spacer()

            Button("Start Recording") { onDone() }
                .buttonStyle(GlassCapsuleButtonStyle(tintColor: .green))

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Background / chrome (mirrors OnboardingView)

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.15),
                    Color(red: 0.1, green: 0.15, blue: 0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(RadialGradient(colors: [Color.blue.opacity(0.15), Color.clear], center: .topLeading, startRadius: 0, endRadius: 300))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150, y: -100)

            Circle()
                .fill(RadialGradient(colors: [Color.cyan.opacity(0.12), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 250))
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .offset(x: 150, y: 100)
        }
    }

    private var glassCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear, Color.black.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}
