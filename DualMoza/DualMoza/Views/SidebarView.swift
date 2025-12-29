import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var lang = LanguageManager.shared

    var onFlipCamera: () -> Void
    var onOpenSettings: () -> Void
    var onOpenCameraSettings: () -> Void
    var isLandscape: Bool = false  // ランドスケープモード

    @State private var showZoomSlider = false

    // iPad対応のスケール
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var buttonSize: CGFloat { isLandscape ? 44 : (isIPad ? 70 : 56) }
    private var iconFont: Font { isLandscape ? .body : (isIPad ? .title : .title3) }
    private var labelFont: CGFloat { isLandscape ? 7 : (isIPad ? 11 : 8) }
    private var spacing: CGFloat { isLandscape ? 8 : (isIPad ? 20 : 12) }
    private var sliderWidth: CGFloat { isIPad ? 220 : 150 }

    var body: some View {
        if isLandscape {
            // ランドスケープモード: 横並び（アイコンのみ）
            VStack(spacing: 8) {
                // Zoom Slider (上に表示)
                if showZoomSlider {
                    HorizontalZoomSliderView(
                        zoom: currentZoomBinding,
                        minZoom: currentCameraSettings.minZoom,
                        maxZoom: currentCameraSettings.maxZoom
                    )
                    .frame(width: sliderWidth, height: 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Main sidebar buttons - 横並び（アイコンのみ）
                HStack(spacing: 6) {
                    // Zoom Button
                    LandscapeSidebarButton(
                        systemName: "plus.magnifyingglass",
                        label: String(format: "%.1fx", currentZoom),
                        isActive: showZoomSlider
                    ) {
                        withAnimation(.spring()) {
                            showZoomSlider.toggle()
                        }
                    }

                    // Flip Camera
                    LandscapeSidebarButton(
                        systemName: "arrow.triangle.2.circlepath.camera.fill"
                    ) {
                        onFlipCamera()
                    }

                    // PiP Toggle
                    LandscapeSidebarButton(
                        systemName: isPiPEnabled ? "pip.enter" : "pip.exit"
                    ) {
                        togglePiP()
                    }

                    // PiP Shape Toggle (only show when PiP is enabled)
                    if isPiPEnabled {
                        LandscapeSidebarButton(
                            systemName: appState.pipSettings.shape == .circle ? "circle.fill" : "rectangle.fill"
                        ) {
                            togglePiPShape()
                        }
                    }

                    // Mosaic Toggle
                    LandscapeSidebarButton(
                        systemName: isMosaicEnabled ? "face.dashed.fill" : "face.dashed",
                        isActive: isMosaicEnabled
                    ) {
                        toggleMosaic()
                    }

                    // Camera Settings
                    LandscapeSidebarButton(
                        systemName: "slider.horizontal.3"
                    ) {
                        onOpenCameraSettings()
                    }

                    // Settings
                    LandscapeSidebarButton(
                        systemName: "gearshape.fill"
                    ) {
                        onOpenSettings()
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .clipShape(Capsule())
                )
            }
        } else {
            // ポートレートモード: 従来の縦並び
            HStack(spacing: isIPad ? 16 : 12) {
                // Horizontal Zoom Slider (appears to the left when active)
                if showZoomSlider {
                    HorizontalZoomSliderView(
                        zoom: currentZoomBinding,
                        minZoom: currentCameraSettings.minZoom,
                        maxZoom: currentCameraSettings.maxZoom
                    )
                    .frame(width: sliderWidth, height: isIPad ? 44 : 36)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // Main sidebar buttons
                VStack(spacing: spacing) {
                    // Zoom Button
                    SidebarButton(
                        systemName: "plus.magnifyingglass",
                        label: String(format: "%.1fx", currentZoom),
                        isActive: showZoomSlider,
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        withAnimation(.spring()) {
                            showZoomSlider.toggle()
                        }
                    }

                    // Flip Camera
                    SidebarButton(
                        systemName: "arrow.triangle.2.circlepath.camera.fill",
                        label: lang.L("switch_camera"),
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        onFlipCamera()
                    }

                    // PiP Toggle
                    SidebarButton(
                        systemName: isPiPEnabled ? "pip.enter" : "pip.exit",
                        label: lang.L("pip"),
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        togglePiP()
                    }

                    // PiP Shape Toggle (only show when PiP is enabled)
                    if isPiPEnabled {
                        SidebarButton(
                            systemName: appState.pipSettings.shape == .circle ? "circle.fill" : "rectangle.fill",
                            label: appState.pipSettings.shape == .circle ? lang.L("circle") : lang.L("rectangle"),
                            buttonSize: buttonSize,
                            iconFont: iconFont,
                            labelFontSize: labelFont
                        ) {
                            togglePiPShape()
                        }
                    }

                    // Mosaic Toggle
                    SidebarButton(
                        systemName: isMosaicEnabled ? "face.dashed.fill" : "face.dashed",
                        label: lang.L("mosaic"),
                        isActive: isMosaicEnabled,
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        toggleMosaic()
                    }

                    // Camera Settings
                    SidebarButton(
                        systemName: "slider.horizontal.3",
                        label: lang.L("camera"),
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        onOpenCameraSettings()
                    }

                    // Settings
                    SidebarButton(
                        systemName: "gearshape.fill",
                        label: lang.L("settings"),
                        buttonSize: buttonSize,
                        iconFont: iconFont,
                        labelFontSize: labelFont
                    ) {
                        onOpenSettings()
                    }
                }
                .padding(.vertical, isIPad ? 28 : 20)
                .padding(.horizontal, isIPad ? 12 : 8)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 36 : 28)
                        .fill(Color.black.opacity(0.3))
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 36 : 28))
                )
            }
        }
    }

    // MARK: - Current Camera Settings
    private var currentCameraSettings: CameraSettings {
        appState.mainCameraIsBack ? appState.backCamera : appState.frontCamera
    }

    private var currentZoom: CGFloat {
        currentCameraSettings.zoom
    }

    private var currentZoomBinding: Binding<CGFloat> {
        Binding(
            get: { currentCameraSettings.zoom },
            set: { newValue in
                currentCameraSettings.zoom = newValue
                cameraManager.setZoom(
                    newValue,
                    for: appState.mainCameraIsBack ? .back : .front
                )
            }
        )
    }
    
    // MARK: - Helpers
    
    private var isPiPEnabled: Bool {
        if appState.mainCameraIsBack {
            return appState.frontCamera.mode != .off
        } else {
            return appState.backCamera.mode != .off
        }
    }
    
    private var isMosaicEnabled: Bool {
        if appState.mainCameraIsBack {
            return appState.backCamera.mosaicEnabled
        } else {
            return appState.frontCamera.mosaicEnabled
        }
    }
    
    private func togglePiP() {
        withAnimation {
            if isPiPEnabled {
                // Turn off secondary camera
                if appState.mainCameraIsBack {
                    appState.frontCamera.mode = .off
                } else {
                    appState.backCamera.mode = .off
                }
            } else {
                // Turn on secondary camera (default to back/front swap)
                if appState.mainCameraIsBack {
                    appState.frontCamera.mode = .on
                } else {
                    appState.backCamera.mode = .on
                }
            }
        }
    }
    
    private func toggleMosaic() {
        let newValue = !isMosaicEnabled
        if appState.mainCameraIsBack {
            appState.backCamera.mosaicEnabled = newValue
            cameraManager.backMosaicEnabled = newValue
        } else {
            appState.frontCamera.mosaicEnabled = newValue
            cameraManager.frontMosaicEnabled = newValue
        }
    }

    private func togglePiPShape() {
        withAnimation {
            if appState.pipSettings.shape == .circle {
                appState.pipSettings.shape = .rectangle
            } else {
                appState.pipSettings.shape = .circle
            }
        }
    }
}

struct SidebarButton: View {
    let systemName: String
    let label: String
    var isActive: Bool = false
    var buttonSize: CGFloat = 56
    var iconFont: Font = .title3
    var labelFontSize: CGFloat = 8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(iconFont)
                    .foregroundColor(isActive ? .yellow : .white)
                    .shadow(radius: 2)

                Text(label)
                    .font(.system(size: labelFontSize))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Landscape Sidebar Button (Icon only, compact)
struct LandscapeSidebarButton: View {
    let systemName: String
    var label: String? = nil
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundColor(isActive ? .yellow : .white)
                    .shadow(radius: 2)

                if let label = label {
                    Text(label)
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Helper for Glassmorphism
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Horizontal Zoom Slider View
struct HorizontalZoomSliderView: View {
    @Binding var zoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            // Min label
            Text("1x")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            // Slider track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: fillWidth(for: geometry.size.width), height: 6)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: thumbOffset(for: geometry.size.width))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateZoom(from: value.location.x, width: geometry.size.width)
                        }
                )
            }

            // Max label
            Text("5x")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }

    private func fillWidth(for totalWidth: CGFloat) -> CGFloat {
        let ratio = (zoom - minZoom) / (maxZoom - minZoom)
        return totalWidth * ratio
    }

    private func thumbOffset(for totalWidth: CGFloat) -> CGFloat {
        let ratio = (zoom - minZoom) / (maxZoom - minZoom)
        return (totalWidth * ratio) - 12  // -12 for half of thumb width
    }

    private func updateZoom(from x: CGFloat, width: CGFloat) {
        let ratio = x / width
        let clampedRatio = max(0, min(1, ratio))
        zoom = minZoom + (maxZoom - minZoom) * clampedRatio
    }
}
