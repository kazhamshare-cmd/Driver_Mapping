import SwiftUI

struct TermsOfServiceView: View {
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
            .navigationTitle(lang.L("terms_title"))
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
            ("第1条（適用）", """
            本規約は、株式会社ビーク（以下「当社」）が提供する「DualMoza」アプリケーション（以下「本サービス」）の利用条件を定めるものです。
            """),
            ("第2条（利用登録）", """
            1. 本サービスは、ダウンロードすることで利用を開始できます。

            2. 本サービスをダウンロードした時点で、利用者は本規約に同意したものとみなします。
            """),
            ("第3条（利用料金および支払方法）", """
            1. 本サービスは基本機能を無料で提供します。無料版では30秒までの録画制限、ウォーターマーク表示、広告表示があります。

            2. PRO版（¥1,600・買い切り）を購入することで、録画時間無制限、ウォーターマーク非表示、広告非表示の機能をご利用いただけます。

            3. 利用料金の支払いは、App Storeを通じて行われます。

            4. PRO版は一度の購入で永久にご利用いただけます。
            """),
            ("第4条（顔検出・モザイク機能について）", """
            1. 本サービスの顔検出・モザイク機能は、すべての顔を検出することを保証するものではありません。

            2. 照明条件、顔の向き、カメラの品質等により、検出精度が変動する場合があります。

            3. 本機能の利用により、プライバシー侵害等の問題が発生した場合、当社は一切の責任を負いません。利用者自身の責任でご利用ください。
            """),
            ("第5条（禁止事項）", """
            利用者は、本サービスの利用にあたり、以下の行為をしてはなりません。

            • 法令または公序良俗に違反する行為
            • 犯罪行為に関連する行為
            • 他人のプライバシーを侵害する目的での撮影
            • 盗撮その他の違法な撮影行為
            • 当社のサーバーまたはネットワークの機能を破壊したり、妨害したりする行為
            • 本サービスのリバースエンジニアリング、逆コンパイル、逆アセンブル
            • その他、当社が不適切と判断する行為
            """),
            ("第6条（本サービスの提供の停止等）", """
            当社は、以下のいずれかの事由があると判断した場合、利用者に事前に通知することなく本サービスの全部または一部の提供を停止または中断することができるものとします。

            • 本サービスにかかるコンピュータシステムの保守点検または更新を行う場合
            • 地震、落雷、火災、停電または天災などの不可抗力により、本サービスの提供が困難となった場合
            • その他、当社が本サービスの提供が困難と判断した場合
            """),
            ("第7条（免責事項）", """
            1. 当社は、本サービスの顔検出・モザイク機能の精度について、いかなる保証もいたしません。

            2. 本サービスを使用して撮影・録画されたコンテンツに関する責任は、すべて利用者に帰属します。

            3. 当社は、本サービスに関して、利用者と他の利用者または第三者との間において生じた取引、連絡または紛争等について一切責任を負いません。
            """),
            ("第8条（サービス内容の変更等）", """
            当社は、利用者に通知することなく、本サービスの内容を変更しまたは本サービスの提供を中止することができるものとし、これによって利用者に生じた損害について一切の責任を負いません。
            """),
            ("第9条（利用規約の変更）", """
            当社は、必要と判断した場合には、利用者に通知することなくいつでも本規約を変更することができるものとします。
            """),
            ("第10条（準拠法・裁判管轄）", """
            1. 本規約の解釈にあたっては、日本法を準拠法とします。

            2. 本サービスに関して紛争が生じた場合には、札幌地方裁判所を第一審の専属的合意管轄裁判所とします。
            """)
        ]
    }

    // MARK: - English Content
    private var englishSections: [(title: String, content: String)] {
        [
            ("Article 1 (Application)", """
            These Terms govern the use of the "DualMoza" application (the "Service") provided by B19 Inc. (the "Company").
            """),
            ("Article 2 (Registration)", """
            1. You can start using the Service by downloading it.

            2. By downloading the Service, you are deemed to have agreed to these Terms.
            """),
            ("Article 3 (Fees and Payment)", """
            1. The Service provides basic features for free. The free version has a 30-second recording limit, watermark display, and advertisements.

            2. By purchasing the PRO version (one-time purchase), you can enjoy unlimited recording time, no watermark, and no advertisements.

            3. Payment is processed through the App Store.

            4. The PRO version is a one-time purchase for permanent use.
            """),
            ("Article 4 (Face Detection and Mosaic Feature)", """
            1. The face detection and mosaic feature of the Service does not guarantee detection of all faces.

            2. Detection accuracy may vary depending on lighting conditions, face orientation, camera quality, etc.

            3. The Company assumes no responsibility for any privacy issues that may arise from using this feature. Use at your own risk.
            """),
            ("Article 5 (Prohibited Activities)", """
            Users shall not engage in the following activities when using the Service:

            • Activities that violate laws or public order
            • Activities related to criminal acts
            • Recording for the purpose of invading others' privacy
            • Voyeurism or other illegal recording activities
            • Activities that destroy or interfere with the Company's servers or networks
            • Reverse engineering, decompiling, or disassembling the Service
            • Other activities deemed inappropriate by the Company
            """),
            ("Article 6 (Service Suspension)", """
            The Company may suspend or interrupt all or part of the Service without prior notice to users in the following cases:

            • When performing maintenance or updates on the computer system for the Service
            • When provision of the Service becomes difficult due to force majeure such as earthquakes, lightning, fire, power outages, or natural disasters
            • When the Company determines that provision of the Service is difficult
            """),
            ("Article 7 (Disclaimer)", """
            1. The Company makes no warranties regarding the accuracy of the face detection and mosaic feature.

            2. All responsibility for content recorded using the Service lies with the user.

            3. The Company assumes no responsibility for any transactions, communications, or disputes between users or between users and third parties regarding the Service.
            """),
            ("Article 8 (Service Changes)", """
            The Company may change the content of the Service or discontinue its provision without notice to users, and assumes no responsibility for any damages incurred by users as a result.
            """),
            ("Article 9 (Terms Changes)", """
            The Company may change these Terms at any time without notice to users when deemed necessary.
            """),
            ("Article 10 (Governing Law and Jurisdiction)", """
            1. These Terms shall be governed by and construed in accordance with the laws of Japan.

            2. Any disputes arising in connection with the Service shall be subject to the exclusive jurisdiction of the Sapporo District Court as the court of first instance.
            """)
        ]
    }

    // MARK: - Chinese Content
    private var chineseSections: [(title: String, content: String)] {
        [
            ("第1条（适用范围）", """
            本条款规定了株式会社ビーク（以下简称"本公司"）提供的"DualMoza"应用程序（以下简称"本服务"）的使用条件。
            """),
            ("第2条（注册使用）", """
            1. 下载后即可开始使用本服务。

            2. 下载本服务即视为用户同意本条款。
            """),
            ("第3条（费用及支付方式）", """
            1. 本服务免费提供基本功能。免费版有30秒录制限制、水印显示和广告显示。

            2. 购买PRO版（一次性购买）后，可享受无限录制时间、无水印、无广告功能。

            3. 付款通过App Store进行。

            4. PRO版为一次性购买，可永久使用。
            """),
            ("第4条（人脸检测和马赛克功能）", """
            1. 本服务的人脸检测和马赛克功能不保证能检测到所有人脸。

            2. 检测精度可能因光照条件、面部朝向、相机质量等因素而变化。

            3. 因使用此功能而产生的任何隐私问题，本公司不承担任何责任。请自行承担使用风险。
            """),
            ("第5条（禁止事项）", """
            用户在使用本服务时不得进行以下行为：

            • 违反法律法规或公序良俗的行为
            • 与犯罪行为相关的行为
            • 以侵犯他人隐私为目的的拍摄
            • 偷拍或其他非法拍摄行为
            • 破坏或干扰本公司服务器或网络功能的行为
            • 对本服务进行逆向工程、反编译或反汇编
            • 本公司认为不当的其他行为
            """),
            ("第6条（服务中止）", """
            在以下情况下，本公司可在不事先通知用户的情况下中止或中断本服务的全部或部分：

            • 对本服务的计算机系统进行维护或更新时
            • 因地震、雷击、火灾、停电或自然灾害等不可抗力导致难以提供本服务时
            • 本公司判断难以提供本服务时
            """),
            ("第7条（免责声明）", """
            1. 本公司不对人脸检测和马赛克功能的精度作任何保证。

            2. 使用本服务录制的内容的所有责任由用户承担。

            3. 对于本服务相关的用户之间或用户与第三方之间产生的任何交易、通信或纠纷，本公司不承担任何责任。
            """),
            ("第8条（服务内容变更）", """
            本公司可在不通知用户的情况下变更本服务内容或停止提供本服务，对由此给用户造成的任何损失不承担任何责任。
            """),
            ("第9条（条款变更）", """
            本公司认为必要时，可随时在不通知用户的情况下变更本条款。
            """),
            ("第10条（准据法及管辖）", """
            1. 本条款的解释以日本法律为准据法。

            2. 与本服务相关的纠纷，以札幌地方法院为第一审专属管辖法院。
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
