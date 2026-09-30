import AVFoundation
import CoreMedia
import ScreenCaptureKit

enum RecorderError: LocalizedError {
    case noDisplay
    case noFrames
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available to record."
        case .noFrames: "No video frames were captured."
        case .writeFailed: "The recording could not be saved."
        }
    }
}

/// Records one display (ScreenCaptureKit) plus the default microphone (AVCaptureSession)
/// into a single QuickTime movie. All writer access happens on `queue`.
final class ScreenRecorder: NSObject, @unchecked Sendable {
    private static let frameRate: Int32 = 30
    private static let maxDimension = 3840

    var onUnexpectedStop: ((Error) -> Void)?

    private let display: SCDisplay
    private let outputURL: URL
    private let captureMicrophone: Bool
    private let queue = DispatchQueue(label: "ScreenRecord.writer")

    private var stream: SCStream?
    private var micSession: AVCaptureSession?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var sessionStartTime: CMTime?
    private var micMuted: Bool

    init(display: SCDisplay, outputURL: URL, captureMicrophone: Bool, micMuted: Bool) {
        self.display = display
        self.outputURL = outputURL
        self.captureMicrophone = captureMicrophone
        self.micMuted = micMuted
    }

    func setMicMuted(_ muted: Bool) {
        queue.async { self.micMuted = muted }
    }

    func start() async throws {
        let (width, height) = Self.outputSize(for: display)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 3, 4_000_000),
                AVVideoExpectedSourceFrameRateKey: Self.frameRate,
                AVVideoMaxKeyFrameIntervalKey: Self.frameRate * 2,
            ] as [String: Any],
        ])
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)

        var micSession: AVCaptureSession?
        var audioInput: AVAssetWriterInput?
        if captureMicrophone, let session = makeMicrophoneSession() {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
            ])
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                audioInput = input
                micSession = session
            }
        }

        guard writer.startWriting() else {
            throw writer.error ?? RecorderError.writeFailed
        }

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: Self.frameRate)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 6

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)

        queue.sync {
            self.writer = writer
            self.videoInput = videoInput
            self.audioInput = audioInput
        }
        self.stream = stream
        self.micSession = micSession

        micSession?.startRunning()
        do {
            try await stream.startCapture()
        } catch {
            micSession?.stopRunning()
            writer.cancelWriting()
            throw error
        }
    }

    func stop() async throws -> URL {
        if let stream {
            try? await stream.stopCapture()
        }
        micSession?.stopRunning()
        stream = nil
        micSession = nil

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let writer = self.writer else {
                    continuation.resume(throwing: RecorderError.writeFailed)
                    return
                }
                self.writer = nil
                guard self.sessionStartTime != nil else {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: self.outputURL)
                    continuation.resume(throwing: RecorderError.noFrames)
                    return
                }
                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                writer.endSession(atSourceTime: CMClockGetTime(CMClockGetHostTimeClock()))
                writer.finishWriting {
                    if writer.status == .completed {
                        continuation.resume(returning: self.outputURL)
                    } else {
                        continuation.resume(throwing: writer.error ?? RecorderError.writeFailed)
                    }
                }
            }
        }
    }

    private func makeMicrophoneSession() -> AVCaptureSession? {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return nil }

        let session = AVCaptureSession()
        let output = AVCaptureAudioDataOutput()
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        output.setSampleBufferDelegate(self, queue: queue)

        guard session.canAddInput(input), session.canAddOutput(output) else { return nil }
        session.addInput(input)
        session.addOutput(output)
        return session
    }

    private static func outputSize(for display: SCDisplay) -> (Int, Int) {
        var scale: Double = 2
        if let mode = CGDisplayCopyDisplayMode(display.displayID), mode.width > 0 {
            scale = Double(mode.pixelWidth) / Double(mode.width)
        }
        var width = Double(display.width) * scale
        var height = Double(display.height) * scale
        let longest = max(width, height)
        if longest > Double(maxDimension) {
            let factor = Double(maxDimension) / longest
            width *= factor
            height *= factor
        }
        return (Int(width) & ~1, Int(height) & ~1)
    }

    private static func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus)
        else { return false }
        return status == .complete
    }
}

extension ScreenRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              Self.isCompleteFrame(sampleBuffer),
              let writer, writer.status == .writing,
              let videoInput
        else { return }

        if sessionStartTime == nil {
            let start = sampleBuffer.presentationTimeStamp
            writer.startSession(atSourceTime: start)
            sessionStartTime = start
        }
        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }
}

extension ScreenRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !micMuted,
              let start = sessionStartTime,
              sampleBuffer.presentationTimeStamp >= start,
              let writer, writer.status == .writing,
              let audioInput, audioInput.isReadyForMoreMediaData
        else { return }
        audioInput.append(sampleBuffer)
    }
}

extension ScreenRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onUnexpectedStop?(error)
    }
}
