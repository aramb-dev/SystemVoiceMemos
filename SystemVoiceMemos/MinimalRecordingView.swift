import SwiftUI
import AppKit

struct MinimalRecordingView: View {
    @ObservedObject var recorder: SystemAudioRecorder
    @Binding var isAlwaysOnTop: Bool
    
    var onStop: () -> Void
    var onRestart: () -> Void
    
    private var formattedDuration: String {
        let total = Int(recorder.currentRecordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            recordingIndicator
            
            Text(formattedDuration)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60)
            
            Divider()
                .frame(height: 24)
            
            controlButtons
            
            Divider()
                .frame(height: 24)
            
            pinButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
    
    private var recordingIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .fill(indicatorColor.opacity(0.4))
                    .frame(width: 18, height: 18)
                    .opacity(recorder.recordingState == .recording ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.recordingState)
            )
    }
    
    private var indicatorColor: Color {
        switch recorder.recordingState {
        case .idle: return .gray
        case .recording: return .red
        case .paused: return .orange
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Pause/Resume button
            Button {
                Task {
                    if recorder.isPaused {
                        await recorder.resumeRecording()
                    } else {
                        await recorder.pauseRecording()
                    }
                }
            } label: {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help(recorder.isPaused ? "Resume" : "Pause")
            
            // Stop button
            Button {
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .help("Stop Recording")
            
            // Restart button
            Button {
                onRestart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Restart Recording")
        }
    }
    
    private var pinButton: some View {
        Button {
            isAlwaysOnTop.toggle()
        } label: {
            Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isAlwaysOnTop ? .accentColor : .secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(isAlwaysOnTop ? "Unpin from top" : "Keep on top")
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
