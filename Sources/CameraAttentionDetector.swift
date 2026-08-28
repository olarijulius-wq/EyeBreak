import AVFoundation
import Vision

final class CameraAttentionDetector: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    private static let sampleInterval: TimeInterval = 0.25
    private static let staleResultInterval: TimeInterval = 0.75
    private static let facingThreshold = 0.25

    static func requestPermissionIfNeeded(
        completion: @escaping (Bool) -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private let captureQueue = DispatchQueue(
        label: "com.eyebreak.camera-attention",
        qos: .userInitiated
    )
    private let captureQueueKey = DispatchSpecificKey<Void>()
    private let onFacingScreenChanged: (Bool) -> Void

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var staleResultTimer: DispatchSourceTimer?
    private var lastSampleUptime: TimeInterval?
    private var lastReportedFacingScreen: Bool?

    init(onFacingScreenChanged: @escaping (Bool) -> Void) {
        self.onFacingScreenChanged = onFacingScreenChanged
        super.init()
        captureQueue.setSpecific(key: captureQueueKey, value: ())
    }

    deinit {
        stop()
    }

    func start() {
        captureQueue.async { [weak self] in
            self?.startOnCaptureQueue()
        }
    }

    func stop() {
        if DispatchQueue.getSpecific(key: captureQueueKey) != nil {
            stopOnCaptureQueue()
        } else {
            captureQueue.sync { [self] in
                stopOnCaptureQueue()
            }
        }
    }

    private func startOnCaptureQueue() {
        guard captureSession == nil else {
            return
        }

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            reportFacingScreen(false)
            return
        }

        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .unspecified
            ),
            let cameraInput = try? AVCaptureDeviceInput(device: camera)
        else {
            reportFacingScreen(false)
            return
        }

        let session = AVCaptureSession()
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true

        session.beginConfiguration()

        guard session.canAddInput(cameraInput) else {
            session.commitConfiguration()
            reportFacingScreen(false)
            return
        }
        session.addInput(cameraInput)

        let presets: [AVCaptureSession.Preset] = [
            .low,
            .cif352x288,
            .vga640x480,
            .medium,
            .high
        ]
        guard
            let preset = presets.first(where: { session.canSetSessionPreset($0) })
        else {
            session.commitConfiguration()
            reportFacingScreen(false)
            return
        }
        session.sessionPreset = preset

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            reportFacingScreen(false)
            return
        }
        session.addOutput(output)
        if
            let connection = output.connection(with: .video),
            connection.isVideoMinFrameDurationSupported
        {
            connection.videoMinFrameDuration = CMTime(value: 1, timescale: 4)
        }
        output.setSampleBufferDelegate(self, queue: captureQueue)
        session.commitConfiguration()

        captureSession = session
        videoOutput = output
        lastSampleUptime = nil
        reportFacingScreen(false)

        session.startRunning()
        if !session.isRunning {
            stopOnCaptureQueue()
        } else {
            startStaleResultTimer()
        }
    }

    private func stopOnCaptureQueue() {
        staleResultTimer?.cancel()
        staleResultTimer = nil
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)

        if let captureSession {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }

            captureSession.beginConfiguration()
            captureSession.outputs.forEach { captureSession.removeOutput($0) }
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.commitConfiguration()
        }

        captureSession = nil
        videoOutput = nil
        lastSampleUptime = nil
        reportFacingScreen(false)
    }

    private func startStaleResultTimer() {
        staleResultTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(
            deadline: .now() + Self.staleResultInterval,
            repeating: Self.sampleInterval
        )
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            guard
                self.captureSession?.isRunning == true,
                let lastSampleUptime = self.lastSampleUptime,
                ProcessInfo.processInfo.systemUptime - lastSampleUptime
                    <= Self.staleResultInterval
            else {
                self.reportFacingScreen(false)
                return
            }
        }
        staleResultTimer = timer
        timer.resume()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let videoOutput,
            output === videoOutput,
            captureSession?.isRunning == true
        else {
            return
        }

        let sampleUptime = ProcessInfo.processInfo.systemUptime
        if
            let lastSampleUptime,
            sampleUptime - lastSampleUptime < Self.sampleInterval
        {
            return
        }
        lastSampleUptime = sampleUptime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            reportFacingScreen(false)
            return
        }

        let request = VNDetectFaceLandmarksRequest()
        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            options: [:]
        )

        do {
            try requestHandler.perform([request])
            let isFacingScreen = (request.results ?? []).contains { face in
                guard
                    let yaw = face.yaw?.doubleValue,
                    let pitch = face.pitch?.doubleValue
                else {
                    return false
                }

                return abs(yaw) < Self.facingThreshold
                    && abs(pitch) < Self.facingThreshold
            }
            reportFacingScreen(isFacingScreen)
        } catch {
            reportFacingScreen(false)
        }
    }

    private func reportFacingScreen(_ isFacingScreen: Bool) {
        guard lastReportedFacingScreen != isFacingScreen else {
            return
        }

        lastReportedFacingScreen = isFacingScreen
        DispatchQueue.main.async { [onFacingScreenChanged] in
            onFacingScreenChanged(isFacingScreen)
        }
    }
}
