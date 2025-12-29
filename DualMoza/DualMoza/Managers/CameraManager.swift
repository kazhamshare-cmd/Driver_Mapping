import AVFoundation
import UIKit
import Vision
import CoreImage

class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var frontCameraImage: UIImage?
    @Published var backCameraImage: UIImage?
    @Published var isMultiCamSupported: Bool = false
    @Published var isRunning: Bool = false
    @Published var error: String?

    // MARK: - Session
    private var multiCamSession: AVCaptureMultiCamSession?
    private var singleSession: AVCaptureSession?

    // MARK: - Devices
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?

    // MARK: - Inputs
    private var frontInput: AVCaptureDeviceInput?
    private var backInput: AVCaptureDeviceInput?

    // MARK: - Outputs
    private var frontOutput: AVCaptureVideoDataOutput?
    private var backOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?

    // MARK: - Audio
    private var audioDevice: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?

    // MARK: - Recording
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording: Bool = false
    private var recordingStartTime: CMTime?
    private var recordingURL: URL?

    // MARK: - Processing Queues
    private let videoQueue = DispatchQueue(label: "com.dualmoza.videoQueue", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "com.dualmoza.processingQueue", qos: .userInteractive)
    private let faceDetectionQueue = DispatchQueue(label: "com.dualmoza.faceDetection", qos: .utility)  // 顔検出は別キューで

    // MARK: - Face Detection
    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest?
    // フロントとバックで別々に顔検出結果を保持
    private var detectedFacesFront: [VNFaceObservation] = []
    private var detectedFacesBack: [VNFaceObservation] = []

    // MARK: - Person Detection (iOS 17+)
    private var humanRectanglesRequest: Any?  // VNDetectHumanRectanglesRequest (iOS 17+)
    private var detectedBodiesFront: [CGRect] = []
    private var detectedBodiesBack: [CGRect] = []

    // MARK: - Reusable Filters (avoid creating new instances every frame)
    private lazy var pixellateFilter: CIFilter? = CIFilter(name: "CIPixellate")
    private lazy var gaussianBlurFilter: CIFilter? = CIFilter(name: "CIGaussianBlur")
    private lazy var radialGradientFilter: CIFilter? = CIFilter(name: "CIRadialGradient")
    private lazy var blendWithMaskFilter: CIFilter? = CIFilter(name: "CIBlendWithMask")

    // MARK: - Watermark (cached for performance)
    private var cachedWatermarkImage: CIImage?
    private var cachedWatermarkSize: CGSize = .zero
    private var isProUser: Bool = false  // 録画開始時にキャッシュ

    // MARK: - Pixel Buffer Pool for Recording
    private var pixelBufferPool: CVPixelBufferPool?

    // MARK: - Settings
    var frontMosaicEnabled: Bool = false
    var backMosaicEnabled: Bool = false
    var frontPrivacyFilterType: PrivacyFilterType = .mosaic
    var backPrivacyFilterType: PrivacyFilterType = .mosaic
    var frontDetectionMode: DetectionMode = .faceOnly
    var backDetectionMode: DetectionMode = .faceOnly
    var frontMosaicIntensity: CGFloat = 20.0
    var backMosaicIntensity: CGFloat = 20.0
    var frontMosaicCoverage: CGFloat = 0.5  // 0=目だけ、0.5=標準、1.0=おでこ〜顎髭
    var backMosaicCoverage: CGFloat = 0.5
    var frontZoom: CGFloat = 1.0
    var backZoom: CGFloat = 1.0
    var frontEV: Float = 0.0
    var backEV: Float = 0.0

    // MARK: - Recording Settings (PiP)
    var recordingMainIsBack: Bool = true
    var recordingPiPEnabled: Bool = true
    var recordingPiPShape: PiPShape = .rectangle
    var recordingPiPPosition: CGPoint = CGPoint(x: 280, y: 500)
    var recordingPiPSize: CGFloat = 120
    var recordingScreenSize: CGSize = CGSize(width: 393, height: 852)

    // Store latest frames for compositing
    private var latestFrontCIImage: CIImage?
    private var latestBackCIImage: CIImage?
    private let frameLock = NSLock()

    // MARK: - CIContext for image processing
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false  // 中間結果をキャッシュしない（メモリ節約）
    ])

    // MARK: - Frame Rate Throttling
    private var lastPreviewTimeFront: CFAbsoluteTime = 0
    private var lastPreviewTimeBack: CFAbsoluteTime = 0
    private var lastFaceDetectionTime: CFAbsoluteTime = 0
    private var lastRecordingFrameTime: CFAbsoluteTime = 0
    private let previewFrameInterval: CFAbsoluteTime = 1.0 / 30.0  // 30fps for preview
    private let previewFrameIntervalRecording: CFAbsoluteTime = 1.0 / 15.0  // 録画中は15fpsに下げる
    private let faceDetectionInterval: CFAbsoluteTime = 1.0 / 10.0  // 10fps for face detection
    private let recordingFrameInterval: CFAbsoluteTime = 1.0 / 30.0  // 30fps for recording

    // MARK: - Memory Management
    private var isLowMemory: Bool = false

    // MARK: - Camera State
    @Published var cameraInterrupted: Bool = false
    @Published var interruptionReason: String = ""

    // MARK: - Device Orientation
    private var currentOrientation: UIDeviceOrientation = .portrait
    private var frontConnection: AVCaptureConnection?
    private var backConnection: AVCaptureConnection?

    // MARK: - Initialization
    override init() {
        super.init()

        // 現在のデバイスの向きを取得
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation.isValidInterfaceOrientation {
            currentOrientation = deviceOrientation
        } else {
            // アプリ起動時は向きがunknownの場合があるので、ステータスバーから取得
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                switch windowScene.interfaceOrientation {
                case .portrait:
                    currentOrientation = .portrait
                case .portraitUpsideDown:
                    currentOrientation = .portraitUpsideDown
                case .landscapeLeft:
                    currentOrientation = .landscapeRight  // インターフェースとデバイスの向きは逆
                case .landscapeRight:
                    currentOrientation = .landscapeLeft
                @unknown default:
                    currentOrientation = .portrait
                }
            }
        }
        print("Initial orientation: \(currentOrientation.rawValue)")

        setupFaceDetection()
        checkMultiCamSupport()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    // MARK: - Setup Notifications
    private func setupNotifications() {
        // カメラセッションが中断された時
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: nil
        )

        // カメラセッションが再開された時
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: nil
        )

        // ランタイムエラー
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: nil
        )

        // メモリ警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // アプリがバックグラウンドに移行する時
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // アプリがフォアグラウンドに復帰する時
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // デバイスの向き変更を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // 向きの変更を有効化
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    @objc private func deviceOrientationDidChange() {
        let newOrientation = UIDevice.current.orientation

        // 有効な向きのみ処理（faceUp, faceDownは無視）
        guard newOrientation.isValidInterfaceOrientation else { return }

        // 向きが変わった場合のみ更新
        guard newOrientation != currentOrientation else { return }

        currentOrientation = newOrientation
        print("Device orientation changed to: \(newOrientation.rawValue)")

        // カメラ接続の向きを更新
        updateCameraConnectionOrientation()
    }

    private func updateCameraConnectionOrientation() {
        let videoOrientation = currentVideoOrientation()

        videoQueue.async { [weak self] in
            if let frontConn = self?.frontConnection, frontConn.isVideoOrientationSupported {
                frontConn.videoOrientation = videoOrientation
            }
            if let backConn = self?.backConnection, backConn.isVideoOrientationSupported {
                backConn.videoOrientation = videoOrientation
            }
            print("Camera connections updated to orientation: \(videoOrientation.rawValue)")
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch currentOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight  // デバイスとビデオの向きは逆
        case .landscapeRight:
            return .landscapeLeft   // デバイスとビデオの向きは逆
        default:
            return .portrait
        }
    }

    @objc private func didReceiveMemoryWarning() {
        print("Memory warning received - clearing cached frames and buffers")

        // 低メモリフラグを設定（フレームレートを下げる）
        isLowMemory = true

        // Clear cached frames to free memory
        frameLock.lock()
        if !isRecording {
            latestFrontCIImage = nil
            latestBackCIImage = nil
        }
        frameLock.unlock()

        // Clear detected faces
        detectedFacesFront.removeAll()
        detectedFacesBack.removeAll()

        // Flush pixel buffer pool to release excess buffers
        if let pool = pixelBufferPool {
            CVPixelBufferPoolFlush(pool, .excessBuffers)
        }

        // 録画中にメモリ警告が来た場合、録画を停止してデータを保護
        if isRecording {
            print("Memory warning during recording - stopping to protect data")
            DispatchQueue.main.async { [weak self] in
                self?.error = "メモリ不足のため録画を停止しました"
            }
            stopRecording { _ in }
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.cameraInterrupted = true
            switch reason {
            case .videoDeviceNotAvailableInBackground:
                self?.interruptionReason = "アプリがバックグラウンドにあります"
            case .audioDeviceInUseByAnotherClient:
                self?.interruptionReason = "他のアプリがマイクを使用中です"
            case .videoDeviceInUseByAnotherClient:
                self?.interruptionReason = "他のアプリがカメラを使用中です"
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                self?.interruptionReason = "マルチタスク中はカメラを使用できません"
            case .videoDeviceNotAvailableDueToSystemPressure:
                self?.interruptionReason = "システム負荷によりカメラが停止しました"
            @unknown default:
                self?.interruptionReason = "カメラが中断されました"
            }
            self?.error = self?.interruptionReason
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.cameraInterrupted = false
            self?.interruptionReason = ""
            self?.error = nil
        }
        // セッションを再開
        startSession()
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

        DispatchQueue.main.async { [weak self] in
            self?.error = "カメラエラー: \(error.localizedDescription)"

            // メディアサービスがリセットされた場合は再起動を試みる
            if error.code == .mediaServicesWereReset {
                self?.setupSession()
                self?.startSession()
            }
        }
    }

    @objc private func appDidEnterBackground() {
        print("App entered background - stopping camera session to release resources")

        // 録画中は停止しない（ユーザーが意図的にバックグラウンドにした場合を除く）
        // ただし、通常のカメラアプリでは録画中にバックグラウンドに行くと録画が止まる
        if isRecording {
            // 録画を停止（バックグラウンドでは録画継続不可）
            stopRecording { _ in }
        }

        // カメラセッションを停止して他のアプリがカメラ/マイクを使えるようにする
        videoQueue.async { [weak self] in
            if let multiSession = self?.multiCamSession, multiSession.isRunning {
                multiSession.stopRunning()
            } else if let singleSession = self?.singleSession, singleSession.isRunning {
                singleSession.stopRunning()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
        }
    }

    @objc private func appWillEnterForeground() {
        print("App will enter foreground - restarting camera session")

        // 前回のキャッシュ画像をクリア
        DispatchQueue.main.async { [weak self] in
            self?.frontCameraImage = nil
            self?.backCameraImage = nil
        }
        latestFrontCIImage = nil
        latestBackCIImage = nil

        // カメラセッションを再開
        startSession()
    }

    // MARK: - Check Multi-Cam Support
    private func checkMultiCamSupport() {
        isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported
    }

    // MARK: - Setup Face Detection
    private func setupFaceDetection() {
        // Use FaceLandmarksRequest to detect eye positions
        // コールバックは使用せず、perform後に直接結果を取得する
        faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: nil)

        // Setup Human Rectangles Request for iOS 17+
        if #available(iOS 17.0, *) {
            let humanRequest = VNDetectHumanRectanglesRequest(completionHandler: nil)
            humanRequest.upperBodyOnly = true  // 上半身のみ検出（頭部含む）
            humanRectanglesRequest = humanRequest
        }
    }

    /// iOS 17以上で人物検出が利用可能かどうか
    var isPersonDetectionAvailable: Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }

    // MARK: - Configure Camera Format
    /// カメラの解像度を設定（目標解像度に最も近いフォーマットを選択）
    private func configureCameraFormat(device: AVCaptureDevice, targetWidth: Int32, targetHeight: Int32) {
        // マルチカメラ対応のフォーマットのみをフィルタ
        let formats = device.formats.filter { format in
            // マルチカメラ対応かチェック
            format.isMultiCamSupported
        }

        // 目標解像度に最も近いフォーマットを探す
        var bestFormat: AVCaptureDevice.Format?
        var bestDiff = Int32.max

        for format in formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)

            // 縦向きなので、widthとheightを比較
            let diff = abs(dimensions.width - targetWidth) + abs(dimensions.height - targetHeight)

            if diff < bestDiff {
                bestDiff = diff
                bestFormat = format
            }

            // 完全一致なら即採用
            if dimensions.width == targetWidth && dimensions.height == targetHeight {
                bestFormat = format
                break
            }
        }

        // フォーマットを適用
        if let format = bestFormat {
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                // フレームレートを30fpsに設定（安定性向上）
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                device.unlockForConfiguration()

                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("Camera \(device.position == .front ? "Front" : "Back") configured: \(dims.width)x\(dims.height)")
            } catch {
                print("Failed to configure camera format: \(error)")
            }
        }
    }

    // MARK: - Update Camera Quality Based on Main Camera
    /// メインカメラに基づいて解像度を動的に変更
    /// - Parameter mainIsBack: trueならバックカメラがメイン、falseならフロントカメラがメイン
    private var lastQualityUpdateTime: CFAbsoluteTime = 0
    func updateCameraQuality(mainIsBack: Bool) {
        guard isMultiCamSupported else { return }

        // 短時間での重複呼び出しを防止（500ms以内は無視）
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastQualityUpdateTime > 0.5 else {
            print("Quality update skipped (too frequent)")
            return
        }
        lastQualityUpdateTime = currentTime

        // プレビュー時は両方低画質（パフォーマンス優先）
        if let back = backCamera {
            configureCameraFormat(device: back, targetWidth: 640, targetHeight: 480)
        }
        if let front = frontCamera {
            configureCameraFormat(device: front, targetWidth: 640, targetHeight: 480)
        }
        print("Quality: Both cameras set to 640x480 for preview")
    }

    /// 録画用に高画質に切り替え
    func setRecordingQuality(mainIsBack: Bool) {
        guard isMultiCamSupported else { return }

        if mainIsBack {
            // バックカメラがメイン → バック高画質、フロント低画質
            if let back = backCamera {
                configureCameraFormat(device: back, targetWidth: 1280, targetHeight: 720)
            }
            if let front = frontCamera {
                configureCameraFormat(device: front, targetWidth: 640, targetHeight: 480)
            }
            print("Recording Quality: Back=720p (main), Front=480p (PiP)")
        } else {
            // フロントカメラがメイン → フロント高画質、バック低画質
            if let front = frontCamera {
                configureCameraFormat(device: front, targetWidth: 1280, targetHeight: 720)
            }
            if let back = backCamera {
                configureCameraFormat(device: back, targetWidth: 640, targetHeight: 480)
            }
            print("Recording Quality: Front=720p (main), Back=480p (PiP)")
        }
    }

    /// プレビュー用に低画質に戻す
    func setPreviewQuality() {
        guard isMultiCamSupported else { return }

        if let back = backCamera {
            configureCameraFormat(device: back, targetWidth: 640, targetHeight: 480)
        }
        if let front = frontCamera {
            configureCameraFormat(device: front, targetWidth: 640, targetHeight: 480)
        }
        print("Preview Quality: Both cameras set to 640x480")
    }

    // MARK: - Setup Session
    private var lastSetupTime: CFAbsoluteTime = 0
    private var isSettingUp: Bool = false
    func setupSession() {
        // 短時間での重複呼び出しを防止（2秒以内は無視）
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastSetupTime > 2.0, !isSettingUp else {
            print("Setup session skipped (too frequent or already setting up)")
            return
        }
        lastSetupTime = currentTime
        isSettingUp = true

        // 前回のキャッシュ画像をクリア
        DispatchQueue.main.async { [weak self] in
            self?.frontCameraImage = nil
            self?.backCameraImage = nil
        }
        latestFrontCIImage = nil
        latestBackCIImage = nil

        if isMultiCamSupported {
            setupMultiCamSession()
        } else {
            setupSingleCamSession()
        }

        isSettingUp = false
    }

    // MARK: - Setup Multi-Cam Session
    private func setupMultiCamSession() {
        multiCamSession = AVCaptureMultiCamSession()
        guard let session = multiCamSession else { return }

        session.beginConfiguration()

        // Front camera setup
        if let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = frontDevice
            do {
                let input = try AVCaptureDeviceInput(device: frontDevice)
                if session.canAddInput(input) {
                    session.addInputWithNoConnections(input)
                    frontInput = input
                }
            } catch {
                self.error = "フロントカメラの設定に失敗: \(error.localizedDescription)"
            }
        }

        // Back camera setup
        if let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = backDevice
            do {
                let input = try AVCaptureDeviceInput(device: backDevice)
                if session.canAddInput(input) {
                    session.addInputWithNoConnections(input)
                    backInput = input
                }
            } catch {
                self.error = "バックカメラの設定に失敗: \(error.localizedDescription)"
            }
        }

        // 初期設定: バックカメラがメイン（高画質）、フロントがPiP（低画質）
        updateCameraQuality(mainIsBack: true)

        // Front output
        let frontVideoOutput = AVCaptureVideoDataOutput()
        frontVideoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        frontVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(frontVideoOutput) {
            session.addOutputWithNoConnections(frontVideoOutput)
            frontOutput = frontVideoOutput
        }

        // Back output
        let backVideoOutput = AVCaptureVideoDataOutput()
        backVideoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        backVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(backVideoOutput) {
            session.addOutputWithNoConnections(backVideoOutput)
            backOutput = backVideoOutput
        }

        // Connect front camera
        if let frontInput = frontInput,
           let frontPort = frontInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .front).first {
            let connection = AVCaptureConnection(inputPorts: [frontPort], output: frontVideoOutput)
            connection.videoOrientation = currentVideoOrientation()
            connection.isVideoMirrored = true
            if session.canAddConnection(connection) {
                session.addConnection(connection)
                frontConnection = connection
            }
        }

        // Connect back camera
        if let backInput = backInput,
           let backPort = backInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .back).first {
            let connection = AVCaptureConnection(inputPorts: [backPort], output: backVideoOutput)
            connection.videoOrientation = currentVideoOrientation()
            if session.canAddConnection(connection) {
                session.addConnection(connection)
                backConnection = connection
            }
        }

        // Audio setup
        setupAudioCapture(for: session)

        session.commitConfiguration()
    }

    // MARK: - Setup Single Cam Session (Fallback)
    private func setupSingleCamSession() {
        singleSession = AVCaptureSession()
        guard let session = singleSession else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        // Default to back camera
        if let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = backDevice
            do {
                let input = try AVCaptureDeviceInput(device: backDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    backInput = input
                }
            } catch {
                self.error = "カメラの設定に失敗: \(error.localizedDescription)"
            }
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            backOutput = videoOutput
        }

        // Audio setup
        setupAudioCapture(for: session)

        session.commitConfiguration()
    }

    // MARK: - Setup Audio Capture
    private func setupAudioCapture(for session: AVCaptureSession) {
        // Configure audio session first
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        // Get audio device
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Audio device not available")
            return
        }
        self.audioDevice = audioDevice

        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                self.audioInput = audioInput
                print("Audio input added to session")
            }

            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                self.audioOutput = audioOutput
                print("Audio output added to session")
            }

            print("Audio capture setup complete")
        } catch {
            print("Failed to setup audio capture: \(error)")
        }
    }

    // MARK: - Start/Stop Session
    func startSession() {
        videoQueue.async { [weak self] in
            if let multiSession = self?.multiCamSession {
                multiSession.startRunning()
            } else if let singleSession = self?.singleSession {
                singleSession.startRunning()
            }
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    func stopSession() {
        videoQueue.async { [weak self] in
            if let multiSession = self?.multiCamSession {
                multiSession.stopRunning()
            } else if let singleSession = self?.singleSession {
                singleSession.stopRunning()
            }
            DispatchQueue.main.async {
                self?.isRunning = false
                // Clear images to free memory
                self?.frontCameraImage = nil
                self?.backCameraImage = nil
                self?.latestFrontCIImage = nil
                self?.latestBackCIImage = nil
            }
        }
    }

    // MARK: - Zoom Control
    func setZoom(_ zoom: CGFloat, for position: AVCaptureDevice.Position) {
        let device = position == .front ? frontCamera : backCamera
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            device.videoZoomFactor = min(max(zoom, 1.0), maxZoom)
            device.unlockForConfiguration()
        } catch {
            print("Zoom設定に失敗: \(error)")
        }
    }

    // MARK: - Exposure Control
    func setExposure(_ ev: Float, for position: AVCaptureDevice.Position) {
        let device = position == .front ? frontCamera : backCamera
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(ev, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            print("露出設定に失敗: \(error)")
        }
    }

    // MARK: - Apply Privacy Filter to Face
    private func applyPrivacyFilterToFaces(image: CIImage, faces: [VNFaceObservation], filterType: PrivacyFilterType, intensity: CGFloat, coverage: CGFloat) -> CIImage {
        var outputImage = image
        let imageSize = image.extent.size

        // 安全のため処理する顔の数を制限（最大3人に削減）
        let maxFaces = min(faces.count, 3)
        let facesToProcess = Array(faces.prefix(maxFaces))

        for face in facesToProcess {
            // 無効な顔データをスキップ
            guard face.boundingBox.width > 0.01, face.boundingBox.height > 0.01 else { continue }

            // VNFaceObservation の座標を画像座標に変換
            let faceRect = CGRect(
                x: face.boundingBox.origin.x * imageSize.width,
                y: face.boundingBox.origin.y * imageSize.height,
                width: face.boundingBox.width * imageSize.width,
                height: face.boundingBox.height * imageSize.height
            )

            // 顔が小さすぎる場合はスキップ（ノイズ対策）
            guard faceRect.width > 30, faceRect.height > 30 else { continue }

            // 目の位置を取得（ランドマークから）- 簡略化
            var eyesCenterY = faceRect.midY + faceRect.height * 0.15

            if let landmarks = face.landmarks,
               let leftEye = landmarks.leftEye,
               let rightEye = landmarks.rightEye {
                let leftPoints = leftEye.normalizedPoints
                let rightPoints = rightEye.normalizedPoints

                if !leftPoints.isEmpty && !rightPoints.isEmpty {
                    let leftY = leftPoints.map { (face.boundingBox.origin.y + $0.y * face.boundingBox.height) * imageSize.height }.reduce(0, +) / CGFloat(leftPoints.count)
                    let rightY = rightPoints.map { (face.boundingBox.origin.y + $0.y * face.boundingBox.height) * imageSize.height }.reduce(0, +) / CGFloat(rightPoints.count)
                    eyesCenterY = (leftY + rightY) / 2
                }
            }

            // coverageに応じて中心点をスムーズに移動
            // coverage 1.0 では頭全体（髪の毛含む）+ 顎下をカバー
            let faceCenterY = faceRect.midY
            // 中心点は顔の中央より少し上（頭頂部と顎下の両方をカバーするため）
            let headCenterY = faceCenterY + faceRect.height * 0.15  // 顔中央より少し上
            let filterCenterY = eyesCenterY + (headCenterY - eyesCenterY) * coverage
            let filterCenterX = faceRect.midX

            // サイズを計算
            // coverage 0.0: 目の周辺のみ (幅70%, 高さ30%)
            // coverage 1.0: 頭全体+顎下 (幅170%, 高さ250%)
            let filterWidth = faceRect.width * (0.7 + coverage * 1.0)
            let filterHeight = faceRect.height * (0.3 + coverage * 2.2)

            // フィルター領域を計算
            let filterRect = CGRect(
                x: filterCenterX - filterWidth / 2,
                y: filterCenterY - filterHeight / 2,
                width: filterWidth,
                height: filterHeight
            )

            // 画像範囲内にクリップ
            let clippedRect = filterRect.intersection(image.extent)
            guard !clippedRect.isEmpty, clippedRect.width > 10, clippedRect.height > 10 else { continue }

            // フィルタータイプに応じて処理を分岐
            var filteredImage: CIImage?

            switch filterType {
            case .mosaic:
                guard let filter = pixellateFilter else { continue }
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(intensity, forKey: kCIInputScaleKey)
                filter.setValue(CIVector(cgPoint: CGPoint(x: clippedRect.midX, y: clippedRect.midY)), forKey: kCIInputCenterKey)
                filteredImage = filter.outputImage

            case .blur:
                guard let filter = gaussianBlurFilter else { continue }
                let blurRadius = intensity * 0.5
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
                filteredImage = filter.outputImage
            }

            guard let processedFilterImage = filteredImage else { continue }

            // coverageに応じて形状を変化させる
            // coverage 0.0-0.3: 四角（目用）
            // coverage 0.3-0.7: 角丸
            // coverage 0.7-1.0: 楕円（顔全体用）
            let minDimension = min(clippedRect.width, clippedRect.height)
            let maxCornerRadius = minDimension / 2  // 楕円になる最大角丸

            // coverageに基づいて角丸半径を計算
            // 0.0-0.3: 0% (四角)
            // 0.3-0.7: 0%-70% (角丸)
            // 0.7-1.0: 70%-100% (楕円)
            let cornerRadiusRatio: CGFloat
            if coverage < 0.3 {
                cornerRadiusRatio = 0
            } else if coverage < 0.7 {
                cornerRadiusRatio = (coverage - 0.3) / 0.4 * 0.7
            } else {
                cornerRadiusRatio = 0.7 + (coverage - 0.7) / 0.3 * 0.3
            }
            let cornerRadius = maxCornerRadius * cornerRadiusRatio

            // マスクを作成して形状を適用
            if let maskedFilter = applyShapeMask(
                filteredImage: processedFilterImage,
                originalImage: outputImage,
                rect: clippedRect,
                cornerRadius: cornerRadius
            ) {
                outputImage = maskedFilter
            } else {
                // フォールバック: 単純な矩形クリップ
                let croppedFilter = processedFilterImage.cropped(to: clippedRect)
                outputImage = croppedFilter.composited(over: outputImage)
            }
        }

        return outputImage
    }

    // MARK: - Apply Privacy Filter to Bodies (Person Detection)
    /// 人物検出結果に基づいてプライバシーフィルターを適用（頭部領域のみ）
    private func applyPrivacyFilterToBodies(image: CIImage, bodies: [CGRect], filterType: PrivacyFilterType, intensity: CGFloat) -> CIImage {
        var outputImage = image
        let imageSize = image.extent.size

        // 処理する人数を制限（最大5人）
        let maxBodies = min(bodies.count, 5)
        let bodiesToProcess = Array(bodies.prefix(maxBodies))

        for bodyRect in bodiesToProcess {
            // 無効なデータをスキップ
            guard bodyRect.width > 0.01, bodyRect.height > 0.01 else { continue }

            // 正規化された座標を画像座標に変換
            let rect = CGRect(
                x: bodyRect.origin.x * imageSize.width,
                y: bodyRect.origin.y * imageSize.height,
                width: bodyRect.width * imageSize.width,
                height: bodyRect.height * imageSize.height
            )

            // 小さすぎる領域はスキップ
            guard rect.width > 20, rect.height > 20 else { continue }

            // 頭部領域を推定（上半身検出結果から頭部位置を計算）
            // upperBodyOnly=trueなので、上半身（頭から腰まで）が検出される
            // 頭部＋顎を完全にカバーするため、範囲を大きめに設定
            let headHeightRatio: CGFloat = 0.60  // 上部60%を頭部領域とする（頭頂から顎下まで）
            let headWidthRatio: CGFloat = 0.90   // 幅は体の90%程度（横顔も考慮）
            let headHeight = rect.height * headHeightRatio
            let headWidth = rect.width * headWidthRatio

            // 頭部の中心位置（X: 体の中心、Y: 上部寄り）
            let headCenterX = rect.midX
            let headCenterY = rect.maxY - headHeight * 0.45  // 上寄りに配置（頭頂もカバー）

            let headRect = CGRect(
                x: headCenterX - headWidth / 2,
                y: headCenterY - headHeight / 2,
                width: headWidth,
                height: headHeight
            )

            // 画像範囲内にクリップ
            let clippedRect = headRect.intersection(image.extent)
            guard !clippedRect.isEmpty, clippedRect.width > 10, clippedRect.height > 10 else { continue }

            // フィルター適用
            var filteredImage: CIImage?

            switch filterType {
            case .mosaic:
                guard let filter = pixellateFilter else { continue }
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(intensity, forKey: kCIInputScaleKey)
                filter.setValue(CIVector(cgPoint: CGPoint(x: clippedRect.midX, y: clippedRect.midY)), forKey: kCIInputCenterKey)
                filteredImage = filter.outputImage

            case .blur:
                guard let filter = gaussianBlurFilter else { continue }
                let blurRadius = intensity * 0.5
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
                filteredImage = filter.outputImage
            }

            guard let processedFilterImage = filteredImage else { continue }

            // 楕円形のマスクを適用（頭部用）
            let minDimension = min(clippedRect.width, clippedRect.height)
            let cornerRadius = minDimension / 2  // 楕円形

            if let maskedFilter = applyShapeMask(
                filteredImage: processedFilterImage,
                originalImage: outputImage,
                rect: clippedRect,
                cornerRadius: cornerRadius
            ) {
                outputImage = maskedFilter
            } else {
                // フォールバック
                let croppedFilter = processedFilterImage.cropped(to: clippedRect)
                outputImage = croppedFilter.composited(over: outputImage)
            }
        }

        return outputImage
    }

    // MARK: - Apply Shape Mask to Filter
    /// フィルター適用領域に形状マスクを適用
    private func applyShapeMask(filteredImage: CIImage, originalImage: CIImage, rect: CGRect, cornerRadius: CGFloat) -> CIImage? {
        // 角丸矩形のマスク画像を作成
        let maskSize = rect.size
        UIGraphicsBeginImageContextWithOptions(maskSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        // 白で塗りつぶした角丸矩形
        UIColor.white.setFill()
        let path = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: maskSize),
            cornerRadius: cornerRadius
        )
        path.fill()

        guard let maskUIImage = UIGraphicsGetImageFromCurrentImageContext(),
              let maskCGImage = maskUIImage.cgImage else {
            return nil
        }

        // マスクをCIImageに変換し、正しい位置に移動
        var maskCIImage = CIImage(cgImage: maskCGImage)
        maskCIImage = maskCIImage.transformed(by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y))

        // フィルター画像をクリップ
        let croppedFilter = filteredImage.cropped(to: rect)

        // マスクを使ってブレンド
        guard let blendFilter = blendWithMaskFilter else {
            return nil
        }

        blendFilter.setValue(croppedFilter, forKey: kCIInputImageKey)
        blendFilter.setValue(originalImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage
    }

    // MARK: - Recording
    private var frameCount: Int = 0
    private var lastFrameTime: CMTime = .zero
    private let recordingLock = NSLock()

    func startRecording(maxDuration: TimeInterval? = nil, isPro: Bool = false) {
        recordingLock.lock()
        defer { recordingLock.unlock() }

        guard !isRecording else { return }

        // Pro版かどうかをキャッシュ（ウォーターマーク判定用）
        isProUser = isPro

        // 録画用に高画質に切り替え
        setRecordingQuality(mainIsBack: recordingMainIsBack)

        // 録画開始前にメモリをクリーンアップ
        isLowMemory = false
        lastRecordingFrameTime = 0
        detectedFacesFront.removeAll()
        detectedFacesBack.removeAll()

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "DualMoza_\(dateFormatter.string(from: Date())).mp4"
        recordingURL = documentsPath.appendingPathComponent(fileName)

        guard let url = recordingURL else { return }

        // 既存のファイルがあれば削除
        try? FileManager.default.removeItem(at: url)

        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

            // 720p出力（パフォーマンス優先）
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2000000,  // 2Mbps
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]

            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true

            // sourcePixelBufferAttributesをnilにして、入力ピクセルバッファの変換を許可
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: nil
            )

            if assetWriter?.canAdd(videoInput!) == true {
                assetWriter?.add(videoInput!)
            }

            // Audio input settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]

            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput?.expectsMediaDataInRealTime = true

            if assetWriter?.canAdd(audioWriterInput!) == true {
                assetWriter?.add(audioWriterInput!)
                print("Audio writer input added")
            }

            assetWriter?.startWriting()
            isRecording = true
            recordingStartTime = nil
            frameCount = 0
            lastFrameTime = .zero
            audioSampleCount = 0
            audioStartTime = nil

            print("Recording started: \(url)")
            print("AssetWriter status after start: \(assetWriter!.status.rawValue)")

        } catch {
            print("録画の開始に失敗: \(error)")
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            print("stopRecording called but not recording")
            completion(nil)
            return
        }

        isRecording = false
        print("Stopping recording. Total frames written: \(frameCount), audio samples: \(audioSampleCount)")

        // プレビュー用に低画質に戻す
        setPreviewQuality()

        // Clear stored frames to free memory
        frameLock.lock()
        latestFrontCIImage = nil
        latestBackCIImage = nil
        frameLock.unlock()

        guard let assetWriter = assetWriter else {
            print("AssetWriter is nil")
            cleanupRecordingResources()
            completion(nil)
            return
        }

        if assetWriter.status == .writing {
            videoInput?.markAsFinished()
            audioWriterInput?.markAsFinished()
            assetWriter.finishWriting { [weak self] in
                self?.cleanupRecordingResources()
                DispatchQueue.main.async {
                    if assetWriter.status == .completed {
                        print("Recording completed successfully: \(self?.recordingURL?.path ?? "nil")")
                        completion(self?.recordingURL)
                    } else {
                        print("Recording failed with status: \(assetWriter.status.rawValue), error: \(assetWriter.error?.localizedDescription ?? "none")")
                        completion(nil)
                    }
                }
            }
        } else {
            print("AssetWriter status is not writing: \(assetWriter.status.rawValue), error: \(assetWriter.error?.localizedDescription ?? "none")")
            cleanupRecordingResources()
            completion(nil)
        }
    }

    private func cleanupRecordingResources() {
        assetWriter = nil
        videoInput = nil
        audioWriterInput = nil
        pixelBufferAdaptor = nil
        recordingStartTime = nil

        // ピクセルバッファプールも解放してメモリを節約
        if let pool = pixelBufferPool {
            CVPixelBufferPoolFlush(pool, .excessBuffers)
        }
        pixelBufferPool = nil

        // 低メモリフラグをリセット
        isLowMemory = false

        // 録画用のキャッシュ画像をクリア
        frameLock.lock()
        latestFrontCIImage = nil
        latestBackCIImage = nil
        frameLock.unlock()
    }

    // MARK: - Handle Audio Sample Buffer
    private var audioSampleCount: Int = 0
    private var audioStartTime: CMTime?

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }

        guard let audioWriterInput = audioWriterInput else {
            if audioSampleCount == 0 {
                print("Audio writer input is nil")
            }
            return
        }

        guard let assetWriter = assetWriter, assetWriter.status == .writing else {
            if audioSampleCount == 0 {
                print("Asset writer not in writing state: \(self.assetWriter?.status.rawValue ?? -1)")
            }
            return
        }

        // 録画開始時間が設定されていない場合はスキップ（ビデオフレームが来るまで待つ）
        guard let videoStartTime = recordingStartTime else {
            return
        }

        guard audioWriterInput.isReadyForMoreMediaData else {
            return
        }

        // オーディオの開始時間を記録
        let audioTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if audioStartTime == nil {
            audioStartTime = audioTimestamp
            print("Audio recording started at: \(audioTimestamp.seconds)")
        }

        // タイムスタンプを調整（ビデオと同期）
        let adjustedTime = CMTimeSubtract(audioTimestamp, videoStartTime)

        // 負のタイムスタンプはスキップ
        guard CMTimeGetSeconds(adjustedTime) >= 0 else {
            return
        }

        // タイムスタンプを調整したサンプルバッファを作成
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: adjustedTime,
            decodeTimeStamp: .invalid
        )

        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )

        guard status == noErr, let buffer = adjustedBuffer else {
            // フォールバック: 元のバッファを使用
            if audioWriterInput.append(sampleBuffer) {
                audioSampleCount += 1
                if audioSampleCount % 100 == 1 {
                    print("Audio samples written (original): \(audioSampleCount)")
                }
            }
            return
        }

        // 調整されたオーディオサンプルを書き込み
        if audioWriterInput.append(buffer) {
            audioSampleCount += 1
            if audioSampleCount % 100 == 1 {
                print("Audio samples written: \(audioSampleCount), time: \(CMTimeGetSeconds(adjustedTime))s")
            }
        } else {
            print("Failed to append audio sample buffer, writer status: \(assetWriter.status.rawValue), error: \(assetWriter.error?.localizedDescription ?? "none")")
        }
    }

    // MARK: - Photo Capture
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        // 現在のフレームから静止画をキャプチャ
        // backCameraImageを使用（メインカメラ）
        DispatchQueue.main.async { [weak self] in
            completion(self?.backCameraImage)
        }
    }

    // 両カメラの合成画像をキャプチャ
    func captureCombinedPhoto(mainImage: UIImage?, pipImage: UIImage?, pipSettings: PiPSettings, screenSize: CGSize, isPro: Bool = false, completion: @escaping (UIImage?) -> Void) {
        guard let mainImage = mainImage else {
            completion(nil)
            return
        }

        processingQueue.async { [isPro] in
            // 出力サイズ（1080x1920）
            let outputSize = CGSize(width: 1080, height: 1920)
            let scale = outputSize.width / screenSize.width

            UIGraphicsBeginImageContextWithOptions(outputSize, true, 1.0)
            defer { UIGraphicsEndImageContext() }

            // メイン画像をアスペクト比を維持してセンタークロップで描画
            let mainImageSize = mainImage.size
            let mainAspect = mainImageSize.width / mainImageSize.height
            let outputAspect = outputSize.width / outputSize.height

            let drawRect: CGRect
            if mainAspect > outputAspect {
                // 画像が横長 - 幅に合わせてクロップ
                let scaledHeight = outputSize.height
                let scaledWidth = scaledHeight * mainAspect
                let offsetX = (scaledWidth - outputSize.width) / 2
                drawRect = CGRect(x: -offsetX, y: 0, width: scaledWidth, height: scaledHeight)
            } else {
                // 画像が縦長 - 高さに合わせてクロップ
                let scaledWidth = outputSize.width
                let scaledHeight = scaledWidth / mainAspect
                let offsetY = (scaledHeight - outputSize.height) / 2
                drawRect = CGRect(x: 0, y: -offsetY, width: scaledWidth, height: scaledHeight)
            }
            mainImage.draw(in: drawRect)

            // PiP画像を描画（存在する場合）
            if let pipImage = pipImage {
                let pipSize = pipSettings.size * scale
                let pipWidth = pipSize
                let pipHeight = pipSettings.shape == .circle ? pipSize : pipSize * 1.3
                let pipX = pipSettings.position.x * scale - pipWidth / 2
                let pipY = pipSettings.position.y * scale - pipHeight / 2

                let pipRect = CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight)

                // PiP画像のアスペクト比を維持してセンタークロップ
                let pipImageSize = pipImage.size
                let pipImageAspect = pipImageSize.width / pipImageSize.height
                let pipTargetAspect = pipWidth / pipHeight

                let pipDrawRect: CGRect
                if pipImageAspect > pipTargetAspect {
                    // 画像が横長 - 高さに合わせてスケール、幅をクロップ
                    let scaledHeight = pipHeight
                    let scaledWidth = scaledHeight * pipImageAspect
                    let offsetX = (scaledWidth - pipWidth) / 2
                    pipDrawRect = CGRect(x: pipX - offsetX, y: pipY, width: scaledWidth, height: scaledHeight)
                } else {
                    // 画像が縦長 - 幅に合わせてスケール、高さをクロップ
                    let scaledWidth = pipWidth
                    let scaledHeight = scaledWidth / pipImageAspect
                    let offsetY = (scaledHeight - pipHeight) / 2
                    pipDrawRect = CGRect(x: pipX, y: pipY - offsetY, width: scaledWidth, height: scaledHeight)
                }

                // クリッピングパスを設定
                let path: UIBezierPath
                if pipSettings.shape == .circle {
                    path = UIBezierPath(ovalIn: pipRect)
                } else {
                    path = UIBezierPath(roundedRect: pipRect, cornerRadius: 12 * scale)
                }

                // クリッピングして描画
                if let context = UIGraphicsGetCurrentContext() {
                    context.saveGState()
                    path.addClip()
                    pipImage.draw(in: pipDrawRect)
                    context.restoreGState()

                    // 白い枠線を描画
                    UIColor.white.setStroke()
                    path.lineWidth = 3 * scale
                    path.stroke()
                }
            }

            // 無料版はウォーターマークを追加
            if !isPro {
                let text = "DualMoza"
                let fontSize: CGFloat = min(outputSize.width, outputSize.height) * 0.035
                let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.5)
                ]
                let textSize = (text as NSString).size(withAttributes: attributes)
                let padding: CGFloat = fontSize * 0.5
                let textX = outputSize.width - textSize.width - padding
                let textY = outputSize.height - textSize.height - padding
                (text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
            }

            let combinedImage = UIGraphicsGetImageFromCurrentImageContext()

            DispatchQueue.main.async {
                completion(combinedImage)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Handle audio output
        if output == audioOutput {
            handleAudioSampleBuffer(sampleBuffer)
            return
        }

        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let currentTime = CFAbsoluteTimeGetCurrent()
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Determine which camera this is from
            let isFrontCamera = (output == frontOutput)
            let isBackCamera = (output == backOutput)
            let mosaicEnabled = isFrontCamera ? frontMosaicEnabled : backMosaicEnabled
            let privacyFilterType = isFrontCamera ? frontPrivacyFilterType : backPrivacyFilterType
            let detectionMode = isFrontCamera ? frontDetectionMode : backDetectionMode
            let mosaicIntensity = isFrontCamera ? frontMosaicIntensity : backMosaicIntensity
            let mosaicCoverage = isFrontCamera ? frontMosaicCoverage : backMosaicCoverage

            // Create CIImage (lightweight, doesn't copy pixel data)
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            // Check if we should process this frame for preview
            // 録画中または低メモリ時はプレビューフレームレートを下げる
            // カメラごとに個別に管理して、両方のカメラが同じフレームレートで更新されるようにする
            let currentPreviewInterval = (self.isRecording || self.isLowMemory) ? previewFrameIntervalRecording : previewFrameInterval
            let lastPreviewTime = isFrontCamera ? lastPreviewTimeFront : lastPreviewTimeBack
            let shouldUpdatePreview = (currentTime - lastPreviewTime) >= currentPreviewInterval

            // 検出は低メモリ時はスキップ（人物検出は間隔を少し長めに）
            let detectionInterval = detectionMode == .personDetection ? faceDetectionInterval * 1.5 : faceDetectionInterval
            let shouldRunDetection = mosaicEnabled && !self.isLowMemory && (currentTime - lastFaceDetectionTime) >= detectionInterval

            // Detection (throttled, runs on separate queue to avoid blocking)
            if shouldRunDetection {
                lastFaceDetectionTime = currentTime
                let bufferForDetection = pixelBuffer
                let isForFrontCamera = isFrontCamera
                let currentDetectionMode = detectionMode

                faceDetectionQueue.async { [weak self] in
                    autoreleasepool {
                        do {
                            // orientationを指定しない（CIImageと同じ座標系で検出結果を取得）
                            let handler = VNImageRequestHandler(cvPixelBuffer: bufferForDetection, options: [:])

                            if currentDetectionMode == .personDetection {
                                // 人物検出モード (iOS 17+)
                                if #available(iOS 17.0, *) {
                                    if let request = self?.humanRectanglesRequest as? VNDetectHumanRectanglesRequest {
                                        try handler.perform([request])
                                        let observations = request.results ?? []
                                        let bodyRects = observations.map { $0.boundingBox }
                                        if isForFrontCamera {
                                            self?.detectedBodiesFront = bodyRects
                                        } else {
                                            self?.detectedBodiesBack = bodyRects
                                        }
                                    }
                                }
                            } else {
                                // 顔検出モード
                                if let request = self?.faceLandmarksRequest {
                                    try handler.perform([request])
                                    let observations = request.results ?? []
                                    if isForFrontCamera {
                                        self?.detectedFacesFront = observations
                                    } else {
                                        self?.detectedFacesBack = observations
                                    }
                                }
                            }
                        } catch {
                            // 検出エラーは無視
                        }
                    }
                }
            }

            // Process image with privacy filter if enabled
            var processedImage = ciImage
            if mosaicEnabled {
                autoreleasepool {
                    if detectionMode == .personDetection {
                        // 人物検出モード
                        let bodiesForCamera = isFrontCamera ? self.detectedBodiesFront : self.detectedBodiesBack
                        if !bodiesForCamera.isEmpty {
                            processedImage = self.applyPrivacyFilterToBodies(image: ciImage, bodies: bodiesForCamera, filterType: privacyFilterType, intensity: mosaicIntensity)
                        }
                    } else {
                        // 顔検出モード
                        let facesForCamera = isFrontCamera ? self.detectedFacesFront : self.detectedFacesBack
                        if !facesForCamera.isEmpty {
                            processedImage = self.applyPrivacyFilterToFaces(image: ciImage, faces: facesForCamera, filterType: privacyFilterType, intensity: mosaicIntensity, coverage: mosaicCoverage)
                        }
                    }
                }
            }

            // Store processed frame for recording (throttle to 30fps to reduce memory pressure)
            if self.isRecording {
                // 録画フレームのスロットリング（30fps）
                let shouldRecordFrame = (currentTime - lastRecordingFrameTime) >= recordingFrameInterval

                if shouldRecordFrame {
                    lastRecordingFrameTime = currentTime

                    self.frameLock.lock()
                    if isFrontCamera {
                        self.latestFrontCIImage = processedImage
                    } else {
                        self.latestBackCIImage = processedImage
                    }
                    self.frameLock.unlock()

                    // Recording: compose and write frame from main camera trigger
                    let isMainCamera = self.recordingMainIsBack ? isBackCamera : isFrontCamera
                    if isMainCamera {
                        self.writeComposedFrame(time: presentationTime)
                    }
                }
            }

            // Update preview (throttled, process on background to avoid blocking video queue)
            if shouldUpdatePreview {
                // カメラごとに個別に更新
                if isFrontCamera {
                    lastPreviewTimeFront = currentTime
                } else {
                    lastPreviewTimeBack = currentTime
                }
                let imageToProcess = processedImage
                let isForFrontCamera = isFrontCamera

                self.processingQueue.async { [weak self] in
                    autoreleasepool {
                        guard let self = self else { return }
                        if let cgImage = self.ciContext.createCGImage(imageToProcess, from: imageToProcess.extent) {
                            let uiImage = UIImage(cgImage: cgImage)

                            DispatchQueue.main.async {
                                if isForFrontCamera {
                                    self.frontCameraImage = uiImage
                                } else {
                                    self.backCameraImage = uiImage
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Write Composed Frame with PiP
    private func writeComposedFrame(time: CMTime) {
        recordingLock.lock()
        defer { recordingLock.unlock() }

        guard isRecording else { return }

        guard let assetWriter = assetWriter,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor else {
            if frameCount == 0 {
                print("writeComposedFrame: assetWriter, videoInput, or adaptor is nil")
            }
            return
        }

        // AssetWriterの状態をチェック
        guard assetWriter.status == .writing else {
            if frameCount == 0 {
                print("writeComposedFrame: AssetWriter status is not writing: \(assetWriter.status.rawValue)")
            }
            return
        }

        if recordingStartTime == nil {
            recordingStartTime = time
            assetWriter.startSession(atSourceTime: .zero)
            print("Recording session started at time: \(time.seconds)")
        }

        // 時間の進行をチェック
        let presentationTime = CMTimeSubtract(time, recordingStartTime!)

        guard CMTimeCompare(presentationTime, lastFrameTime) > 0 || frameCount == 0 else {
            return
        }

        guard videoInput.isReadyForMoreMediaData else {
            if frameCount < 5 {
                print("VideoInput not ready for more data at frame \(frameCount)")
            }
            return
        }

        // Get latest frames
        frameLock.lock()
        let mainImage = recordingMainIsBack ? latestBackCIImage : latestFrontCIImage
        let pipImage = recordingMainIsBack ? latestFrontCIImage : latestBackCIImage
        frameLock.unlock()

        guard let mainCIImage = mainImage else { return }

        // Compose the frame
        autoreleasepool {
            let composedImage = composeFrameWithPiP(main: mainCIImage, pip: recordingPiPEnabled ? pipImage : nil)

            // Create pixel buffer from composed image
            if let pixelBuffer = createPixelBuffer(from: composedImage) {
                let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                if success {
                    frameCount += 1
                    lastFrameTime = presentationTime
                    if frameCount % 30 == 0 {
                        print("Frames written: \(frameCount), time: \(presentationTime.seconds)s")
                    }
                } else {
                    print("Failed to append pixel buffer at time: \(presentationTime.seconds)")
                }
            }
        }
    }

    // MARK: - Compose Frame with PiP
    private func composeFrameWithPiP(main: CIImage, pip: CIImage?) -> CIImage {
        // Output size: 720x1280 (720p for better performance)
        let outputWidth: CGFloat = 720
        let outputHeight: CGFloat = 1280

        // Scale main image to fill output
        let mainScaleX = outputWidth / main.extent.width
        let mainScaleY = outputHeight / main.extent.height
        let mainScale = max(mainScaleX, mainScaleY)

        var scaledMain = main.transformed(by: CGAffineTransform(scaleX: mainScale, y: mainScale))

        // Center crop
        let mainOffsetX = (scaledMain.extent.width - outputWidth) / 2
        let mainOffsetY = (scaledMain.extent.height - outputHeight) / 2
        scaledMain = scaledMain.transformed(by: CGAffineTransform(translationX: -mainOffsetX - scaledMain.extent.origin.x, y: -mainOffsetY - scaledMain.extent.origin.y))
        scaledMain = scaledMain.cropped(to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        guard let pipImage = pip else {
            // PiPなしでもウォーターマークを追加
            return addWatermark(to: scaledMain, outputSize: CGSize(width: outputWidth, height: outputHeight))
        }

        // Calculate PiP position and size for output
        let scale = outputWidth / recordingScreenSize.width
        let pipSize = recordingPiPSize * scale

        // PiPのアスペクト比を決定
        // 円形: 正方形（1:1）
        // 四角形: 縦長（1:1.3）
        let pipWidth: CGFloat
        let pipHeight: CGFloat
        if recordingPiPShape == .circle {
            pipWidth = pipSize
            pipHeight = pipSize
        } else {
            pipWidth = pipSize
            pipHeight = pipSize * 1.3
        }

        // Convert screen position to output position (flip Y axis for CIImage)
        let pipX = recordingPiPPosition.x * scale - pipWidth / 2
        let pipY = outputHeight - (recordingPiPPosition.y * scale) - pipHeight / 2

        // Scale PiP image to fill target area while maintaining aspect ratio
        let pipImageAspect = pipImage.extent.width / pipImage.extent.height
        let targetAspect = pipWidth / pipHeight

        let pipScaledWidth: CGFloat
        let pipScaledHeight: CGFloat

        if pipImageAspect > targetAspect {
            // Image is wider - scale to match height, crop width
            pipScaledHeight = pipHeight
            pipScaledWidth = pipHeight * pipImageAspect
        } else {
            // Image is taller - scale to match width, crop height
            pipScaledWidth = pipWidth
            pipScaledHeight = pipWidth / pipImageAspect
        }

        let pipScaleX = pipScaledWidth / pipImage.extent.width
        let pipScaleY = pipScaledHeight / pipImage.extent.height
        // Use uniform scale to preserve aspect ratio
        let pipScale = pipScaleX  // Both should be equal due to calculation above

        var scaledPiP = pipImage.transformed(by: CGAffineTransform(scaleX: pipScale, y: pipScale))

        // Center crop PiP to target size
        let pipCropWidth = pipWidth
        let pipCropHeight = pipHeight
        let pipOffsetX = (scaledPiP.extent.width - pipCropWidth) / 2
        let pipOffsetY = (scaledPiP.extent.height - pipCropHeight) / 2
        scaledPiP = scaledPiP.cropped(to: CGRect(
            x: scaledPiP.extent.origin.x + pipOffsetX,
            y: scaledPiP.extent.origin.y + pipOffsetY,
            width: pipCropWidth,
            height: pipCropHeight
        ))

        // Move PiP to correct position
        scaledPiP = scaledPiP.transformed(by: CGAffineTransform(translationX: pipX - scaledPiP.extent.origin.x, y: pipY - scaledPiP.extent.origin.y))

        // Create mask for PiP shape
        let pipRect = CGRect(x: pipX, y: pipY, width: pipSize, height: pipHeight)

        if recordingPiPShape == .circle {
            // Circle mask using cached radial gradient filter
            guard let maskFilter = radialGradientFilter,
                  let blendFilter = blendWithMaskFilter else {
                // Fallback to simple composite
                var result = scaledPiP.composited(over: scaledMain)
                result = result.cropped(to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
                return addWatermark(to: result, outputSize: CGSize(width: outputWidth, height: outputHeight))
            }

            let center = CIVector(x: pipRect.midX, y: pipRect.midY)
            let radius = pipSize / 2
            maskFilter.setValue(center, forKey: kCIInputCenterKey)
            maskFilter.setValue(radius - 1, forKey: "inputRadius0")
            maskFilter.setValue(radius, forKey: "inputRadius1")
            maskFilter.setValue(CIColor.white, forKey: "inputColor0")
            maskFilter.setValue(CIColor.clear, forKey: "inputColor1")

            if let maskImage = maskFilter.outputImage {
                // Blend PiP with main using cached mask filter
                blendFilter.setValue(scaledPiP, forKey: kCIInputImageKey)
                blendFilter.setValue(scaledMain, forKey: kCIInputBackgroundImageKey)
                blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

                if let result = blendFilter.outputImage {
                    let croppedResult = result.cropped(to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
                    // 無料版はウォーターマークを追加
                    return addWatermark(to: croppedResult, outputSize: CGSize(width: outputWidth, height: outputHeight))
                }
            }
        }

        // Rectangle: simple composite
        var result = scaledPiP.composited(over: scaledMain)
        result = result.cropped(to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        // 無料版はウォーターマークを追加
        return addWatermark(to: result, outputSize: CGSize(width: outputWidth, height: outputHeight))
    }

    // MARK: - Create Pixel Buffer from CIImage (with Pool Reuse)
    private func createPixelBuffer(from ciImage: CIImage) -> CVPixelBuffer? {
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)

        // プールから再利用可能なバッファを取得、またはプールを作成
        if pixelBufferPool == nil {
            createPixelBufferPool(width: width, height: height)
        }

        var pixelBuffer: CVPixelBuffer?

        // プールからバッファを取得（可能な場合）
        if let pool = pixelBufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                ciContext.render(ciImage, to: buffer)
                return buffer
            }
        }

        // フォールバック：直接バッファを作成
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        ciContext.render(ciImage, to: buffer)
        return buffer
    }

    // MARK: - Create Pixel Buffer Pool
    private func createPixelBufferPool(width: Int, height: Int) {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
        ]

        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        pixelBufferPool = pool
    }

    // MARK: - Watermark for Free Users
    /// ウォーターマーク画像を作成（キャッシュして再利用）
    private func getWatermarkImage(for outputSize: CGSize) -> CIImage? {
        // Pro版はウォーターマーク不要
        if isProUser {
            return nil
        }

        // キャッシュがあり、サイズが同じなら再利用
        if let cached = cachedWatermarkImage, cachedWatermarkSize == outputSize {
            return cached
        }

        // ウォーターマークを作成
        let text = "DualMoza"
        let fontSize: CGFloat = min(outputSize.width, outputSize.height) * 0.035  // 画面の3.5%
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.5)  // 半透明の白
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = fontSize * 0.5

        // 右下に配置するための位置を計算
        let imageSize = CGSize(width: outputSize.width, height: outputSize.height)

        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        // 背景を透明に
        UIColor.clear.setFill()
        UIRectFill(CGRect(origin: .zero, size: imageSize))

        // テキストを右下に描画
        let textX = imageSize.width - textSize.width - padding
        let textY = imageSize.height - textSize.height - padding
        let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: textSize.height)
        (text as NSString).draw(in: textRect, withAttributes: attributes)

        guard let uiImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = uiImage.cgImage else {
            return nil
        }

        // CIImageに変換（Y軸を反転してCIImage座標系に合わせる）
        let ciImage = CIImage(cgImage: cgImage)

        // キャッシュに保存
        cachedWatermarkImage = ciImage
        cachedWatermarkSize = outputSize

        return ciImage
    }

    /// CIImageにウォーターマークを合成
    private func addWatermark(to image: CIImage, outputSize: CGSize) -> CIImage {
        guard let watermark = getWatermarkImage(for: outputSize) else {
            return image
        }

        // ウォーターマークを画像の上に合成
        return watermark.composited(over: image)
    }
}
