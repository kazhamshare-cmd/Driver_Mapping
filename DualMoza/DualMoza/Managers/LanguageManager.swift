import Foundation
import SwiftUI

// Supported languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case japanese = "ja"
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            // Use device language for "System" display
            let deviceLang = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "ja"
            switch deviceLang {
            case "en": return "System Default"
            case "zh": return "跟随系统"
            default: return "システム設定に従う"
            }
        case .japanese: return "日本語"
        case .english: return "English"
        case .chinese: return "中文（简体）"
        }
    }
}

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            applyLanguage()
        }
    }

    private var effectiveLanguage: String = "ja"

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
        applyLanguage()
    }

    private func applyLanguage() {
        if currentLanguage == .system {
            effectiveLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "ja"
        } else {
            effectiveLanguage = currentLanguage.rawValue
        }
        objectWillChange.send()
    }

    func L(_ key: String) -> String {
        return translations[effectiveLanguage]?[key] ?? translations["ja"]?[key] ?? key
    }

    // MARK: - Translations Dictionary
    private let translations: [String: [String: String]] = [
        "ja": [
            // Settings
            "settings": "設定",
            "done": "完了",
            "account": "アカウント",
            "plan": "プラン",
            "pro": "PRO",
            "free": "無料版",
            "video_settings": "動画設定",
            "quality": "画質",
            "auto_save": "フォトライブラリに自動保存",
            "language_settings": "言語設定",
            "language": "言語",
            "language_note": "言語を変更した場合、一部の表示に反映されるにはアプリの再起動が必要な場合があります",
            "camera_adjustment": "カメラ調整",
            "camera_detailed_settings": "カメラ詳細設定 (ズーム/露出/モザイク)",
            "about": "アプリについて",
            "version": "バージョン",
            "privacy_policy": "プライバシーポリシー",
            "terms": "利用規約",
            "support": "サポート",
            "tips": "使い方のヒント",
            "tip_drag": "PiPはドラッグで移動できます",
            "tip_pinch": "PiPはピンチで拡大縮小できます",
            "tip_mosaic": "モザイクは顔を自動検出します",
            "language_changed": "言語を変更しました",
            "language_changed_msg": "一部の表示は次回アプリ起動時に反映されます",
            // Camera Settings
            "back_camera": "アウトカメラ",
            "front_camera": "インカメラ",
            "mode": "モード",
            "zoom": "ズーム",
            "exposure": "露出 (EV)",
            "mosaic": "モザイク",
            "privacy_filter": "プライバシーフィルター",
            "filter_type": "フィルタータイプ",
            "filter_intensity": "フィルター強度",
            "mosaic_intensity": "モザイク荒さ",
            "mosaic_coverage": "モザイク範囲",
            "filter_coverage": "フィルター範囲",
            "mosaic_coverage_note": "顔検出範囲を拡張します（おでこ・顎髭対応）",
            "filter_coverage_note": "顔検出範囲を拡張します（おでこ・顎髭対応）",
            "detection_mode": "検出モード",
            "face_only": "顔のみ",
            "person_detection": "人物検出",
            "person_detection_note": "横顔・後ろ姿も検出します（iOS 17以降）",
            "fine": "細",
            "coarse": "荒",
            "eyes_only": "目のみ",
            "full": "全体",
            "standard": "標準",
            "wide": "広範囲",
            "select_photo": "写真を選択",
            "change_photo": "写真を変更",
            // Capture
            "video": "動画",
            "photo": "写真",
            "save_success": "保存完了",
            "photo_saved": "写真をフォトライブラリに保存しました",
            "video_saved": "動画をフォトライブラリに保存しました",
            // Ad
            "watch_ad": "広告を見る",
            "ad_required": "次の撮影を行うには\n動画広告をご覧ください",
            "ad_loading": "広告を読み込み中...",
            "pro_no_ads": "PRO版で広告なし",
            // Recording
            "size": "サイズ",
            "range": "範囲",
            // Update
            "update_required": "アップデートが必要です",
            "update_message": "新しいバージョンが利用可能です。\n最新版にアップデートしてください。",
            "current_version": "現在のバージョン",
            "latest_version": "最新バージョン",
            "update_now": "アップデートする",
            // ControlPanel
            "shape": "形状",
            "display": "表示",
            "auto_detect_face": "顔を自動検出",
            "intensity": "荒さ",
            "eyes": "目",
            "all": "全",
            "wide_short": "広",
            // Sidebar
            "switch_camera": "切替",
            "pip": "ワイプ",
            "circle": "丸",
            "rectangle": "四角",
            "camera": "カメラ",
            // Purchase
            "unlock_all_features": "すべての機能を解放",
            "no_ads": "広告なし",
            "unlimited_recording": "録画時間無制限",
            "no_watermark": "ウォーターマークなし",
            "one_time_purchase": "買い切り・一度の支払いで永久に使える",
            "purchase_pro": "PRO版を購入",
            "restore_purchase": "購入を復元",
            "close": "閉じる",
            "error": "エラー",
            "feature_comparison": "機能比較",
            "feature": "機能",
            "dual_camera": "両カメラ撮影",
            "auto_mosaic": "自動モザイク",
            "pip_display": "PiP表示",
            "recording_time": "録画時間",
            "ads": "広告",
            "watermark": "ウォーターマーク",
            "thirty_seconds": "30秒",
            "unlimited": "無制限",
            "yes": "あり",
            "no": "なし",
            "no_purchase_to_restore": "復元できる購入が見つかりませんでした",
            // ContentView
            "ad_load_failed": "広告の読み込みに失敗しました",
            "retry": "再試行",
            "skip": "スキップ",
            "retrying": "再試行中...",
            "camera_unavailable": "カメラが使用できません",
            "camera_in_use_message": "他のアプリでカメラを終了してから\nDualMozaを再度開いてください",
            // Legal
            "privacy_policy_title": "プライバシーポリシー",
            "terms_title": "利用規約",
            "last_updated": "最終更新日",
        ],
        "en": [
            // Settings
            "settings": "Settings",
            "done": "Done",
            "account": "Account",
            "plan": "Plan",
            "pro": "PRO",
            "free": "Free",
            "video_settings": "Video Settings",
            "quality": "Quality",
            "auto_save": "Auto-save to Photo Library",
            "language_settings": "Language",
            "language": "Language",
            "language_note": "Some changes may require restarting the app to take effect",
            "camera_adjustment": "Camera",
            "camera_detailed_settings": "Camera Settings (Zoom/Exposure/Mosaic)",
            "about": "About",
            "version": "Version",
            "privacy_policy": "Privacy Policy",
            "terms": "Terms of Service",
            "support": "Support",
            "tips": "Tips",
            "tip_drag": "Drag to move PiP",
            "tip_pinch": "Pinch to resize PiP",
            "tip_mosaic": "Mosaic auto-detects faces",
            "language_changed": "Language Changed",
            "language_changed_msg": "Some changes will take effect after restarting the app",
            // Camera Settings
            "back_camera": "Back Camera",
            "front_camera": "Front Camera",
            "mode": "Mode",
            "zoom": "Zoom",
            "exposure": "Exposure (EV)",
            "mosaic": "Mosaic",
            "privacy_filter": "Privacy Filter",
            "filter_type": "Filter Type",
            "filter_intensity": "Filter Intensity",
            "mosaic_intensity": "Mosaic Intensity",
            "mosaic_coverage": "Mosaic Coverage",
            "filter_coverage": "Filter Coverage",
            "mosaic_coverage_note": "Expand face detection area (forehead/beard)",
            "filter_coverage_note": "Expand face detection area (forehead/beard)",
            "detection_mode": "Detection Mode",
            "face_only": "Face Only",
            "person_detection": "Person",
            "person_detection_note": "Detects side profiles and back views (iOS 17+)",
            "fine": "Fine",
            "coarse": "Coarse",
            "eyes_only": "Eyes",
            "full": "Full",
            "standard": "Standard",
            "wide": "Wide",
            "select_photo": "Select Photo",
            "change_photo": "Change Photo",
            // Capture
            "video": "Video",
            "photo": "Photo",
            "save_success": "Saved",
            "photo_saved": "Photo saved to library",
            "video_saved": "Video saved to library",
            // Ad
            "watch_ad": "Watch Ad",
            "ad_required": "Watch an ad to\ncontinue recording",
            "ad_loading": "Loading ad...",
            "pro_no_ads": "Go PRO - No Ads",
            // Recording
            "size": "Size",
            "range": "Range",
            // Update
            "update_required": "Update Required",
            "update_message": "A new version is available.\nPlease update to continue.",
            "current_version": "Current",
            "latest_version": "Latest",
            "update_now": "Update Now",
            // ControlPanel
            "shape": "Shape",
            "display": "Display",
            "auto_detect_face": "Auto Face Detection",
            "intensity": "Intensity",
            "eyes": "Eyes",
            "all": "Full",
            "wide_short": "Wide",
            // Sidebar
            "switch_camera": "Switch",
            "pip": "PiP",
            "circle": "Circle",
            "rectangle": "Rect",
            "camera": "Camera",
            // Purchase
            "unlock_all_features": "Unlock All Features",
            "no_ads": "No Ads",
            "unlimited_recording": "Unlimited Recording",
            "no_watermark": "No Watermark",
            "one_time_purchase": "One-time purchase, use forever",
            "purchase_pro": "Purchase PRO",
            "restore_purchase": "Restore Purchase",
            "close": "Close",
            "error": "Error",
            "feature_comparison": "Feature Comparison",
            "feature": "Feature",
            "dual_camera": "Dual Camera",
            "auto_mosaic": "Auto Mosaic",
            "pip_display": "PiP Display",
            "recording_time": "Recording Time",
            "ads": "Ads",
            "watermark": "Watermark",
            "thirty_seconds": "30s",
            "unlimited": "Unlimited",
            "yes": "Yes",
            "no": "No",
            "no_purchase_to_restore": "No purchase to restore",
            // ContentView
            "ad_load_failed": "Failed to load ad",
            "retry": "Retry",
            "skip": "Skip",
            "retrying": "Retrying...",
            "camera_unavailable": "Camera unavailable",
            "camera_in_use_message": "Please close camera in other apps\nand reopen DualMoza",
            // Legal
            "privacy_policy_title": "Privacy Policy",
            "terms_title": "Terms of Service",
            "last_updated": "Last updated",
        ],
        "zh-Hans": [
            // Settings
            "settings": "设置",
            "done": "完成",
            "account": "账户",
            "plan": "套餐",
            "pro": "PRO",
            "free": "免费版",
            "video_settings": "视频设置",
            "quality": "画质",
            "auto_save": "自动保存到相册",
            "language_settings": "语言设置",
            "language": "语言",
            "language_note": "更改语言后，部分内容可能需要重启应用才能生效",
            "camera_adjustment": "相机调整",
            "camera_detailed_settings": "相机详细设置（缩放/曝光/马赛克）",
            "about": "关于",
            "version": "版本",
            "privacy_policy": "隐私政策",
            "terms": "使用条款",
            "support": "支持",
            "tips": "使用技巧",
            "tip_drag": "拖动可移动画中画",
            "tip_pinch": "捏合可调整画中画大小",
            "tip_mosaic": "马赛克自动检测人脸",
            "language_changed": "语言已更改",
            "language_changed_msg": "部分内容将在下次启动时生效",
            // Camera Settings
            "back_camera": "后置摄像头",
            "front_camera": "前置摄像头",
            "mode": "模式",
            "zoom": "缩放",
            "exposure": "曝光 (EV)",
            "mosaic": "马赛克",
            "privacy_filter": "隐私滤镜",
            "filter_type": "滤镜类型",
            "filter_intensity": "滤镜强度",
            "mosaic_intensity": "马赛克强度",
            "mosaic_coverage": "马赛克范围",
            "filter_coverage": "滤镜范围",
            "mosaic_coverage_note": "扩展人脸检测区域（额头/胡须）",
            "filter_coverage_note": "扩展人脸检测区域（额头/胡须）",
            "detection_mode": "检测模式",
            "face_only": "仅人脸",
            "person_detection": "人物检测",
            "person_detection_note": "可检测侧脸和背影（iOS 17+）",
            "fine": "细",
            "coarse": "粗",
            "eyes_only": "仅眼睛",
            "full": "全部",
            "standard": "标准",
            "wide": "广域",
            "select_photo": "选择照片",
            "change_photo": "更换照片",
            // Capture
            "video": "视频",
            "photo": "照片",
            "save_success": "保存成功",
            "photo_saved": "照片已保存到相册",
            "video_saved": "视频已保存到相册",
            // Ad
            "watch_ad": "观看广告",
            "ad_required": "观看广告后\n继续录制",
            "ad_loading": "广告加载中...",
            "pro_no_ads": "升级PRO版 无广告",
            // Recording
            "size": "大小",
            "range": "范围",
            // Update
            "update_required": "需要更新",
            "update_message": "有新版本可用。\n请更新后继续使用。",
            "current_version": "当前版本",
            "latest_version": "最新版本",
            "update_now": "立即更新",
            // ControlPanel
            "shape": "形状",
            "display": "显示",
            "auto_detect_face": "自动人脸检测",
            "intensity": "强度",
            "eyes": "眼睛",
            "all": "全部",
            "wide_short": "广",
            // Sidebar
            "switch_camera": "切换",
            "pip": "画中画",
            "circle": "圆形",
            "rectangle": "方形",
            "camera": "相机",
            // Purchase
            "unlock_all_features": "解锁所有功能",
            "no_ads": "无广告",
            "unlimited_recording": "无限录制时间",
            "no_watermark": "无水印",
            "one_time_purchase": "一次购买，永久使用",
            "purchase_pro": "购买PRO版",
            "restore_purchase": "恢复购买",
            "close": "关闭",
            "error": "错误",
            "feature_comparison": "功能对比",
            "feature": "功能",
            "dual_camera": "双摄像头",
            "auto_mosaic": "自动马赛克",
            "pip_display": "画中画显示",
            "recording_time": "录制时间",
            "ads": "广告",
            "watermark": "水印",
            "thirty_seconds": "30秒",
            "unlimited": "无限",
            "yes": "有",
            "no": "无",
            "no_purchase_to_restore": "没有可恢复的购买",
            // ContentView
            "ad_load_failed": "广告加载失败",
            "retry": "重试",
            "skip": "跳过",
            "retrying": "重试中...",
            "camera_unavailable": "相机不可用",
            "camera_in_use_message": "请关闭其他应用的相机\n然后重新打开DualMoza",
            // Legal
            "privacy_policy_title": "隐私政策",
            "terms_title": "服务条款",
            "last_updated": "最后更新",
        ]
    ]
}
