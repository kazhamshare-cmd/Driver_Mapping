import SwiftUI
import PhotosUI
import AVFoundation

struct ControlPanelView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var lang = LanguageManager.shared

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectingImageFor: CameraPosition = .back

    enum CameraPosition {
        case front, back
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // PiP Settings
                pipSettingsSection

                Divider().background(Color.white.opacity(0.3))

                // Back Camera Settings
                cameraSettingsSection(
                    title: lang.L("back_camera"),
                    settings: appState.backCamera,
                    position: .back
                )

                Divider().background(Color.white.opacity(0.3))

                // Front Camera Settings
                cameraSettingsSection(
                    title: lang.L("front_camera"),
                    settings: appState.frontCamera,
                    position: .front
                )
            }
            .padding(16)
        }
        .frame(maxHeight: 500)
        .background(Color.black.opacity(0.9))
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .onChange(of: selectedPhotoItem) { newItem in
            loadSelectedImage(from: newItem)
        }
    }

    // MARK: - PiP Settings Section
    private var pipSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.L("pip"))
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Text(lang.L("shape"))
                    .foregroundColor(.gray)

                Picker("", selection: $appState.pipSettings.shape) {
                    ForEach(PiPShape.allCases, id: \.self) { shape in
                        Text(shape.rawValue).tag(shape)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Text(lang.L("size"))
                    .foregroundColor(.gray)

                Slider(
                    value: $appState.pipSettings.size,
                    in: appState.pipSettings.minSize...appState.pipSettings.maxSize
                )
                .tint(.blue)

                Text("\(Int(appState.pipSettings.size))")
                    .foregroundColor(.white)
                    .frame(width: 40)
            }
        }
    }

    // MARK: - Camera Settings Section
    private func cameraSettingsSection(
        title: String,
        settings: CameraSettings,
        position: CameraPosition
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with icon
            HStack {
                Image(systemName: position == .back ? "camera.fill" : "camera.rotate.fill")
                    .foregroundColor(.white)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Mode selector - 2行に分割
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(lang.L("display"))
                        .foregroundColor(.gray)
                        .frame(width: 50, alignment: .leading)

                    ForEach(CameraMode.allCases, id: \.self) { mode in
                        Button(action: {
                            if mode == .staticImage {
                                selectingImageFor = position
                            }
                            settings.mode = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(settings.mode == mode ? .semibold : .regular)
                                .foregroundColor(settings.mode == mode ? .black : .white)
                                .frame(width: 70, height: 36)
                                .background(settings.mode == mode ? Color.white : Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                    }

                    Spacer()

                    // Image picker for static image mode
                    if settings.mode == .staticImage {
                        PhotosPicker(
                            selection: Binding(
                                get: { selectedPhotoItem },
                                set: { newValue in
                                    selectingImageFor = position
                                    selectedPhotoItem = newValue
                                }
                            ),
                            matching: .images
                        ) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 36)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Only show controls if camera is ON
            if settings.mode == .on {
                // Zoom slider
                HStack {
                    Text("Zoom")
                        .foregroundColor(.gray)
                        .frame(width: 50, alignment: .leading)

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
                    .tint(.green)

                    Text(String(format: "%.1fx", settings.zoom))
                        .foregroundColor(.white)
                        .frame(width: 45)
                }

                // EV slider
                HStack {
                    Text("EV")
                        .foregroundColor(.gray)
                        .frame(width: 50, alignment: .leading)

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
                    .tint(.yellow)

                    Text(String(format: "%+.1f", settings.exposureValue))
                        .foregroundColor(.white)
                        .frame(width: 45)
                }

                // Mosaic toggle
                HStack {
                    Text(lang.L("mosaic"))
                        .foregroundColor(.gray)
                        .frame(width: 70, alignment: .leading)

                    Toggle("", isOn: Binding(
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
                    .labelsHidden()
                    .tint(.red)

                    Spacer()

                    if settings.mosaicEnabled {
                        Text(lang.L("auto_detect_face"))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Mosaic intensity slider (only when mosaic is enabled)
                if settings.mosaicEnabled {
                    HStack {
                        Text(lang.L("intensity"))
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .leading)

                        Text(lang.L("fine"))
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Slider(
                            value: Binding(
                                get: { settings.mosaicIntensity },
                                set: { newValue in
                                    settings.mosaicIntensity = newValue
                                    if position == .front {
                                        cameraManager.frontMosaicIntensity = newValue
                                    } else {
                                        cameraManager.backMosaicIntensity = newValue
                                    }
                                }
                            ),
                            in: settings.minMosaicIntensity...settings.maxMosaicIntensity
                        )
                        .tint(.red)

                        Text(lang.L("coarse"))
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text("\(Int(settings.mosaicIntensity))")
                            .foregroundColor(.white)
                            .frame(width: 30)
                    }

                    // Mosaic coverage slider
                    HStack {
                        Text(lang.L("range"))
                            .foregroundColor(.gray)
                            .frame(width: 50, alignment: .leading)

                        Text(lang.L("eyes"))
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Slider(
                            value: Binding(
                                get: { settings.mosaicCoverage },
                                set: { newValue in
                                    settings.mosaicCoverage = newValue
                                    if position == .front {
                                        cameraManager.frontMosaicCoverage = newValue
                                    } else {
                                        cameraManager.backMosaicCoverage = newValue
                                    }
                                }
                            ),
                            in: settings.minMosaicCoverage...settings.maxMosaicCoverage
                        )
                        .tint(.orange)

                        Text(lang.L("all"))
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text(coverageLabel(settings.mosaicCoverage))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    // Helper function for coverage label
    private func coverageLabel(_ coverage: CGFloat) -> String {
        if coverage < 0.3 {
            return lang.L("eyes")
        } else if coverage < 0.7 {
            return lang.L("standard")
        } else {
            return lang.L("wide_short")
        }
    }

    // MARK: - Load Selected Image
    private func loadSelectedImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        if selectingImageFor == .front {
                            appState.frontCamera.staticImage = image
                        } else {
                            appState.backCamera.staticImage = image
                        }
                    }
                case .failure(let error):
                    print("Failed to load image: \(error)")
                }
            }
        }
    }
}
