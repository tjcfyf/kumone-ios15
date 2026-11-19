import Foundation

/// `Duration`, `Clock` and `Task.sleep(for:)` are iOS 16 / macOS 13 only. The
/// app targets iOS 15, so timing is kept in plain seconds and nanoseconds
/// here, where every system can do the arithmetic.
enum AppTime {
    /// A monotonic timestamp in nanoseconds. `ContinuousClock` is the natural
    /// choice on the newer systems, but it does not exist on iOS 15.
    @inline(__always) static var nowNanoseconds: UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    @inline(__always) static func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
    }

    @inline(__always) static func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}

/// `OSAllocatedUnfairLock` is iOS 16. This keeps the same `withLock` shape on
/// an `NSLock`, which every supported system has.
final class CompatLockedState<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: State

    init(initialState: State) {
        value = initialState
    }

    func withLock<R>(_ body: (inout State) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
