import Foundation
import SwiftUI

@MainActor
class VersionManager: ObservableObject {
    static let shared = VersionManager()

    @Published var needsUpdate: Bool = false
    @Published var latestVersion: String = ""
    @Published var isChecking: Bool = false

    // App Store ID
    private let appStoreID = "6756903535"

    // Bundle ID
    private let bundleID = "b19.DualMoza"

    private init() {}

    // 現在のアプリバージョンを取得
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // App Storeの最新バージョンをチェック
    func checkForUpdate() async {
        isChecking = true
        defer { isChecking = false }

        // iTunes Search APIでアプリ情報を取得
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=jp"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let storeVersion = firstResult["version"] as? String {

                latestVersion = storeVersion

                // バージョン比較
                if compareVersions(current: currentVersion, store: storeVersion) == .orderedAscending {
                    needsUpdate = true
                }
            }
        } catch {
            print("Version check failed: \(error.localizedDescription)")
            // エラー時はアップデートチェックをスキップ（アプリは使用可能）
        }
    }

    // バージョン比較（セマンティックバージョニング対応）
    private func compareVersions(current: String, store: String) -> ComparisonResult {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let storeParts = store.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(currentParts.count, storeParts.count)

        for i in 0..<maxCount {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let storePart = i < storeParts.count ? storeParts[i] : 0

            if currentPart < storePart {
                return .orderedAscending  // current < store (要アップデート)
            } else if currentPart > storePart {
                return .orderedDescending  // current > store
            }
        }

        return .orderedSame  // 同じバージョン
    }

    // App Storeを開く
    func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Force Update View
struct ForceUpdateView: View {
    @ObservedObject var versionManager = VersionManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Spacer()

                // アイコン
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                // タイトル
                Text(languageManager.L("update_required"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // メッセージ
                VStack(spacing: 8) {
                    Text(languageManager.L("update_message"))
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {
                        VStack {
                            Text(languageManager.L("current_version"))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(versionManager.currentVersion)
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.gray)

                        VStack {
                            Text(languageManager.L("latest_version"))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(versionManager.latestVersion)
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 40)

                Spacer()

                // アップデートボタン
                Button(action: {
                    versionManager.openAppStore()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(languageManager.L("update_now"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}
