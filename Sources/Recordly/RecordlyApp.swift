import SwiftUI

@main
struct RecordlyApp: App {
    @StateObject private var recorder = RecorderController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(recorder: recorder)
        } label: {
            MenuBarLabel(recorder: recorder)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var recorder: RecorderController

    var body: some View {
        switch recorder.phase {
        case .idle:
            HStack(spacing: 4) {
                Image(systemName: "record.circle")
                Text("Recordly")
            }
        case .countdown(let seconds):
            Text("\(Image(systemName: "timer")) \(seconds)")
        case .recording:
            Text("\(Image(systemName: "record.circle.fill")) \(formatDuration(recorder.elapsed))")
        case .finishing:
            Image(systemName: "hourglass")
        }
    }
}

struct MenuContent: View {
    @ObservedObject var recorder: RecorderController

    var body: some View {
        Button(primaryTitle) { recorder.toggleRecording() }
            .keyboardShortcut("r")
            .disabled(recorder.phase == .finishing)

        Divider()

        Toggle("Camera", isOn: $recorder.cameraEnabled)
        Toggle("Microphone", isOn: $recorder.micEnabled)

        if let message = recorder.statusMessage {
            Divider()
            Text(message)
        }
        if recorder.needsScreenPermission {
            Button("Open Screen Recording Settings…") { recorder.openScreenRecordingSettings() }
        }

        Divider()

        Button("Show Last Recording") { recorder.revealLastRecording() }
            .disabled(recorder.lastRecordingURL == nil)
        Button("Open Recordings Folder") { recorder.openRecordingsFolder() }

        Divider()

        Button("Quit Recordly") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var primaryTitle: String {
        switch recorder.phase {
        case .idle: "Start Recording"
        case .countdown(let seconds): "Cancel (starting in \(seconds)…)"
        case .recording: "Stop Recording (\(formatDuration(recorder.elapsed)))"
        case .finishing: "Saving…"
        }
    }
}

func formatDuration(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
        : String(format: "%02d:%02d", minutes, seconds)
}
