import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var appState: AppState
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) var dismiss

    @AppStorage("videoQuality") private var videoQuality = "1080p"
    @AppStorage("saveToPhotos") private var saveToPhotos = true

    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showLanguageRestartAlert = false
    @State private var showPurchaseView = false

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    Button(action: {
                        if !purchaseManager.isPro {
                            showPurchaseView = true
                        }
                    }) {
                        HStack {
                            Text(languageManager.L("plan"))
                                .foregroundColor(.primary)
                            Spacer()
                            if purchaseManager.isPro {
                                Text(languageManager.L("pro"))
                                    .foregroundColor(.yellow)
                                    .fontWeight(.bold)
                            } else {
                                Text(languageManager.L("free"))
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text(languageManager.L("account"))
                }

                // Video Settings
                Section {
                    Picker(languageManager.L("quality"), selection: $videoQuality) {
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                        if purchaseManager.isPro {
                            Text("4K").tag("4K")
                        }
                    }

                    Toggle(languageManager.L("auto_save"), isOn: $saveToPhotos)
                } header: {
                    Text(languageManager.L("video_settings"))
                }

                // Language Settings
                Section {
                    Picker("Language", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .onChange(of: languageManager.currentLanguage, perform: { _ in
                        showLanguageRestartAlert = true
                    })
                } header: {
                    Text("Language")
                } footer: {
                    Text(languageManager.L("language_note"))
                        .font(.caption)
                }

                // About Section
                Section {
                    HStack {
                        Text(languageManager.L("version"))
                        Spacer()
                        Text("1.0.1")
                            .foregroundColor(.gray)
                    }

                    Button(action: { showPrivacyPolicy = true }) {
                        HStack {
                            Text(languageManager.L("privacy_policy"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }

                    Button(action: { showTermsOfService = true }) {
                        HStack {
                            Text(languageManager.L("terms"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }

                    Link(destination: URL(string: "https://b19.co.jp/support")!) {
                        HStack {
                            Text(languageManager.L("support"))
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text(languageManager.L("about"))
                }

                // Tips Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow(icon: "hand.draw", text: languageManager.L("tip_drag"))
                        tipRow(icon: "arrow.up.left.and.arrow.down.right", text: languageManager.L("tip_pinch"))
                        tipRow(icon: "person.crop.rectangle", text: languageManager.L("tip_mosaic"))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(languageManager.L("tips"))
                }
            }
            .navigationTitle(languageManager.L("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.L("done")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPurchaseView) {
                PurchaseView()
                    .environmentObject(purchaseManager)
            }
            .alert(languageManager.L("language_changed"), isPresented: $showLanguageRestartAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(languageManager.L("language_changed_msg"))
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
