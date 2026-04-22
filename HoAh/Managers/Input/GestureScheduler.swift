import Foundation

/// Seam over `Task.sleep` so the multi-press coordinator's timers can be
/// driven by a controllable fake in tests. The live implementation is a
/// thin passthrough to `Task.sleep(nanoseconds:)`.
protocol GestureScheduler: Sendable {
    func sleep(nanoseconds: UInt64) async throws
}

struct LiveGestureScheduler: GestureScheduler {
    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
