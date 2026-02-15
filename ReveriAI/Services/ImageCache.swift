import SwiftUI

@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func load(url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else {
                return nil
            }
            cache.setObject(uiImage, forKey: key, cost: data.count)
            return uiImage
        }

        inFlight[url] = task
        let result = await task.value
        inFlight.removeValue(forKey: url)
        return result
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                if let cached = ImageCache.shared.image(for: url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                if let uiImage = await ImageCache.shared.load(url: url) {
                    phase = .success(Image(uiImage: uiImage))
                } else {
                    phase = .failure(URLError(.badServerResponse))
                }
            }
    }
}

enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}
