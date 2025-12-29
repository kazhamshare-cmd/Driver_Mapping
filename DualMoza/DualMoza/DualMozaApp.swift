import SwiftUI
import AppTrackingTransparency

@main
struct DualMozaApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var adManager = AdManager()
    @StateObject private var versionManager = VersionManager.shared
    @State private var hasRequestedATT = false

    var body: some Scene {
        WindowGroup {
            Group {
                if versionManager.needsUpdate {
                    // 強制アップデート画面
                    ForceUpdateView()
                } else {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(purchaseManager)
                        .environmentObject(adManager)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // アプリ起動時にバージョンチェック
                await versionManager.checkForUpdate()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // アプリがアクティブになったらATT許可をリクエスト（一度のみ）
                if !hasRequestedATT {
                    requestTrackingPermission()
                }
            }
        }
    }

    private func requestTrackingPermission() {
        // 既にリクエスト済みの場合はスキップ
        guard !hasRequestedATT else { return }
        hasRequestedATT = true

        // iOS 14以上でATT許可をリクエスト
        if #available(iOS 14, *) {
            // 現在のステータスを確認
            let currentStatus = ATTrackingManager.trackingAuthorizationStatus
            if currentStatus == .notDetermined {
                // 少し遅延させてUIが準備されてからリクエスト
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                    ATTrackingManager.requestTrackingAuthorization { status in
                        switch status {
                        case .authorized:
                            print("ATT: Tracking authorized")
                        case .denied:
                            print("ATT: Tracking denied")
                        case .notDetermined:
                            print("ATT: Tracking not determined")
                        case .restricted:
                            print("ATT: Tracking restricted")
                        @unknown default:
                            print("ATT: Unknown status")
                        }
                        // ATT完了後に広告を読み込み
                        Task { @MainActor in
                            adManager.loadRewardedAd()
                        }
                    }
                }
            } else {
                // 既に許可/拒否済みの場合は広告を読み込み
                print("ATT: Already determined - \(currentStatus.rawValue)")
                Task { @MainActor in
                    adManager.loadRewardedAd()
                }
            }
        } else {
            // iOS 14未満の場合は直接広告を読み込み
            Task { @MainActor in
                adManager.loadRewardedAd()
            }
        }
    }
}
