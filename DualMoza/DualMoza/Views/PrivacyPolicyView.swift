import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lang = LanguageManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections, id: \.title) { section in
                        sectionView(title: section.title, content: section.content)
                    }

                    Text(lastUpdatedText)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
                .padding(20)
            }
            .navigationTitle(lang.L("privacy_policy_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.L("close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sections: [(title: String, content: String)] {
        let effectiveLanguage = getEffectiveLanguage()

        switch effectiveLanguage {
        case "en":
            return englishSections
        case "zh-Hans":
            return chineseSections
        default:
            return japaneseSections
        }
    }

    private var lastUpdatedText: String {
        let effectiveLanguage = getEffectiveLanguage()
        switch effectiveLanguage {
        case "en":
            return "Last updated: December 23, 2024"
        case "zh-Hans":
            return "最后更新：2024年12月23日"
        default:
            return "最終更新日: 2024年12月23日"
        }
    }

    private func getEffectiveLanguage() -> String {
        if lang.currentLanguage == .system {
            return Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "ja"
        }
        return lang.currentLanguage.rawValue
    }

    // MARK: - Japanese Content
    private var japaneseSections: [(title: String, content: String)] {
        [
            ("1. 個人情報の収集について", """
            当社は、本サービスの提供にあたり、以下の情報を収集・利用いたします。

            • カメラ映像（録画機能のため）
            • マイク音声（録画機能のため）
            • デバイス情報（サービス最適化のため）
            • 利用統計情報（サービス改善のため）
            • 購入情報（Pro版購入の管理のため）
            """),
            ("2. 個人情報の利用目的", """
            収集した情報は、以下の目的で利用いたします。

            • 本サービスの提供・運営
            • 動画録画機能の提供
            • 顔検出・モザイク処理の実行
            • ユーザーサポート
            • サービスの改善・開発
            • 広告の表示（無料版のみ）
            """),
            ("3. 個人情報の第三者提供", """
            当社は、以下の場合を除き、個人情報を第三者に提供いたしません。

            • ご本人の同意がある場合
            • 法令に基づく場合
            • 人の生命、身体または財産の保護のために必要な場合
            • 公衆衛生の向上または児童の健全な育成の推進のために特に必要な場合
            """),
            ("4. 録画データの取り扱い", """
            本アプリで録画された動画データは、お使いのデバイスのローカルストレージまたはフォトライブラリにのみ保存されます。当社のサーバーにアップロードされることはありません。

            顔検出・モザイク処理はすべてデバイス上で行われ、処理データが外部に送信されることはありません。
            """),
            ("5. 広告について", """
            無料版では、Google AdMobによる広告が表示されます。AdMobは広告配信の最適化のため、デバイス情報や利用状況を収集することがあります。

            Pro版をご購入いただくと、広告は表示されなくなります。
            """),
            ("6. 個人情報の安全管理", """
            当社は、個人情報の漏洩、滅失またはき損の防止その他の個人情報の安全管理のために必要かつ適切な措置を講じます。
            """),
            ("7. お問い合わせ先", """
            個人情報の取り扱いに関するお問い合わせは、以下までお願いいたします。

            株式会社ビーク
            北海道札幌市中央区南1条西14丁目1-230
            フォー＝ライフ大通り南1101
            メール: kazham.share@gmail.com
            サポートURL: https://b19.co.jp/support
            """)
        ]
    }

    // MARK: - English Content
    private var englishSections: [(title: String, content: String)] {
        [
            ("1. Information We Collect", """
            We collect and use the following information to provide our services:

            • Camera footage (for recording functionality)
            • Microphone audio (for recording functionality)
            • Device information (for service optimization)
            • Usage statistics (for service improvement)
            • Purchase information (for Pro version management)
            """),
            ("2. How We Use Your Information", """
            We use the collected information for the following purposes:

            • Providing and operating the service
            • Video recording functionality
            • Face detection and mosaic processing
            • User support
            • Service improvement and development
            • Displaying advertisements (free version only)
            """),
            ("3. Third-Party Disclosure", """
            We do not share your personal information with third parties except in the following cases:

            • With your consent
            • When required by law
            • When necessary to protect life, body, or property
            • When specially necessary for public health or child welfare
            """),
            ("4. Recording Data Handling", """
            Video data recorded with this app is stored only on your device's local storage or photo library. It is never uploaded to our servers.

            All face detection and mosaic processing is performed on your device, and no processing data is transmitted externally.
            """),
            ("5. Advertising", """
            The free version displays advertisements through Google AdMob. AdMob may collect device information and usage data to optimize ad delivery.

            Purchasing the Pro version removes all advertisements.
            """),
            ("6. Data Security", """
            We implement necessary and appropriate measures to prevent leakage, loss, or damage of personal information and ensure its secure management.
            """),
            ("7. Contact Us", """
            For inquiries regarding personal information handling, please contact:

            B19 Inc.
            Minami 1-jo Nishi 14-1-230, Chuo-ku
            Sapporo, Hokkaido, Japan
            Email: kazham.share@gmail.com
            Support: https://b19.co.jp/support
            """)
        ]
    }

    // MARK: - Chinese Content
    private var chineseSections: [(title: String, content: String)] {
        [
            ("1. 我们收集的信息", """
            我们收集并使用以下信息来提供服务：

            • 摄像头画面（用于录制功能）
            • 麦克风音频（用于录制功能）
            • 设备信息（用于服务优化）
            • 使用统计信息（用于服务改进）
            • 购买信息（用于Pro版管理）
            """),
            ("2. 信息使用目的", """
            我们将收集的信息用于以下目的：

            • 提供和运营服务
            • 视频录制功能
            • 人脸检测和马赛克处理
            • 用户支持
            • 服务改进和开发
            • 显示广告（仅限免费版）
            """),
            ("3. 向第三方披露", """
            除以下情况外，我们不会向第三方提供个人信息：

            • 经本人同意
            • 根据法律要求
            • 为保护生命、身体或财产所必需
            • 为公共卫生或儿童福利特别需要
            """),
            ("4. 录制数据处理", """
            使用本应用录制的视频数据仅存储在您设备的本地存储或相册中，不会上传到我们的服务器。

            所有人脸检测和马赛克处理都在您的设备上进行，处理数据不会对外传输。
            """),
            ("5. 关于广告", """
            免费版通过Google AdMob显示广告。AdMob可能会收集设备信息和使用数据以优化广告投放。

            购买Pro版后将不再显示广告。
            """),
            ("6. 数据安全", """
            我们采取必要和适当的措施，防止个人信息泄露、丢失或损坏，确保其安全管理。
            """),
            ("7. 联系我们", """
            如有关于个人信息处理的咨询，请联系：

            株式会社ビーク (B19 Inc.)
            日本北海道札幌市中央区南1条西14丁目1-230
            邮箱: kazham.share@gmail.com
            支持: https://b19.co.jp/support
            """)
        ]
    }

    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}
