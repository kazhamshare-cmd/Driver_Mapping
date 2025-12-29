import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@MainActor
class AdManager: NSObject, ObservableObject {
    @Published var isAdLoaded: Bool = false
    @Published var isShowingAd: Bool = false
    @Published var isLoading: Bool = false
    @Published var adError: String? = nil
    @Published var canSkipAd: Bool = false  // 広告をスキップできるか
    @Published var attRequested: Bool = false  // ATT許可リクエスト済みかどうか

    private var rewardedAd: RewardedAd?

    // AdMob リワード広告のユニットID
    #if DEBUG
    // テスト用広告ユニットID（開発時はこちらを使用）
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    // 本番用広告ユニットID
    private let rewardedAdUnitID = "ca-app-pub-1116360810482665/7682790069"
    #endif

    // リトライ設定
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private var loadingTimer: Timer?
    private let loadingTimeout: TimeInterval = 15.0  // 15秒タイムアウト

    var onAdCompleted: (() -> Void)?

    override init() {
        super.init()
        configureTestDevices()
        // ATT完了後に広告を読み込むため、ここでは読み込まない
        // loadRewardedAd() は DualMozaApp から ATT 完了後に呼び出される
    }

    // MARK: - Configure Test Devices
    private func configureTestDevices() {
        // テストデバイスを設定（実機でテスト広告を表示するため）
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "0bc84f86f1b36348c8d4c69cc9adb448"  // あなたのデバイス
        ]
    }

    // MARK: - Load Rewarded Ad
    func loadRewardedAd() {
        // 既に読み込み中の場合はスキップ
        guard !isLoading else { return }

        isLoading = true
        adError = nil

        let request = Request()

        print("Loading rewarded ad... (attempt \(retryCount + 1)/\(maxRetries))")

        // タイムアウトタイマーを開始
        startLoadingTimeout()

        RewardedAd.load(with: rewardedAdUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor in
                self?.cancelLoadingTimeout()
                self?.isLoading = false

                if let error = error {
                    self?.handleLoadError(error)
                    return
                }

                // 読み込み成功
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                self?.isAdLoaded = true
                self?.adError = nil
                self?.retryCount = 0
                self?.canSkipAd = false
                print("Rewarded ad loaded successfully")
            }
        }
    }

    // MARK: - Handle Load Error
    private func handleLoadError(_ error: Error) {
        retryCount += 1
        adError = error.localizedDescription
        isAdLoaded = false

        print("Failed to load rewarded ad (attempt \(retryCount)/\(maxRetries)): \(error.localizedDescription)")

        if retryCount >= maxRetries {
            // 最大リトライ回数に達した場合、スキップを許可
            canSkipAd = true
            adError = "広告の読み込みに失敗しました。スキップして続行できます。"
            print("Max retries reached. User can skip ad.")
        } else {
            // 指数バックオフでリトライ（2秒、4秒、8秒...）
            let delay = pow(2.0, Double(retryCount))
            print("Retrying in \(delay) seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.loadRewardedAd()
            }
        }
    }

    // MARK: - Loading Timeout
    private func startLoadingTimeout() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isLoading else { return }
                print("Ad loading timed out")
                self.isLoading = false
                self.handleLoadError(NSError(domain: "AdManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "読み込みがタイムアウトしました"]))
            }
        }
    }

    private func cancelLoadingTimeout() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }

    // MARK: - Show Rewarded Ad
    func showRewardedAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let rewardedAd = rewardedAd else {
            adError = "広告の読み込み中です。しばらくお待ちください。"
            if !isLoading {
                loadRewardedAd()
            }
            return
        }

        isShowingAd = true
        onAdCompleted = completion

        rewardedAd.present(from: viewController) { [weak self] in
            // ユーザーが報酬を獲得した
            print("User earned reward")
            Task { @MainActor in
                self?.onAdCompleted?()
                self?.onAdCompleted = nil
            }
        }
    }

    // MARK: - Skip Ad (読み込み失敗時用)
    func skipAd(completion: @escaping () -> Void) {
        guard canSkipAd else { return }
        print("User skipped ad due to loading failure")
        // リトライカウントをリセットして再読み込み開始
        retryCount = 0
        canSkipAd = false
        loadRewardedAd()
        completion()
    }

    // MARK: - Reset and Retry
    func resetAndRetry() {
        retryCount = 0
        canSkipAd = false
        isLoading = false
        cancelLoadingTimeout()
        loadRewardedAd()
    }

    // MARK: - Get Root View Controller
    func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            isShowingAd = false
            // 次の広告を読み込む
            loadRewardedAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            isShowingAd = false
            adError = error.localizedDescription
            loadRewardedAd()
        }
    }
}
