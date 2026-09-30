import AppKit
import AVFoundation
import ScreenCaptureKit

@MainActor
final class RecorderController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case recording
        case finishing
    }

    static let recordingsFolder = FileManager.default
        .urls(for: .moviesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Recordly", isDirectory: true)

    private static let countdownSeconds = 3

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var statusMessage: String?
    @Published private(set) var needsScreenPermission = false
    @Published private(set) var lastRecordingURL: URL?
    @Published var cameraEnabled = true {
        didSet { syncCamera() }
    }
    @Published var micEnabled = true {
        didSet { recorder?.setMicMuted(!micEnabled) }
    }

    private let camera = CameraOverlayController()
    private var recorder: ScreenRecorder?
    private var startTask: Task<Void, Never>?
    private var clock: Timer?
    private var recordingStartDate: Date?

    func toggleRecording() {
        switch phase {
        case .idle:
            startTask = Task { await start() }
        case .countdown:
            startTask?.cancel()
            startTask = nil
            phase = .idle
            syncCamera()
        case .recording:
            Task { await stop() }
        case .finishing:
            break
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func revealLastRecording() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
    }

    func openRecordingsFolder() {
        try? FileManager.default.createDirectory(at: Self.recordingsFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.recordingsFolder)
    }

    private func start() async {
        statusMessage = nil
        guard Permissions.ensureScreenRecordingAccess() else {
            needsScreenPermission = true
            statusMessage = "Allow Recordly in Privacy & Security › Screen Recording, then relaunch."
            return
        }
        needsScreenPermission = false

        let micAllowed = micEnabled
            ? await Permissions.requestAccess(for: .audio)
            : Permissions.isAuthorized(for: .audio)
        if micEnabled && !micAllowed {
            statusMessage = "Microphone access denied. Recording without audio."
        }
        let displayID = Self.displayUnderMouse()

        phase = .countdown(Self.countdownSeconds)
        syncCamera()
        for remaining in stride(from: Self.countdownSeconds, through: 1, by: -1) {
            phase = .countdown(remaining)
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first
            else { throw RecorderError.noDisplay }

            let recorder = ScreenRecorder(
                display: display,
                outputURL: try Self.makeOutputURL(),
                captureMicrophone: micAllowed,
                micMuted: !micEnabled
            )
            recorder.onUnexpectedStop = { [weak self] error in
                Task { @MainActor in self?.handleUnexpectedStop(error) }
            }
            try await recorder.start()
            if Task.isCancelled {
                _ = try? await recorder.stop()
                return
            }
            self.recorder = recorder
            phase = .recording
            startClock()
        } catch {
            phase = .idle
            syncCamera()
            statusMessage = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    private func stop() async {
        guard let recorder else { return }
        phase = .finishing
        stopClock()
        do {
            let url = try await recorder.stop()
            lastRecordingURL = url
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            statusMessage = "Recording failed: \(error.localizedDescription)"
        }
        self.recorder = nil
        phase = .idle
        syncCamera()
    }

    private func handleUnexpectedStop(_ error: Error) {
        guard phase == .recording else { return }
        Task {
            await stop()
            statusMessage = "Recording stopped: \(error.localizedDescription)"
        }
    }

    private func syncCamera() {
        let shouldShow: Bool
        switch phase {
        case .countdown, .recording: shouldShow = cameraEnabled
        case .idle, .finishing: shouldShow = false
        }
        Task {
            let shown = await camera.setVisible(shouldShow)
            if shouldShow && !shown {
                statusMessage = "Camera unavailable. Check Privacy & Security › Camera."
            }
        }
    }

    private func startClock() {
        recordingStartDate = Date()
        elapsed = 0
        clock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStartDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopClock() {
        clock?.invalidate()
        clock = nil
        recordingStartDate = nil
    }

    private static func displayUnderMouse() -> CGDirectDisplayID {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.uint32Value ?? CGMainDisplayID()
    }

    private static func makeOutputURL() throws -> URL {
        try FileManager.default.createDirectory(at: recordingsFolder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return recordingsFolder.appendingPathComponent("Recording \(formatter.string(from: Date())).mov")
    }
}
