import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import os
import ScreenCaptureKit

/// 屏幕录制引擎：`SCStream` 连续采帧 → `AVAssetWriter` 编码为 `.mp4`。
///
/// 设计要点（生产级稳健性）：
/// - 所有 `AVAssetWriter` 写入与 `startSession` 都发生在单一串行 `writerQueue` 上，避免竞态。
/// - `startSession(atSourceTime:)` 只在首个样本（视频或音频）时调用一次。
/// - writer 满载（`isReadyForMoreMediaData == false`）时直接丢帧，绝不阻塞流回调。
/// - 视频宽高强制取偶数（H.264 要求）。
/// - `stream(_:didStopWithError:)` 兜底：标记失败并通知外部，防止悬挂会话。
///
/// 参考 DeskPad 的 `SCStream` 逐帧 `CMSampleBuffer` 处理方式（不采用其虚拟显示器）。
final class ScreenCaptureRecorder: NSObject, @unchecked Sendable {

    private static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.screen-recorder.engine")

    /// 停止后返回的摘要。
    struct Output: Sendable {
        let url: URL
        let width: Int
        let height: Int
    }

    /// 流意外停止时回调（如权限被收回、显示配置变化）。
    var onError: (@Sendable (Error) -> Void)?

    /// 串行队列：承载所有样本处理与 writer 操作，避免数据竞争。
    private let writerQueue = DispatchQueue(label: "com.coffic.lumi.screen-recorder.writer")
    private let stateLock = NSLock()

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var isCapturing = false
    private var sessionStarted = false
    private var streamError: Error?
    private(set) var outputWidth = 0
    private(set) var outputHeight = 0
    private var tempURL: URL?

    // MARK: - Start

    /// 配置并启动采集与编码。
    ///
    /// 标记为 `@MainActor`：调用方（会话管理器）在主线程解析出 `SCContentFilter`
    /// （非 Sendable），主线程内传递避免跨隔离边界的数据竞争；内部 `startCapture()`
    /// 仍以 `await` 挂起，不阻塞主线程。
    ///
    /// - Parameters:
    ///   - filter: 由会话管理器解析好的内容过滤器（窗口或显示器）。
    ///   - config: 录制配置。
    ///   - tempOutputURL: 临时文件路径（由会话管理器通过 `RecordingFileWriter` 解析）。
    @MainActor
    func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {
        try Task.checkCancellation()

        let contentSize = CGSize(
            width: filter.contentRect.width * CGFloat(filter.pointPixelScale),
            height: filter.contentRect.height * CGFloat(filter.pointPixelScale)
        )
        let (width, height) = Self.computeOutputSize(contentSize: contentSize, resolutionHeight: config.resolutionHeight)
        outputWidth = width
        outputHeight = height
        self.tempURL = tempOutputURL

        // 1) 配置 SCStream。
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = width
        streamConfig.height = height
        streamConfig.showsCursor = config.showCursor
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.frameRate))
        streamConfig.queueDepth = 6
        var captureMicrophone = false
        if config.includeMicrophone {
            if #available(macOS 15.0, *) {
                streamConfig.captureMicrophone = true
                captureMicrophone = true
            }
            // macOS 14 不支持 SCStream 麦克风采集，静默降级（仅画面 / app 声音）。
        }

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try await stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writerQueue)
        if config.includeAppAudio {
            try await stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writerQueue)
        }
        if captureMicrophone {
            if #available(macOS 15.0, *) {
                try await stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: writerQueue)
            }
        }
        self.stream = stream

        // 2) 配置 AVAssetWriter 与输入（此时采集尚未开始，无并发写入）。
        try setupWriter(tempOutputURL: tempOutputURL, width: width, height: height, audioEnabled: config.includeAppAudio || config.includeMicrophone)

        // 3) 启动。
        guard let writer else { throw RecordingError.encodingFailed("AVAssetWriter unavailable") }
        guard writer.startWriting() else {
            throw writer.error ?? RecordingError.encodingFailed("startWriting failed")
        }
        try await stream.startCapture()
        stateLock.withLock { isCapturing = true }
    }

    /// 在 writerQueue 上初始化 writer 与输入。
    private func setupWriter(tempOutputURL: URL, width: Int, height: Int, audioEnabled: Bool) throws {
        do {
            let writer = try AVAssetWriter(outputURL: tempOutputURL, fileType: .mp4)

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: Self.videoSettings(width: width, height: height))
            videoInput.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            )
            guard writer.canAdd(videoInput) else { throw RecordingError.encodingFailed("cannot add video input") }
            writer.add(videoInput)

            var audioInput: AVAssetWriterInput?
            if audioEnabled {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.audioSettings)
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else { throw RecordingError.encodingFailed("cannot add audio input") }
                writer.add(input)
                audioInput = input
            }

            self.writer = writer
            self.videoInput = videoInput
            self.pixelAdaptor = adaptor
            self.audioInput = audioInput
        } catch {
            throw error
        }
    }

    // MARK: - Stop

    /// 停止采集并完成编码，返回临时文件路径与尺寸。
    func stop() async throws -> Output {
        guard let tempURL else { throw RecordingError.notRecording }

        stateLock.withLock { isCapturing = false }
        try? await stream?.stopCapture()

        // stopCapture 完成后不会再有样本回调，可安全标记输入完成。
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        if let writer {
            // 若从未收到任何样本（未 startSession），finishWriting 会进入失败态。
            if !sessionStarted {
                RecordingFileWriter.removeTempFile(at: tempURL)
                throw RecordingError.encodingFailed("no frames captured")
            }
            await writer.finishWriting()
            if writer.status != .completed {
                throw writer.error ?? RecordingError.encodingFailed("finishWriting failed")
            }
        }

        // 优先抛出流层面的错误（如中途停止）。
        if let streamError { throw streamError }

        return Output(url: tempURL, width: outputWidth, height: outputHeight)
    }

    /// 立即释放底层资源（不保证编码完整），用于异常/取消回滚。
    func cancel() async {
        stateLock.withLock { isCapturing = false }
        try? await stream?.stopCapture()
        if let tempURL { RecordingFileWriter.removeTempFile(at: tempURL) }
        teardown()
    }

    private func teardown() {
        stream = nil
        writer = nil
        videoInput = nil
        pixelAdaptor = nil
        audioInput = nil
    }

    // MARK: - Output size

    private static func computeOutputSize(contentSize: CGSize, resolutionHeight: Int?) -> (width: Int, height: Int) {
        var height = max(1, Int(contentSize.height.rounded()))
        var width = max(1, Int(contentSize.width.rounded()))
        if let target = resolutionHeight, target > 0, height > 0 {
            let scale = CGFloat(target) / CGFloat(height)
            height = target
            width = max(1, Int((CGFloat(width) * scale).rounded()))
        }
        // H.264 要求偶数。
        width = width & ~1
        height = height & ~1
        return (width, height)
    }

    // MARK: - Codec settings

    private static func videoSettings(width: Int, height: Int) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String: Any],
        ]
    }

    private static var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
        ]
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureRecorder: SCStreamOutput {

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        guard stateLock.withLock({ isCapturing }) else { return }

        // 首个样本驱动会话开始（仅一次）。
        if !sessionStarted {
            sessionStarted = true
            writer?.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            Self.logger.info("first sample received, session started (\(type.rawValue, privacy: .public))")
        }

        switch type {
        case .screen:
            appendVideo(sampleBuffer)
        case .audio:
            appendAudio(sampleBuffer)
        default:
            // `.microphone`（macOS 15+）及未来音频类输出统一走音频处理。
            appendAudio(sampleBuffer)
        }
    }

    private func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let videoInput, videoInput.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let pixelAdaptor
        else { return }
        pixelAdaptor.append(pixelBuffer, withPresentationTime: sampleBuffer.presentationTimeStamp)
    }

    private func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureRecorder: SCStreamDelegate {

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        stateLock.withLock {
            streamError = error
            isCapturing = false
        }
        Self.logger.error("stream stopped with error: \(error.localizedDescription, privacy: .public)")
        onError?(error)
    }
}
