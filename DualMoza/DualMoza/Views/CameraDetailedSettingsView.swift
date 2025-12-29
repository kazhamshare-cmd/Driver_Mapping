import SwiftUI
import PhotosUI

// Sheet wrapper with close button
struct CameraDetailedSettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cameraManager: CameraManager
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            CameraDetailedSettingsView(cameraManager: cameraManager)
                .environmentObject(appState)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(languageManager.L("done")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct CameraDetailedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cameraManager: CameraManager
    @StateObject private var languageManager = LanguageManager.shared

    @State private var showBackImagePicker = false
    @State private var showFrontImagePicker = false
    @State private var selectedBackPhotoItem: PhotosPickerItem?
    @State private var selectedFrontPhotoItem: PhotosPickerItem?

    // デバウンス用タイマー
    @State private var mosaicUpdateTimer: Timer?

    // スライダー操作中のローカル値（UI即時反映用）
    @State private var localBackMosaicIntensity: CGFloat = 20.0
    @State private var localFrontMosaicIntensity: CGFloat = 20.0
    @State private var localBackMosaicCoverage: CGFloat = 0.5
    @State private var localFrontMosaicCoverage: CGFloat = 0.5
    @State private var hasInitializedLocalValues = false

    var body: some View {
        Form {
            // Back Camera Section
            Section(header: Label(languageManager.L("back_camera"), systemImage: "camera.fill")) {
                cameraControls(
                    settings: appState.backCamera,
                    position: .back
                )
            }

            // Front Camera Section
            Section(header: Label(languageManager.L("front_camera"), systemImage: "camera.rotate.fill")) {
                cameraControls(
                    settings: appState.frontCamera,
                    position: .front
                )
            }
        }
        .navigationTitle(languageManager.L("camera_detailed_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // ローカル値を初期化
            if !hasInitializedLocalValues {
                localBackMosaicIntensity = appState.backCamera.mosaicIntensity
                localFrontMosaicIntensity = appState.frontCamera.mosaicIntensity
                localBackMosaicCoverage = appState.backCamera.mosaicCoverage
                localFrontMosaicCoverage = appState.frontCamera.mosaicCoverage
                hasInitializedLocalValues = true
            }
        }
        .onDisappear {
            // 画面離脱時にタイマーをクリーン
            mosaicUpdateTimer?.invalidate()
            mosaicUpdateTimer = nil
        }
        .onChange(of: selectedBackPhotoItem) { newItem in
            loadImage(from: newItem, for: appState.backCamera)
        }
        .onChange(of: selectedFrontPhotoItem) { newItem in
            loadImage(from: newItem, for: appState.frontCamera)
        }
    }

    // Load image from PhotosPickerItem
    private func loadImage(from item: PhotosPickerItem?, for settings: CameraSettings) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    settings.staticImage = uiImage
                }
            }
        }
    }
    
    // Local enum to avoid dependency on ControlPanelView
    enum CameraPosition {
        case front, back
    }

    // Camera Controls Builder
    @ViewBuilder
    private func cameraControls(settings: CameraSettings, position: CameraPosition) -> some View {
        // Toggle Camera Mode
        Picker(languageManager.L("mode"), selection: Binding(
            get: { settings.mode },
            set: { newValue in
                settings.mode = newValue
            }
        )) {
            ForEach(CameraMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.vertical, 4)

        // Static Image Selection
        if settings.mode == .staticImage {
            VStack(spacing: 12) {
                // Show selected image preview
                if let staticImage = settings.staticImage {
                    Image(uiImage: staticImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(8)
                }

                // Photo Picker Button
                PhotosPicker(
                    selection: position == .back ? $selectedBackPhotoItem : $selectedFrontPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(settings.staticImage == nil ? languageManager.L("select_photo") : languageManager.L("change_photo"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }

        if settings.mode == .on {
            // Zoom
            VStack(alignment: .leading) {
                HStack {
                    Text(languageManager.L("zoom"))
                    Spacer()
                    Text(String(format: "%.1fx", settings.zoom))
                        .foregroundColor(.gray)
                }
                Slider(
                    value: Binding(
                        get: { settings.zoom },
                        set: { newValue in
                            settings.zoom = newValue
                            cameraManager.setZoom(
                                newValue,
                                for: position == .front ? .front : .back
                            )
                        }
                    ),
                    in: settings.minZoom...settings.maxZoom
                )
            }

            // Exposure
            VStack(alignment: .leading) {
                HStack {
                    Text(languageManager.L("exposure"))
                    Spacer()
                    Text(String(format: "%+.1f", settings.exposureValue))
                        .foregroundColor(.gray)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.exposureValue) },
                        set: { newValue in
                            settings.exposureValue = Float(newValue)
                            cameraManager.setExposure(
                                Float(newValue),
                                for: position == .front ? .front : .back
                            )
                        }
                    ),
                    in: Double(settings.minEV)...Double(settings.maxEV)
                )
            }

            // Privacy Filter Settings
            Toggle(languageManager.L("privacy_filter"), isOn: Binding(
                get: { settings.mosaicEnabled },
                set: { newValue in
                    settings.mosaicEnabled = newValue
                    if position == .front {
                        cameraManager.frontMosaicEnabled = newValue
                    } else {
                        cameraManager.backMosaicEnabled = newValue
                    }
                }
            ))

            if settings.mosaicEnabled {
                // Filter Type Selection
                Picker(languageManager.L("filter_type"), selection: Binding(
                    get: { settings.privacyFilterType },
                    set: { newValue in
                        settings.privacyFilterType = newValue
                        if position == .front {
                            cameraManager.frontPrivacyFilterType = newValue
                        } else {
                            cameraManager.backPrivacyFilterType = newValue
                        }
                    }
                )) {
                    ForEach(PrivacyFilterType.allCases, id: \.self) { filterType in
                        Text(filterType.rawValue).tag(filterType)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                // Detection Mode Selection (iOS 17+ only)
                if cameraManager.isPersonDetectionAvailable {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(languageManager.L("detection_mode"), selection: Binding(
                            get: { settings.detectionMode },
                            set: { newValue in
                                settings.detectionMode = newValue
                                if position == .front {
                                    cameraManager.frontDetectionMode = newValue
                                } else {
                                    cameraManager.backDetectionMode = newValue
                                }
                            }
                        )) {
                            Text(languageManager.L("face_only")).tag(DetectionMode.faceOnly)
                            Text(languageManager.L("person_detection")).tag(DetectionMode.personDetection)
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if settings.detectionMode == .personDetection {
                            Text(languageManager.L("person_detection_note"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                // Mosaic Intensity (荒さ) - デバウンス付き
                VStack(alignment: .leading) {
                    HStack {
                        Text(languageManager.L("mosaic_intensity"))
                        Spacer()
                        Text("\(Int(position == .front ? localFrontMosaicIntensity : localBackMosaicIntensity))")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text(languageManager.L("fine"))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Slider(
                            value: Binding(
                                get: { position == .front ? localFrontMosaicIntensity : localBackMosaicIntensity },
                                set: { newValue in
                                    // ローカル値を即時更新（UI用）
                                    if position == .front {
                                        localFrontMosaicIntensity = newValue
                                    } else {
                                        localBackMosaicIntensity = newValue
                                    }
                                    // デバウンス付きでCameraManagerに反映
                                    debouncedUpdateMosaicIntensity(newValue, position: position, settings: settings)
                                }
                            ),
                            in: settings.minMosaicIntensity...settings.maxMosaicIntensity
                        )
                        .tint(.red)
                        Text(languageManager.L("coarse"))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Mosaic Coverage (範囲) - デバウンス付き
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(languageManager.L("mosaic_coverage"))
                        Spacer()
                        Text(coverageLabel(position == .front ? localFrontMosaicCoverage : localBackMosaicCoverage))
                            .foregroundColor(.gray)
                    }
                    Text(languageManager.L("mosaic_coverage_note"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(languageManager.L("eyes_only"))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Slider(
                            value: Binding(
                                get: { position == .front ? localFrontMosaicCoverage : localBackMosaicCoverage },
                                set: { newValue in
                                    // ローカル値を即時更新（UI用）
                                    if position == .front {
                                        localFrontMosaicCoverage = newValue
                                    } else {
                                        localBackMosaicCoverage = newValue
                                    }
                                    // デバウンス付きでCameraManagerに反映
                                    debouncedUpdateMosaicCoverage(newValue, position: position, settings: settings)
                                }
                            ),
                            in: settings.minMosaicCoverage...settings.maxMosaicCoverage
                        )
                        .tint(.orange)
                        Text(languageManager.L("full"))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // Helper function for coverage label
    private func coverageLabel(_ coverage: CGFloat) -> String {
        if coverage < 0.3 {
            return languageManager.L("eyes_only")
        } else if coverage < 0.7 {
            return languageManager.L("standard")
        } else {
            return languageManager.L("wide")
        }
    }

    // MARK: - デバウンス付きモザイク更新関数

    /// モザイク強度のデバウンス付き更新（200ms遅延）
    private func debouncedUpdateMosaicIntensity(_ value: CGFloat, position: CameraPosition, settings: CameraSettings) {
        // 既存のタイマーをキャンセル
        mosaicUpdateTimer?.invalidate()

        // 200ms後に実際の値を更新
        mosaicUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [self] _ in
            settings.mosaicIntensity = value
            if position == .front {
                cameraManager.frontMosaicIntensity = value
            } else {
                cameraManager.backMosaicIntensity = value
            }
        }
    }

    /// モザイク範囲のデバウンス付き更新（200ms遅延）
    private func debouncedUpdateMosaicCoverage(_ value: CGFloat, position: CameraPosition, settings: CameraSettings) {
        // 既存のタイマーをキャンセル
        mosaicUpdateTimer?.invalidate()

        // 200ms後に実際の値を更新
        mosaicUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [self] _ in
            settings.mosaicCoverage = value
            if position == .front {
                cameraManager.frontMosaicCoverage = value
            } else {
                cameraManager.backMosaicCoverage = value
            }
        }
    }
}
