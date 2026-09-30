import AppKit
@preconcurrency import AVFoundation

/// Floating, draggable circular camera bubble. It is a regular on-screen window,
/// so the screen capture picks it up.
@MainActor
final class CameraOverlayController {
    private static let diameter: CGFloat = 220
    private static let margin: CGFloat = 32

    private var panel: NSPanel?
    private var session: AVCaptureSession?
    private var wantsVisible = false
    private var lastOrigin: CGPoint?
    private let sessionQueue = DispatchQueue(label: "ScreenRecord.camera")

    /// Returns false if the camera could not be shown (no permission or no device).
    @discardableResult
    func setVisible(_ visible: Bool) async -> Bool {
        wantsVisible = visible
        guard visible else {
            hide()
            return true
        }
        if panel != nil { return true }

        guard await Permissions.requestAccess(for: .video) else { return false }
        guard wantsVisible, panel == nil else { return true }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return false }

        let session = AVCaptureSession()
        guard session.canAddInput(input) else { return false }
        session.addInput(input)

        let panel = makePanel(session: session)
        panel.orderFrontRegardless()
        self.panel = panel
        self.session = session
        sessionQueue.async { session.startRunning() }
        return true
    }

    private func hide() {
        if let panel {
            lastOrigin = panel.frame.origin
            panel.orderOut(nil)
        }
        panel = nil
        if let session {
            sessionQueue.async { session.stopRunning() }
        }
        session = nil
    }

    private func makePanel(session: AVCaptureSession) -> NSPanel {
        let size = NSSize(width: Self.diameter, height: Self.diameter)
        let origin = lastOrigin ?? defaultOrigin()
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = CameraBubbleView(frame: NSRect(origin: .zero, size: size), session: session)
        return panel
    }

    private func defaultOrigin() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return CGPoint(x: visible.minX + Self.margin, y: visible.minY + Self.margin)
    }
}

private final class CameraBubbleView: NSView {
    init(frame: NSRect, session: AVCaptureSession) {
        super.init(frame: frame)
        wantsLayer = true

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        preview.cornerRadius = frame.width / 2
        preview.masksToBounds = true
        preview.borderWidth = 4
        preview.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        layer?.addSublayer(preview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var mouseDownCanMoveWindow: Bool { true }
}
