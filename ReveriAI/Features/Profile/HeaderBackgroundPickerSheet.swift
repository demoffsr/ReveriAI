import SwiftUI
import PhotosUI

struct HeaderBackgroundPickerSheet: View {
    var headerBackgroundStorage: HeaderBackgroundStorage
    var initialImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var sourceImage: UIImage?
    @State private var fullResImage: UIImage?

    // Gesture state — committed values
    @State private var committedScale: CGFloat = 1.0
    @State private var committedOffset: CGSize = .zero
    // Gesture state — live delta
    @State private var gestureScale: CGFloat = 1.0
    @State private var gestureOffset: CGSize = .zero

    // The crop zone dimensions (what actually gets saved)
    private let cropHeight: CGFloat = 257 // baseHeaderHeight(220) + cloudOverhang(44.5) - 8
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    private var currentScale: CGFloat {
        min(max(committedScale * gestureScale, minScale), maxScale)
    }

    private var currentOffset: CGSize {
        CGSize(
            width: committedOffset.width + gestureOffset.width,
            height: committedOffset.height + gestureOffset.height
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let sourceImage {
                cropView(sourceImage)
            } else {
                Color.clear
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if let initialImage {
                fullResImage = initialImage
                sourceImage = downsample(initialImage, maxWidth: 1200)
            }
        }
    }

    // MARK: - Crop View

    private func cropView(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .reveriGlass(.circle)
                }

                Spacer()

                Text(String(localized: "profile.positionAndScale", defaultValue: "Position & Scale"))
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    saveCroppedImage()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .reveriGlass(.circle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Full-bleed image canvas with crop guide
            GeometryReader { geo in
                let canvasWidth = geo.size.width
                let canvasHeight = geo.size.height
                let cropWidth = canvasWidth
                // Crop zone centered vertically
                let cropY = (canvasHeight - cropHeight) / 2

                ZStack {
                    // Image layer — fills canvas, not clipped
                    imageLayer(image: image, cropWidth: cropWidth, canvasSize: geo.size, cropY: cropY)

                    // Dark overlay with crop cutout
                    cropGuideOverlay(canvasSize: geo.size, cropWidth: cropWidth, cropY: cropY)
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture(image: image, cropWidth: cropWidth))
                .gesture(magnifyGesture(image: image, cropWidth: cropWidth))
            }

            // Hint
            Text(String(localized: "profile.pinchToZoom", defaultValue: "Pinch to zoom, drag to reposition"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                .padding(.vertical, 14)
        }
    }

    // MARK: - Image Layer

    private func imageLayer(image: UIImage, cropWidth: CGFloat, canvasSize: CGSize, cropY: CGFloat) -> some View {
        let fill = fillSize(for: image, cropWidth: cropWidth)
        let clamped = clampOffset(
            currentOffset,
            scaledSize: CGSize(width: fill.width * currentScale, height: fill.height * currentScale),
            cropSize: CGSize(width: cropWidth, height: cropHeight)
        )
        // Image is positioned relative to the crop zone center
        let cropCenterY = cropY + cropHeight / 2

        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: fill.width, height: fill.height)
            .scaleEffect(currentScale)
            .position(
                x: canvasSize.width / 2 + clamped.width,
                y: cropCenterY + clamped.height
            )
            .drawingGroup()
    }

    // MARK: - Crop Guide Overlay

    private func cropGuideOverlay(canvasSize: CGSize, cropWidth: CGFloat, cropY: CGFloat) -> some View {
        let headerGuideHeight: CGFloat = 220.0

        return ZStack {
            // Top dark zone
            VStack(spacing: 0) {
                Color.black.opacity(0.55)
                    .frame(height: cropY)
                Spacer()
            }

            // Bottom dark zone
            VStack(spacing: 0) {
                Spacer()
                Color.black.opacity(0.55)
                    .frame(height: canvasSize.height - cropY - cropHeight)
            }

            // Crop zone border
            RoundedRectangle(cornerRadius: 2)
                .stroke(.white.opacity(0.4), lineWidth: 1)
                .frame(width: cropWidth, height: cropHeight)
                .position(x: canvasSize.width / 2, y: cropY + cropHeight / 2)

            // Header guide line inside crop zone (shows where clouds start)
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: cropWidth - 32, height: 1)
                .position(x: canvasSize.width / 2, y: cropY + headerGuideHeight)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private func dragGesture(image: UIImage, cropWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                gestureOffset = value.translation
            }
            .onEnded { value in
                let fill = fillSize(for: image, cropWidth: cropWidth)
                let newOffset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                committedOffset = clampOffset(
                    newOffset,
                    scaledSize: CGSize(width: fill.width * currentScale, height: fill.height * currentScale),
                    cropSize: CGSize(width: cropWidth, height: cropHeight)
                )
                gestureOffset = .zero
            }
    }

    private func magnifyGesture(image: UIImage, cropWidth: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureScale = value.magnification
            }
            .onEnded { value in
                let newScale = min(max(committedScale * value.magnification, minScale), maxScale)
                committedScale = newScale
                gestureScale = 1.0
                let fill = fillSize(for: image, cropWidth: cropWidth)
                committedOffset = clampOffset(
                    committedOffset,
                    scaledSize: CGSize(width: fill.width * newScale, height: fill.height * newScale),
                    cropSize: CGSize(width: cropWidth, height: cropHeight)
                )
            }
    }

    // MARK: - Helpers

    private func fillSize(for image: UIImage, cropWidth: CGFloat) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let cropAspect = cropWidth / cropHeight
        if imageAspect > cropAspect {
            return CGSize(width: cropHeight * imageAspect, height: cropHeight)
        } else {
            return CGSize(width: cropWidth, height: cropWidth / imageAspect)
        }
    }

    private func clampOffset(_ offset: CGSize, scaledSize: CGSize, cropSize: CGSize) -> CGSize {
        let maxX = max((scaledSize.width - cropSize.width) / 2, 0)
        let maxY = max((scaledSize.height - cropSize.height) / 2, 0)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func downsample(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let ratio = maxWidth / image.size.width
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func saveCroppedImage() {
        guard let image = fullResImage ?? sourceImage else { return }
        let screenScale: CGFloat = 3.0
        let screenWidth: CGFloat = 393
        let targetSize = CGSize(
            width: screenWidth * screenScale,
            height: cropHeight * screenScale
        )

        let cropWidth = screenWidth
        let fill = fillSize(for: sourceImage ?? image, cropWidth: cropWidth)
        let clampedScale = min(max(committedScale, minScale), maxScale)

        let clampedOffset = clampOffset(
            committedOffset,
            scaledSize: CGSize(width: fill.width * clampedScale, height: fill.height * clampedScale),
            cropSize: CGSize(width: cropWidth, height: cropHeight)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let cropped = renderer.image { _ in
            let drawWidth = fill.width * clampedScale * screenScale
            let drawHeight = fill.height * clampedScale * screenScale
            let drawX = (targetSize.width - drawWidth) / 2 + clampedOffset.width * screenScale
            let drawY = (targetSize.height - drawHeight) / 2 + clampedOffset.height * screenScale
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }

        headerBackgroundStorage.save(uiImage: cropped)
        AnalyticsService.track(.wallpaperChanged, metadata: ["type": "custom_photo"])
        dismiss()
    }
}
