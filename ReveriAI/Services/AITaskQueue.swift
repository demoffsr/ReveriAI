import Foundation

actor AITaskQueue {
    static let shared = AITaskQueue()

    private let maxConcurrent = 2
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func enqueue<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await acquireSlot()
        defer { releaseSlot() }
        return try await operation()
    }

    private func acquireSlot() async {
        if running < maxConcurrent {
            running += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func releaseSlot() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            running -= 1
        }
    }
}
