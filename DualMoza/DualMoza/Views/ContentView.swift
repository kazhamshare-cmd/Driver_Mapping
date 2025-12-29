import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var adManager: AdManager
    @StateObject private var languageManager = LanguageManager.shared

    @StateObject private var cameraManager = CameraManager()

    @State private var showControls = true
    @State private var showAdAlert = false
    @State private var showPurchaseSheet = false
    @State private var showSettingsSheet = false
    @State private var recordingTimer: Timer?
    @State private var showSaveSuccess = false
    @State private var saveMessage = ""
    @State private var isCapturing = false
    @State private var showCameraDetailedSettings = false

    // iPad対応
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // ランドスケープ検出
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)

                // Main Camera View
                mainCameraView
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)

                // PiP View (has its own gesture handlers)
                if shouldShowPiP {
                    PiPView(
                        image: pipImage,
                        settings: appState.pipSettings
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Recording indicator
                if appState.isRecording {
                    recordingIndicator
                        .position(
                            x: isLandscape ? 100 : geometry.size.width / 2,
                            y: isLandscape ? 40 : 80
                        )
                }

                // UI Layer (Sidebar, Bottom Bar, Top Bar)
                if showControls && !appState.isRecording {
                    if isLandscape {
                        // ランドスケープモード: サイドバーを左下、キャプチャボタンを右

                        // Top bar (左上)
                        topBar

                        // Sidebar (下に横配置)
                        VStack {
                            Spacer()
                            SidebarView(
                                cameraManager: cameraManager,
                                onFlipCamera: {
                                    withAnimation {
                                        appState.mainCameraIsBack.toggle()
                                        cameraManager.updateCameraQuality(mainIsBack: appState.mainCameraIsBack)
                                    }
                                },
                                onOpenSettings: {
                                    showSettingsSheet = true
                                },
                                onOpenCameraSettings: {
                                    showCameraDetailedSettings = true
                                },
                                isLandscape: true
                            )
                            .padding(.bottom, 16)
                        }

                        // Capture controls (右側)
                        HStack {
                            Spacer()
                            VStack(spacing: 24) {
                                // Gallery button
                                Button(action: openGallery) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(10)
                                }

                                // Capture button
                                Button(action: handleCaptureAction) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 5)
                                            .frame(width: 80, height: 80)

                                        if appState.captureMode == .video {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 60, height: 60)
                                        } else {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 60, height: 60)
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 24)
                        }
                    } else {
                        // ポートレートモード: 従来のレイアウト

                        // Sidebar (Right)
                        HStack {
                            Spacer()
                            SidebarView(
                                cameraManager: cameraManager,
                                onFlipCamera: {
                                    withAnimation {
                                        appState.mainCameraIsBack.toggle()
                                        cameraManager.updateCameraQuality(mainIsBack: appState.mainCameraIsBack)
                                    }
                                },
                                onOpenSettings: {
                                    showSettingsSheet = true
                                },
                                onOpenCameraSettings: {
                                    showCameraDetailedSettings = true
                                },
                                isLandscape: false
                            )
                            .padding(.trailing, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)

                        // Top bar
                        topBar

                        // Bottom bar
                        VStack {
                            Spacer()
                                .allowsHitTesting(false)
                            ModernBottomBar(
                                isCapturing: $isCapturing,
                                onCapture: handleCaptureAction,
                                onOpenGallery: openGallery
                            )
                        }
                    }
                } else if appState.isRecording {
                    // Recording UI with live controls
                    if isLandscape {
                        // ランドスケープ録画UI
                        HStack {
                            // 左側: 録画コントロール
                            VStack {
                                Spacer()
                                recordingControlsView
                                    .frame(maxWidth: geometry.size.width * 0.5)
                                Spacer()
                            }
                            .padding(.leading, 20)

                            Spacer()

                            // 右側: 停止ボタン
                            Button(action: toggleRecording) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 5)
                                        .frame(width: 80, height: 80)
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .padding(.trailing, 24)
                        }
                    } else {
                        // ポートレート録画UI
                        VStack {
                            // Recording indicator at top
                            recordingIndicator

                            Spacer()

                            // Live adjustment sliders during recording
                            recordingControlsView

                            // Stop button at bottom
                            Button(action: toggleRecording) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: isIPad ? 6 : 5)
                                        .frame(width: isIPad ? 110 : 80, height: isIPad ? 110 : 80)
                                    RoundedRectangle(cornerRadius: isIPad ? 12 : 8)
                                        .fill(Color.red)
                                        .frame(width: isIPad ? 50 : 36, height: isIPad ? 50 : 36)
                                }
                            }
                            .padding(.bottom, isIPad ? 60 : 40)
                        }
                    }
                }

                // Ad required overlay
                if appState.needsToWatchAd && !purchaseManager.isPro {
                    adRequiredOverlay
                }

                // Camera error overlay
                if cameraManager.cameraInterrupted {
                    cameraErrorOverlay
                }
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert(languageManager.L("save_success"), isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveMessage == "photo" ? languageManager.L("photo_saved") : languageManager.L("video_saved"))
        }
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseView()
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showCameraDetailedSettings) {
            CameraDetailedSettingsSheet(cameraManager: cameraManager)
                .environmentObject(appState)
        }
        .onChange(of: isLandscape) { newValue in
            // 向き変更時にPiPの位置をリセット
            let screenSize = UIScreen.main.bounds.size
            if newValue {
                // ランドスケープ: 左下に配置
                appState.pipSettings.position = CGPoint(
                    x: appState.pipSettings.size / 2 + 20,
                    y: screenSize.height - appState.pipSettings.size * 0.65 - 20
                )
            } else {
                // ポートレート: 左下に配置
                appState.pipSettings.position = CGPoint(
                    x: appState.pipSettings.size / 2 + 20,
                    y: screenSize.height - appState.pipSettings.size * 0.65 - 150
                )
            }
        }
    }

    // MARK: - Main Camera View
    @ViewBuilder
    private var mainCameraView: some View {
        // メインカメラがオフの場合、もう一方のカメラを全画面表示
        if let image = effectiveMainCameraImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.black
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Effective Main Camera Image
    // メインカメラがオフなら、セカンダリカメラを表示
    private var effectiveMainCameraImage: UIImage? {
        if appState.mainCameraIsBack {
            // バックカメラがメイン設定
            if appState.backCamera.mode == .on {
                // バックカメラ画像を返す（nilでも可）
                if let image = cameraManager.backCameraImage {
                    return image
                }
                // バックがnilならフロントをフォールバックとして使用
                return cameraManager.frontCameraImage
            } else if appState.backCamera.mode == .staticImage, let image = appState.backCamera.staticImage {
                return image
            } else if appState.backCamera.mode == .off {
                // バックカメラがオフならフロントカメラを全画面表示
                if appState.frontCamera.mode == .on {
                    return cameraManager.frontCameraImage
                } else if appState.frontCamera.mode == .staticImage {
                    return appState.frontCamera.staticImage
                }
            }
        } else {
            // フロントカメラがメイン設定
            if appState.frontCamera.mode == .on {
                // フロントカメラ画像を返す（nilでも可）
                if let image = cameraManager.frontCameraImage {
                    return image
                }
                // フロントがnilならバックをフォールバックとして使用
                return cameraManager.backCameraImage
            } else if appState.frontCamera.mode == .staticImage, let image = appState.frontCamera.staticImage {
                return image
            } else if appState.frontCamera.mode == .off {
                // フロントカメラがオフならバックカメラを全画面表示
                if appState.backCamera.mode == .on {
                    return cameraManager.backCameraImage
                } else if appState.backCamera.mode == .staticImage {
                    return appState.backCamera.staticImage
                }
            }
        }
        // 最終フォールバック：どちらかの画像を返す
        return cameraManager.backCameraImage ?? cameraManager.frontCameraImage
    }

    // MARK: - Is Main Camera Off (for PiP logic)
    private var isMainCameraOff: Bool {
        if appState.mainCameraIsBack {
            return appState.backCamera.mode == .off
        } else {
            return appState.frontCamera.mode == .off
        }
    }

    // MARK: - PiP Image
    private var pipImage: UIImage? {
        if appState.mainCameraIsBack {
            // Main is back, PiP is front
            if appState.frontCamera.mode == .on {
                return cameraManager.frontCameraImage
            } else if appState.frontCamera.mode == .staticImage {
                return appState.frontCamera.staticImage
            }
        } else {
            // Main is front, PiP is back
            if appState.backCamera.mode == .on {
                return cameraManager.backCameraImage
            } else if appState.backCamera.mode == .staticImage {
                return appState.backCamera.staticImage
            }
        }
        return nil
    }

    // MARK: - Should Show PiP
    private var shouldShowPiP: Bool {
        // メインカメラがオフの場合、セカンダリが全画面表示されるのでPiPは不要
        if isMainCameraOff {
            return false
        }
        // 両方のカメラがオンの場合のみPiPを表示
        if appState.mainCameraIsBack {
            return appState.frontCamera.mode != .off
        } else {
            return appState.backCamera.mode != .off
        }
    }

    // MARK: - Recording Indicator
    private var recordingIndicator: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: isIPad ? 16 : 12, height: isIPad ? 16 : 12)

            Text(formatDuration(appState.recordingDuration))
                .font(.system(isIPad ? .title3 : .body, design: .monospaced))
                .foregroundColor(.white)

            if !purchaseManager.isPro {
                Text("/ \(formatDuration(appState.freeRecordingLimit))")
                    .font(isIPad ? .body : .caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.vertical, isIPad ? 12 : 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(isIPad ? 28 : 20)
        .padding(.top, isIPad ? 80 : 60)
    }

    // MARK: - Recording Controls View (for live adjustment during recording)
    private var recordingControlsView: some View {
        VStack(spacing: isIPad ? 16 : 12) {
            // Zoom Slider
            RecordingSliderRow(
                icon: "plus.magnifyingglass",
                label: String(format: "%.1fx", currentCameraSettings.zoom),
                value: Binding(
                    get: { currentCameraSettings.zoom },
                    set: { newValue in
                        currentCameraSettings.zoom = newValue
                        cameraManager.setZoom(newValue, for: appState.mainCameraIsBack ? .back : .front)
                    }
                ),
                range: currentCameraSettings.minZoom...currentCameraSettings.maxZoom,
                isIPad: isIPad
            )

            // Mosaic controls (only if mosaic is enabled)
            if currentCameraSettings.mosaicEnabled {
                // Mosaic Intensity
                RecordingSliderRow(
                    icon: "square.grid.3x3",
                    label: languageManager.L("size"),
                    value: Binding(
                        get: { currentCameraSettings.mosaicIntensity },
                        set: { newValue in
                            currentCameraSettings.mosaicIntensity = newValue
                            if appState.mainCameraIsBack {
                                cameraManager.backMosaicIntensity = newValue
                            } else {
                                cameraManager.frontMosaicIntensity = newValue
                            }
                        }
                    ),
                    range: currentCameraSettings.minMosaicIntensity...currentCameraSettings.maxMosaicIntensity,
                    isIPad: isIPad
                )

                // Mosaic Coverage
                RecordingSliderRow(
                    icon: "face.smiling",
                    label: languageManager.L("range"),
                    value: Binding(
                        get: { currentCameraSettings.mosaicCoverage },
                        set: { newValue in
                            currentCameraSettings.mosaicCoverage = newValue
                            if appState.mainCameraIsBack {
                                cameraManager.backMosaicCoverage = newValue
                            } else {
                                cameraManager.frontMosaicCoverage = newValue
                            }
                        }
                    ),
                    range: currentCameraSettings.minMosaicCoverage...currentCameraSettings.maxMosaicCoverage,
                    isIPad: isIPad
                )
            }
        }
        .padding(.horizontal, isIPad ? 32 : 24)
        .padding(.vertical, isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(Color.black.opacity(0.5))
        )
        .padding(.horizontal, isIPad ? 40 : 20)
        .padding(.bottom, isIPad ? 30 : 20)
    }

    // MARK: - Current Camera Settings
    private var currentCameraSettings: CameraSettings {
        appState.mainCameraIsBack ? appState.backCamera : appState.frontCamera
    }

    // MARK: - Control Panel Overlay (Removed)

    // MARK: - Top Bar
    private var topBar: some View {
        VStack {
            HStack {
                // Pro Badge (Left)
                if purchaseManager.isPro {
                    Text("PRO")
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(8)
                } else {
                    Button(action: { showPurchaseSheet = true }) {
                        Text("PRO")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }

                Spacer()

                // Toggle UI Visibility (Eye icon like in games/apps)
                /*Button(action: { withAnimation { showControls.toggle() } }) {
                    Image(systemName: showControls ? "eye" : "eye.slash")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }*/
            }
            .padding(.horizontal, 20)
            .padding(.top, isLandscape ? 16 : 60)

            Spacer()
        }
    }

    // MARK: - Deprecated Views Removed (BottomBar, ControlPanelOverlay)

    // MARK: - Ad Required Overlay
    private var adRequiredOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text(languageManager.L("ad_required"))
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Button(action: watchAd) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(languageManager.L("watch_ad"))
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(30)
                }
                .disabled(!adManager.isAdLoaded && !adManager.canSkipAd)

                // 広告読み込み状態の表示
                if !adManager.isAdLoaded {
                    if adManager.isLoading {
                        // 読み込み中
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text(languageManager.L("ad_loading"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if adManager.canSkipAd {
                        // 読み込み失敗 - スキップ可能
                        VStack(spacing: 8) {
                            Text(adManager.adError ?? languageManager.L("ad_load_failed"))
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Button(action: {
                                    adManager.resetAndRetry()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text(languageManager.L("retry"))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.5))
                                    .cornerRadius(15)
                                }

                                Button(action: {
                                    adManager.skipAd {
                                        appState.onAdWatched()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "forward.fill")
                                        Text(languageManager.L("skip"))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(15)
                                }
                            }
                        }
                    } else if let error = adManager.adError {
                        // エラー表示（リトライ中）
                        VStack(spacing: 4) {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(languageManager.L("retrying"))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Button(action: { showPurchaseSheet = true }) {
                    Text("\(languageManager.L("pro_no_ads")) \(purchaseManager.proPriceString)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Camera Error Overlay
    private var cameraErrorOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text(languageManager.L("camera_unavailable"))
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(cameraManager.interruptionReason)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text(languageManager.L("camera_in_use_message"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Setup Camera
    private func setupCamera() {
        cameraManager.setupSession()
        cameraManager.startSession()
        syncCameraSettings()
    }

    // MARK: - Sync Camera Settings
    private func syncCameraSettings() {
        cameraManager.frontMosaicEnabled = appState.frontCamera.mosaicEnabled
        cameraManager.backMosaicEnabled = appState.backCamera.mosaicEnabled
    }

    // MARK: - Toggle Recording
    private func toggleRecording() {
        if appState.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Start Recording
    private func startRecording() {
        // 録画開始音を再生
        SoundManager.shared.playRecordingStartSound()

        appState.isRecording = true
        appState.recordingDuration = 0

        // Pass PiP settings to camera manager for recording
        cameraManager.recordingMainIsBack = appState.mainCameraIsBack
        cameraManager.recordingPiPEnabled = shouldShowPiP
        cameraManager.recordingPiPShape = appState.pipSettings.shape
        cameraManager.recordingPiPPosition = appState.pipSettings.position
        cameraManager.recordingPiPSize = appState.pipSettings.size
        cameraManager.recordingScreenSize = UIScreen.main.bounds.size

        let maxDuration = purchaseManager.isPro ? nil : appState.freeRecordingLimit
        cameraManager.startRecording(maxDuration: maxDuration, isPro: purchaseManager.isPro)

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            appState.recordingDuration += 0.1

            // Auto-stop for free version
            if !purchaseManager.isPro && appState.recordingDuration >= appState.freeRecordingLimit {
                stopRecording()
            }
        }
    }

    // MARK: - Stop Recording
    private func stopRecording() {
        // 録画終了音を再生
        SoundManager.shared.playRecordingStopSound()

        recordingTimer?.invalidate()
        recordingTimer = nil

        cameraManager.stopRecording { url in
            appState.isRecording = false

            if let url = url {
                saveVideoToPhotos(url: url)
            }

            // Set ad required for free version
            appState.onRecordingFinished()
        }
    }

    // MARK: - Save Video to Photos
    private func saveVideoToPhotos(url: URL) {
        print("Saving video to photos: \(url)")

        // ファイルが存在するか確認
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Error: Video file does not exist at \(url.path)")
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            print("Photo library authorization status: \(status.rawValue)")

            guard status == .authorized || status == .limited else {
                print("Photo library access not granted")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Video saved successfully")
                        saveMessage = "video"
                        showSaveSuccess = true
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: url)
                    } else if let error = error {
                        print("Failed to save video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Watch Ad
    private func watchAd() {
        guard let rootVC = adManager.getRootViewController() else { return }

        adManager.showRewardedAd(from: rootVC) {
            appState.onAdWatched()
        }
    }

    // MARK: - Handle Capture Action
    private func handleCaptureAction() {
        if appState.captureMode == .video {
            toggleRecording()
        } else {
            capturePhoto()
        }
    }

    // MARK: - Capture Photo
    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true

        // シャッター音を再生（日本のリジェクト対策）
        SoundManager.shared.playShutterSound()

        // Get main and PiP images
        let mainImage: UIImage?
        let pipImageForCapture: UIImage?

        if appState.mainCameraIsBack {
            if appState.backCamera.mode == .on {
                mainImage = cameraManager.backCameraImage
            } else if appState.backCamera.mode == .staticImage {
                mainImage = appState.backCamera.staticImage
            } else {
                mainImage = nil
            }

            if appState.frontCamera.mode == .on {
                pipImageForCapture = cameraManager.frontCameraImage
            } else if appState.frontCamera.mode == .staticImage {
                pipImageForCapture = appState.frontCamera.staticImage
            } else {
                pipImageForCapture = nil
            }
        } else {
            if appState.frontCamera.mode == .on {
                mainImage = cameraManager.frontCameraImage
            } else if appState.frontCamera.mode == .staticImage {
                mainImage = appState.frontCamera.staticImage
            } else {
                mainImage = nil
            }

            if appState.backCamera.mode == .on {
                pipImageForCapture = cameraManager.backCameraImage
            } else if appState.backCamera.mode == .staticImage {
                pipImageForCapture = appState.backCamera.staticImage
            } else {
                pipImageForCapture = nil
            }
        }

        // Get screen size
        let screenSize = UIScreen.main.bounds.size

        cameraManager.captureCombinedPhoto(
            mainImage: mainImage,
            pipImage: shouldShowPiP ? pipImageForCapture : nil,
            pipSettings: appState.pipSettings,
            screenSize: screenSize,
            isPro: purchaseManager.isPro
        ) { combinedImage in
            if let image = combinedImage {
                savePhotoToPhotos(image: image)
            }
            // Animation feedback
            withAnimation(.easeInOut(duration: 0.1)) {
                isCapturing = false
            }
        }
    }

    // MARK: - Save Photo to Photos
    private func savePhotoToPhotos(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async { [self] in
                    if success {
                        saveMessage = "photo"
                        showSaveSuccess = true
                        // 19%の確率で広告を表示
                        appState.onPhotoTaken()
                    }
                }
            }
        }
    }

    // MARK: - Open Gallery
    private func openGallery() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Format Duration
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Slider Row Component
struct RecordingSliderRow: View {
    let icon: String
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            Image(systemName: icon)
                .font(isIPad ? .title3 : .body)
                .foregroundColor(.white)
                .frame(width: isIPad ? 32 : 24)

            Text(label)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.white)
                .frame(width: isIPad ? 70 : 50, alignment: .leading)

            Slider(value: $value, in: range)
                .accentColor(.green)
        }
    }
}
