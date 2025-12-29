import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// Localization keys for easy access
struct L10n {
    // App Name
    static let appName = "app_name".localized

    // Main Screen
    static let recording = "recording".localized
    static let record = "record".localized
    static let stop = "stop".localized
    static let settings = "settings".localized
    static let gallery = "gallery".localized

    // Camera Controls
    static let pipSettings = "pip_settings".localized
    static let shape = "shape".localized
    static let size = "size".localized
    static let backCamera = "back_camera".localized
    static let frontCamera = "front_camera".localized
    static let display = "display".localized
    static let zoom = "zoom".localized
    static let ev = "ev".localized
    static let mosaic = "mosaic".localized
    static let autoFaceDetection = "auto_face_detection".localized
    static let roughness = "roughness".localized
    static let fine = "fine".localized
    static let coarse = "coarse".localized

    // Camera Modes
    static let modeOn = "mode_on".localized
    static let modeOff = "mode_off".localized
    static let modeStatic = "mode_static".localized

    // PiP Shapes
    static let shapeCircle = "shape_circle".localized
    static let shapeRectangle = "shape_rectangle".localized

    // Settings
    static let account = "account".localized
    static let plan = "plan".localized
    static let pro = "pro".localized
    static let free = "free".localized
    static let videoSettings = "video_settings".localized
    static let quality = "quality".localized
    static let autoSaveToPhotos = "auto_save_to_photos".localized
    static let about = "about".localized
    static let version = "version".localized
    static let privacyPolicy = "privacy_policy".localized
    static let termsOfService = "terms_of_service".localized
    static let support = "support".localized
    static let tips = "tips".localized
    static let tipDragPip = "tip_drag_pip".localized
    static let tipPinchPip = "tip_pinch_pip".localized
    static let tipMosaic = "tip_mosaic".localized
    static let done = "done".localized
    static let close = "close".localized

    // Purchase
    static let dualMozaPro = "dualmoza_pro".localized
    static let unlockAllFeatures = "unlock_all_features".localized
    static let noAds = "no_ads".localized
    static let unlimitedRecording = "unlimited_recording".localized
    static let noWatermark = "no_watermark".localized
    static let highQualityExport = "high_quality_export".localized
    static let oneTimePurchase = "one_time_purchase".localized
    static let purchasePro = "purchase_pro".localized
    static let restorePurchase = "restore_purchase".localized
    static let featureComparison = "feature_comparison".localized
    static let feature = "feature".localized
    static let dualCamera = "dual_camera".localized
    static let autoMosaic = "auto_mosaic".localized
    static let pipDisplay = "pip_display".localized
    static let recordingTime = "recording_time".localized
    static let thirtySeconds = "30_seconds".localized
    static let unlimited = "unlimited".localized
    static let ads = "ads".localized
    static let yes = "yes".localized
    static let no = "no".localized
    static let watermark = "watermark".localized
    static let error = "error".localized
    static let ok = "ok".localized
    static let noPurchaseFound = "no_purchase_found".localized

    // Ad Screen
    static let watchAdToContinue = "watch_ad_to_continue".localized
    static let watchAd = "watch_ad".localized
    static let adLoading = "ad_loading".localized
    static let getProNoAds = "get_pro_no_ads".localized
    static let skip = "skip".localized
}
