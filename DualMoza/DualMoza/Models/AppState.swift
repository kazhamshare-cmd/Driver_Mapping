import SwiftUI
import Combine

// MARK: - Camera Mode
enum CameraMode: String, CaseIterable {
    case on = "ON"
    case off = "OFF"
    case staticImage = "静止画"
}

// MARK: - PiP Shape
enum PiPShape: String, CaseIterable {
    case circle = "丸"
    case rectangle = "四角"
}

// MARK: - Capture Mode
enum CaptureMode: String, CaseIterable {
    case video = "動画"
    case photo = "写真"
}

// MARK: - Privacy Filter Type
enum PrivacyFilterType: String, CaseIterable {
    case mosaic = "モザイク"
    case blur = "ぼかし"
}

// MARK: - Detection Mode
enum DetectionMode: String, CaseIterable {
    case faceOnly = "faceOnly"
    case personDetection = "personDetection"
}

// MARK: - Camera Settings
@MainActor
class CameraSettings: ObservableObject {
    @Published var mode: CameraMode = .on
    @Published var zoom: CGFloat = 1.0
    @Published var exposureValue: Float = 0.0
    @Published var mosaicEnabled: Bool = false
    @Published var privacyFilterType: PrivacyFilterType = .mosaic  // フィルタータイプ（モザイク/ぼかし）
    @Published var detectionMode: DetectionMode = .faceOnly  // 検出モード（顔のみ/人物検出）
    @Published var mosaicIntensity: CGFloat = 20.0  // モザイクの荒さ / ぼかしの強さ（大きいほど強い）
    @Published var mosaicCoverage: CGFloat = 0.5    // フィルター範囲（0=目だけ、0.5=標準、1.0=おでこ〜顎髭まで）
    @Published var staticImage: UIImage? = nil

    let minZoom: CGFloat = 1.0
    let maxZoom: CGFloat = 5.0
    let minEV: Float = -2.0
    let maxEV: Float = 2.0
    let minMosaicIntensity: CGFloat = 5.0    // 細かいモザイク
    let maxMosaicIntensity: CGFloat = 100.0  // 荒いモザイク（増加）
    let minMosaicCoverage: CGFloat = 0.0     // 最小範囲（目だけ）
    let maxMosaicCoverage: CGFloat = 1.0     // 最大範囲（おでこ〜顎髭）
}

// MARK: - PiP Settings
@MainActor
class PiPSettings: ObservableObject {
    @Published var shape: PiPShape = .rectangle
    @Published var position: CGPoint
    @Published var size: CGFloat

    let minSize: CGFloat
    let maxSize: CGFloat

    init() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let screenSize = UIScreen.main.bounds.size

        // iPad用に大きめのサイズと位置を設定
        if isIPad {
            self.size = 200
            self.minSize = 120
            self.maxSize = 400
            self.position = CGPoint(x: 150, y: 200)
        } else {
            self.size = 120
            self.minSize = 80
            self.maxSize = 200
            // 左寄りに配置（メニューと重ならないように）
            self.position = CGPoint(x: 80, y: 180)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    // Camera settings
    @Published var frontCamera = CameraSettings()
    @Published var backCamera = CameraSettings()

    // PiP settings
    @Published var pipSettings = PiPSettings()

    // Which camera is main (full screen)
    @Published var mainCameraIsBack: Bool = true

    // Capture mode (video or photo)
    @Published var captureMode: CaptureMode = .video

    // Recording state
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0

    // Ad state - 広告視聴完了状態をUserDefaultsで永続化
    @Published var needsToWatchAd: Bool {
        didSet {
            UserDefaults.standard.set(needsToWatchAd, forKey: "needsToWatchAd")
        }
    }

    // Recording limit for free version (30 seconds)
    let freeRecordingLimit: TimeInterval = 30.0

    init() {
        // 初回起動かどうかをチェック
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            // 初回起動時は広告不要（まだ録画していないため）
            self.needsToWatchAd = false
            UserDefaults.standard.set(false, forKey: "needsToWatchAd")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        } else {
            // 2回目以降は状態を復元
            self.needsToWatchAd = UserDefaults.standard.bool(forKey: "needsToWatchAd")
        }
    }

    // デバッグ用：広告状態をリセット
    func resetAdState() {
        needsToWatchAd = false
    }

    // 録画終了時に呼ばれる
    func onRecordingFinished() {
        // 無料版の場合、広告視聴が必要な状態にする
        if !PurchaseManager.shared.isPro {
            needsToWatchAd = true
        }
    }

    // 写真撮影時に呼ばれる（19%の確率で広告表示）
    func onPhotoTaken() {
        // Pro版は広告不要
        guard !PurchaseManager.shared.isPro else { return }

        // 19%の確率で広告を表示
        let randomValue = Int.random(in: 1...100)
        if randomValue <= 19 {
            needsToWatchAd = true
            print("Photo ad triggered (random: \(randomValue)/100)")
        } else {
            print("Photo ad skipped (random: \(randomValue)/100)")
        }
    }

    // 広告視聴完了時に呼ばれる
    func onAdWatched() {
        needsToWatchAd = false
    }

    // 撮影可能かどうか
    var canStartRecording: Bool {
        return PurchaseManager.shared.isPro || !needsToWatchAd
    }
}
