import ReplayKit
import AVFoundation
import Flutter

/// Phase 1 iOS: wraps RPScreenRecorder + AVAssetWriter to capture screen to a file.
/// ReplayKit's `startCapture(handler:)` delivers CMSampleBuffer frames;
/// AVAssetWriter writes them to disk as H.264/AAC MP4.
class ReplayKitHandler: NSObject, RPScreenRecorderDelegate {

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false

    func startRecording(outputPath: String, result: @escaping FlutterResult) {
        outputURL = URL(fileURLWithPath: outputPath)

        // Remove existing file if any
        if let url = outputURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        let recorder = RPScreenRecorder.shared()
        recorder.delegate = self
        recorder.isMicrophoneEnabled = true

        recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            if let error = error {
                print("ReplayKit capture error: \(error)")
                return
            }
            self?.process(sampleBuffer: sampleBuffer, type: bufferType)
        }) { error in
            if let error = error {
                result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(nil)
            }
        }
    }

    func stopRecording(result: @escaping FlutterResult) {
        RPScreenRecorder.shared().stopCapture { [weak self] error in
            if let error = error {
                result(FlutterError(code: "STOP_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            self?.finalizeOutput { path in
                result(path)
            }
        }
    }

    private func process(sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Lazy-init AVAssetWriter on first video frame
        if assetWriter == nil, type == .video,
           let url = outputURL,
           let desc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            setupWriter(url: url, videoDesc: desc)
        }

        guard let writer = assetWriter, writer.status == .writing else { return }

        // Mark session start time on first appended buffer
        if !sessionStarted {
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            sessionStarted = true
        }

        switch type {
        case .video:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audioMic:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        default:
            break
        }
    }

    private func setupWriter(url: URL, videoDesc: CMFormatDescription) {
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }

        let videoDimensions = CMVideoFormatDescriptionGetDimensions(videoDesc)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoDimensions.width,
            AVVideoHeightKey: videoDimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true

        if writer.canAdd(vInput) { writer.add(vInput) }
        if writer.canAdd(aInput) { writer.add(aInput) }

        writer.startWriting()
        assetWriter = writer
        videoInput = vInput
        audioInput = aInput
    }

    private func finalizeOutput(completion: @escaping (String?) -> Void) {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            let path = self?.outputURL?.path
            self?.resetState()
            completion(path)
        }
    }

    private func resetState() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        outputURL = nil
        sessionStarted = false
    }

    // MARK: - RPScreenRecorderDelegate

    func screenRecorder(_ screenRecorder: RPScreenRecorder,
                        didStopRecordingWith previewViewController: RPPreviewViewController?,
                        error: Error?) {
        if let error = error {
            print("Recording stopped with error: \(error)")
        }
    }
}
