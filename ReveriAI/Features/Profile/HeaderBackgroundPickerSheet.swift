import SwiftUI
import PhotosUI

struct HeaderBackgroundPickerSheet: View {
    var headerBackgroundStorage: HeaderBackgroundStorage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    private let previewHeight: CGFloat = 257 // baseHeaderHeight(220) + cloudOverhang(44.5) - 8
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let sourceImage {
                    cropView(sourceImage)
                } else {
                    pickerView
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .enableSwipeBack()
            .onChange(of: selectedPhoto) { _, item in
                loadPhoto(item)
            }
        }
    }

    // MARK: - Picker

    private var pickerView: some View {
        VStack(spacing: 24) {
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.accent)
                    Text(String(localized: "profile.choosePhoto", defaultValue: "Choose Photo"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.black.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }
            Spacer()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .reveriGlass(.circle)
            }
            .padding(.leading, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Crop View

    private func cropView(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(String(localized: "profile.cancel", defaultValue: "Cancel")) {
                    sourceImage = nil
                    selectedPhoto = nil
                    scale = 1.0
                    offset = .zero
                }
                .foregroundStyle(.primary)

                Spacer()

                Text(String(localized: "profile.positionAndScale", defaultValue: "Position & Scale"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "profile.save", defaultValue: "Save")) {
                    saveCroppedImage(image)
                }
                .fontWeight(.semibold)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer()

            // Preview area
            GeometryReader { geo in
                imagePreview(image: image, previewWidth: geo.size.width)
            }
            .frame(height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )

            Spacer()

            Text(String(localized: "profile.pinchToZoom", defaultValue: "Pinch to zoom, drag to reposition"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Image Preview

    private func fillSize(for image: UIImage, previewWidth: CGFloat) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let previewAspect = previewWidth / previewHeight
        if imageAspect > previewAspect {
            let h = previewHeight
            return CGSize(width: h * imageAspect, height: h)
        } else {
            let w = previewWidth
            return CGSize(width: w, height: w / imageAspect)
        }
    }

    private func imagePreview(image: UIImage, previewWidth: CGFloat) -> some View {
        let fill = fillSize(for: image, previewWidth: previewWidth)
        let currentScale = scale * magnifyBy
        let clampedScale = min(max(currentScale, minScale), maxScale)
        let scaledW = fill.width * clampedScale
        let scaledH = fill.height * clampedScale
        let combined = CGSize(
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
        )
        let clamped = clampOffset(
            combined,
            scaledSize: CGSize(width: scaledW, height: scaledH),
            previewSize: CGSize(width: previewWidth, height: previewHeight)
        )

        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: fill.width, height: fill.height)
            .scaleEffect(clampedScale)
            .offset(clamped)
            .frame(width: previewWidth, height: previewHeight)
            .clipped()
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let cs = min(max(scale, minScale), maxScale)
                        let f = fillSize(for: image, previewWidth: previewWidth)
                        let newOffset = CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        )
                        withAnimation(.spring(duration: 0.3)) {
                            offset = clampOffset(
                                newOffset,
                                scaledSize: CGSize(width: f.width * cs, height: f.height * cs),
                                previewSize: CGSize(width: previewWidth, height: previewHeight)
                            )
                        }
                    }
            )
            .gesture(
                MagnifyGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        let newScale = min(max(scale * value.magnification, minScale), maxScale)
                        let f = fillSize(for: image, previewWidth: previewWidth)
                        withAnimation(.spring(duration: 0.3)) {
                            scale = newScale
                            offset = clampOffset(
                                offset,
                                scaledSize: CGSize(width: f.width * newScale, height: f.height * newScale),
                                previewSize: CGSize(width: previewWidth, height: previewHeight)
                            )
                        }
                    }
            )
    }

    // MARK: - Helpers

    private func clampOffset(_ offset: CGSize, scaledSize: CGSize, previewSize: CGSize) -> CGSize {
        let maxX = max((scaledSize.width - previewSize.width) / 2, 0)
        let maxY = max((scaledSize.height - previewSize.height) / 2, 0)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                sourceImage = uiImage
                scale = 1.0
                offset = .zero
            }
        }
    }

    private func saveCroppedImage(_ image: UIImage) {
        let screenScale: CGFloat = 3.0 // Retina
        let screenWidth: CGFloat = 393 // iPhone Pro width
        let targetSize = CGSize(
            width: screenWidth * screenScale,
            height: previewHeight * screenScale
        )

        let previewWidth = screenWidth
        let fill = fillSize(for: image, previewWidth: previewWidth)

        let clampedScale = min(max(scale, minScale), maxScale)
        let scaledWidth = fill.width * clampedScale
        let scaledHeight = fill.height * clampedScale

        let clampedOffset = clampOffset(
            offset,
            scaledSize: CGSize(width: scaledWidth, height: scaledHeight),
            previewSize: CGSize(width: previewWidth, height: previewHeight)
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
        dismiss()
    }
}
