import SwiftUI

struct PiPView: View {
    let image: UIImage?
    @ObservedObject var settings: PiPSettings

    @State private var dragOffset: CGSize = .zero

    private var frameHeight: CGFloat {
        settings.shape == .circle ? settings.size : settings.size * 1.3
    }

    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: settings.size, height: frameHeight)
                    .clipShape(getPiPShape())
                    .overlay(
                        getPiPShape()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    .contentShape(getPiPShape())
                    .position(
                        x: min(max(settings.position.x + dragOffset.width, settings.size / 2),
                               geometry.size.width - settings.size / 2),
                        y: min(max(settings.position.y + dragOffset.height, frameHeight / 2),
                               geometry.size.height - frameHeight / 2)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                settings.position = CGPoint(
                                    x: min(max(settings.position.x + value.translation.width, settings.size / 2),
                                           geometry.size.width - settings.size / 2),
                                    y: min(max(settings.position.y + value.translation.height, frameHeight / 2),
                                           geometry.size.height - frameHeight / 2)
                                )
                                dragOffset = .zero
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let newSize = settings.size * scale
                                settings.size = min(max(newSize, settings.minSize), settings.maxSize)
                            }
                    )
            }
        }
    }

    private func getPiPShape() -> AnyShape {
        if settings.shape == .circle {
            return AnyShape(Circle())
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - AnyShape Helper
struct AnyShape: Shape, @unchecked Sendable {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
