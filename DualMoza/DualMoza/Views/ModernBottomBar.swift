import SwiftUI

struct ModernBottomBar: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var languageManager = LanguageManager.shared
    @Binding var isCapturing: Bool
    var onCapture: () -> Void
    var onOpenGallery: () -> Void

    // iPad対応
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var shutterSize: CGFloat { isIPad ? 100 : 72 }
    private var innerButtonSize: CGFloat { isIPad ? 84 : 60 }
    private var stopButtonSize: CGFloat { isIPad ? 42 : 30 }
    private var galleryButtonSize: CGFloat { isIPad ? 60 : 44 }
    private var bottomPadding: CGFloat { isIPad ? 50 : 30 }
    private var modeFontSize: CGFloat { isIPad ? 18 : 15 }

    var body: some View {
        VStack(spacing: isIPad ? 28 : 20) {
            // Mode Selector (Centered)
            if !appState.isRecording {
                HStack(spacing: isIPad ? 32 : 24) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation {
                                appState.captureMode = mode
                            }
                        }) {
                            Text(localizedModeName(mode))
                                .font(.system(size: modeFontSize, weight: appState.captureMode == mode ? .bold : .medium))
                                .foregroundColor(appState.captureMode == mode ? .white : .white.opacity(0.6))
                                .padding(.horizontal, isIPad ? 24 : 16)
                                .padding(.vertical, isIPad ? 12 : 8)
                                .background(
                                    appState.captureMode == mode ?
                                    Color.white.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(isIPad ? 20 : 16)
                                .shadow(radius: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 48 : 36)
            }

            // Controls Row
            HStack {
                // Gallery (Left)
                Button(action: onOpenGallery) {
                    Image(systemName: "photo.on.rectangle")
                        .font(isIPad ? .title : .title2)
                        .foregroundColor(.white)
                        .frame(width: galleryButtonSize, height: galleryButtonSize)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.leading, isIPad ? 50 : 30)

                Spacer()

                // Shutter Button (Center)
                Button(action: onCapture) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: isIPad ? 6 : 5)
                            .frame(width: shutterSize, height: shutterSize)
                            .shadow(radius: 4)

                        if appState.captureMode == .video {
                            if appState.isRecording {
                                RoundedRectangle(cornerRadius: isIPad ? 10 : 8)
                                    .fill(Color.red)
                                    .frame(width: stopButtonSize, height: stopButtonSize)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: innerButtonSize, height: innerButtonSize)
                            }
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: innerButtonSize, height: innerButtonSize)
                                .scaleEffect(isCapturing ? 0.9 : 1.0)
                        }
                    }
                }

                Spacer()

                // Empty spacer to balance layout (or place for future filters button)
                Color.clear
                    .frame(width: galleryButtonSize, height: galleryButtonSize)
                    .padding(.trailing, isIPad ? 50 : 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }

    private func localizedModeName(_ mode: CaptureMode) -> String {
        switch mode {
        case .video: return languageManager.L("video")
        case .photo: return languageManager.L("photo")
        }
    }
}
