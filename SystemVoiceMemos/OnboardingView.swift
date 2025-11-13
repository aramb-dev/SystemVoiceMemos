//
//  OnboardingView.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 11/13/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Welcome to SystemVoiceMemos",
            description: "Record your Mac's system audio with ease. Capture music, calls, streaming audio, and more—all in high quality.",
            accentColor: .blue
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Screen Recording Permission Required",
            description: "To capture system audio, macOS requires Screen Recording permission. Don't worry—we only record audio, never video.\n\nYou'll be prompted when you start your first recording.",
            accentColor: .orange,
            isPermissionPage: true
        ),
        OnboardingPage(
            icon: "play.circle.fill",
            title: "Simple & Powerful",
            description: "• Click the red button to start recording\n• Organize with folders and favorites\n• Visualize with beautiful waveforms\n• Control playback with media keys\n• All recordings stored locally & private",
            accentColor: .green
        )
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(maxWidth: 600, maxHeight: 500)

                // Bottom actions
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(32)
                .frame(maxWidth: 600)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 30)
            )
            .padding(40)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(page.accentColor)
                .symbolEffect(.bounce, value: page.icon)

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            // Permission hint
            if page.isPermissionPage {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to enable manually:")
                                .font(.headline)
                            Text("System Settings → Privacy & Security → Screen Recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.vertical, 40)
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    var isPermissionPage: Bool = false
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .frame(width: 800, height: 600)
}
