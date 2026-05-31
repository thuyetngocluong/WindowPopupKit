import Foundation
import os

public final class WPAsyncGuarantee<T: Sendable>: Sendable {

    private struct State {
        var continuation: CheckedContinuation<T, Never>?
        var bufferedValue: T?
        var isResolved: Bool
    }

    private let state = OSAllocatedUnfairLock<State>(
        initialState: .init(continuation: nil, bufferedValue: nil, isResolved: false)
    )

    private let task: Task<T, Never>

    deinit {
        task.cancel()
    }

    public init() {
        let state = self.state
        self.task = Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
                let immediate: T? = state.withLock { s in
                    if s.isResolved, let bufferedValue = s.bufferedValue {
                        return bufferedValue
                    }
                    s.continuation = continuation
                    return nil
                }
                if let immediate {
                    continuation.resume(returning: immediate)
                }
            }
        }
    }

    public func value() async -> T {
        await task.value
    }

    public func resolve(with value: T) {
        let toResume: CheckedContinuation<T, Never>? = state.withLock { s in
            guard !s.isResolved else { return nil }
            s.isResolved = true
            s.bufferedValue = value
            let cont = s.continuation
            s.continuation = nil
            return cont
        }
        toResume?.resume(returning: value)
    }
}
