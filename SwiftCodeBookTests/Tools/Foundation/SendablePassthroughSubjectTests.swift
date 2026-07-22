//
//  SendablePassthroughSubjectTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/SendablePassthroughSubject.swift
//  Subject under test: SendablePassthroughSubject<Output, Failure>
//
//  SendablePassthroughSubject is an @unchecked Sendable wrapper around a
//  Combine PassthroughSubject guarded by an NSRecursiveLock. It exposes:
//    - init()
//    - send(_ input: Output)
//    - send(completion: Subscribers.Completion<Failure>)
//    - eraseToAnyPublisher() -> AnyPublisher<Output, Failure>
//

import Testing
@testable import SwiftCodeBook
import Foundation
import Combine

@Suite struct SendablePassthroughSubjectTests {

    // MARK: - Helpers

    private enum TestError: Error, Equatable {
        case boom
        case other(Int)
    }

    /// Collects all values delivered to a publisher. Thread-safe via an internal
    /// lock so it can be read from the test task after concurrent producers have
    /// finished. `@unchecked Sendable` because mutation is fully lock-guarded.
    private final class Collector<Output, Failure: Error>: @unchecked Sendable {
        let lock = NSLock()
        private var _values: [Output] = []
        private var _completion: Subscribers.Completion<Failure>?
        private var _completionCount = 0
        private var cancellable: AnyCancellable?

        var values: [Output] {
            lock.withLock { _values }
        }

        var completion: Subscribers.Completion<Failure>? {
            lock.withLock { _completion }
        }

        /// Number of completion events actually delivered to the sink.
        var completionCount: Int {
            lock.withLock { _completionCount }
        }

        func subscribe(to publisher: AnyPublisher<Output, Failure>) {
            cancellable = publisher.sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.lock.withLock {
                        // First completion wins for the recorded value, but count
                        // every delivery so we can assert "exactly once".
                        if self._completion == nil { self._completion = completion }
                        self._completionCount += 1
                    }
                },
                receiveValue: { [weak self] value in
                    guard let self else { return }
                    self.lock.withLock { self._values.append(value) }
                }
            )
        }

        func cancel() {
            cancellable?.cancel()
            cancellable = nil
        }
    }

    // MARK: - Initialization

    @Test func initSucceedsForVariousGenericArguments() {
        let intSubject = SendablePassthroughSubject<Int, Never>()
        let stringSubject = SendablePassthroughSubject<String, TestError>()
        let voidSubject = SendablePassthroughSubject<Void, Error>()

        // Each must produce a live, subscribable publisher whose Failure type
        // matches the requested generic argument.
        let intCollector = Collector<Int, Never>()
        intCollector.subscribe(to: intSubject.eraseToAnyPublisher())
        intSubject.send(1)
        #expect(intCollector.values == [1])
        intCollector.cancel()

        let stringCollector = Collector<String, TestError>()
        stringCollector.subscribe(to: stringSubject.eraseToAnyPublisher())
        stringSubject.send("ok")
        #expect(stringCollector.values == ["ok"])
        stringCollector.cancel()

        // Void payload: just assert it is delivered (one element) without crashing.
        let voidCollector = Collector<Void, Error>()
        voidCollector.subscribe(to: voidSubject.eraseToAnyPublisher())
        voidSubject.send(())
        #expect(voidCollector.values.count == 1)
        voidCollector.cancel()
    }

    @Test func eraseToAnyPublisherReturnsStablePublisher() {
        // The implementation stores a single erased publisher and returns it on
        // every call. Both references must observe the same underlying subject.
        let subject = SendablePassthroughSubject<Int, Never>()
        let p1 = subject.eraseToAnyPublisher()
        let p2 = subject.eraseToAnyPublisher()

        let c1 = Collector<Int, Never>()
        let c2 = Collector<Int, Never>()
        c1.subscribe(to: p1)
        c2.subscribe(to: p2)

        subject.send(7)

        #expect(c1.values == [7])
        #expect(c2.values == [7])
        #expect(c1.completion == nil)
        #expect(c2.completion == nil)
        c1.cancel()
        c2.cancel()
    }

    @Test func eraseToAnyPublisherCalledManyTimesAlwaysSubscribable() {
        // Repeated retrieval must never invalidate earlier or later subscriptions.
        let subject = SendablePassthroughSubject<Int, Never>()
        var collectors: [Collector<Int, Never>] = []
        for _ in 0..<32 {
            let c = Collector<Int, Never>()
            c.subscribe(to: subject.eraseToAnyPublisher())
            collectors.append(c)
        }

        subject.send(11)
        subject.send(22)

        for c in collectors {
            #expect(c.values == [11, 22])
        }
        for c in collectors { c.cancel() }
    }

    // MARK: - Basic send / receive

    @Test func sendDeliversSingleValueToSubscriber() async {
        let subject = SendablePassthroughSubject<Int, Never>()

        await confirmation("receives one value") { confirm in
            let cancellable = subject.eraseToAnyPublisher().sink { value in
                #expect(value == 42)
                confirm()
            }
            subject.send(42)
            cancellable.cancel()
        }
    }

    @Test func sendDeliversMultipleValuesInOrder() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let inputs = [1, 2, 3, 4, 5]
        for v in inputs {
            subject.send(v)
        }

        #expect(collector.values == inputs)
        #expect(collector.completion == nil)
        collector.cancel()
    }

    @Test func duplicateValuesAreAllDeliveredNotDeduplicated() {
        // PassthroughSubject does not coalesce equal consecutive values.
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(5)
        subject.send(5)
        subject.send(5)

        #expect(collector.values == [5, 5, 5])
        collector.cancel()
    }

    @Test func valuesSentBeforeSubscriptionAreNotReplayed() {
        // PassthroughSubject does not buffer; pre-subscription sends are dropped.
        let subject = SendablePassthroughSubject<Int, Never>()
        subject.send(100)
        subject.send(200)

        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())
        subject.send(300)

        #expect(collector.values == [300])
        collector.cancel()
    }

    @Test func multipleSubscribersAllReceiveTheSameValues() {
        let subject = SendablePassthroughSubject<String, Never>()
        let a = Collector<String, Never>()
        let b = Collector<String, Never>()
        let c = Collector<String, Never>()
        a.subscribe(to: subject.eraseToAnyPublisher())
        b.subscribe(to: subject.eraseToAnyPublisher())
        c.subscribe(to: subject.eraseToAnyPublisher())

        subject.send("x")
        subject.send("y")

        #expect(a.values == ["x", "y"])
        #expect(b.values == ["x", "y"])
        #expect(c.values == ["x", "y"])
        a.cancel(); b.cancel(); c.cancel()
    }

    @Test func sendWithNoSubscribersIsASafeNoOp() {
        let subject = SendablePassthroughSubject<Int, Never>()
        // No subscribers attached; these must be no-ops without crashing.
        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)

        // A subscriber attaching afterwards observes the already-finished stream:
        // no buffered values, an immediate .finished, and nothing else.
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())
        subject.send(3) // ignored: stream already finished

        #expect(collector.values.isEmpty)
        if case .finished = collector.completion {
            // expected
        } else {
            Issue.record("Expected .finished for a subscriber attaching after completion")
        }
        collector.cancel()
    }

    @Test func completionWithNoSubscribersIsASafeNoOp() {
        let subject = SendablePassthroughSubject<String, TestError>()
        // Completing before anyone subscribes must not crash.
        subject.send(completion: .failure(.boom))
        // And later sends are silently dropped.
        subject.send("late")
        #expect(Bool(true)) // reaching here without a crash is the assertion
    }

    // MARK: - String / unicode payloads

    @Test(arguments: [
        "",
        "a",
        "hello world",
        "emoji 😀🎉",
        "combining e\u{0301}",   // e + combining acute accent
        "中文字符",
        "line1\nline2\t\u{0000}"
    ])
    func sendDeliversStringPayloadsVerbatim(_ payload: String) {
        let subject = SendablePassthroughSubject<String, Never>()
        let collector = Collector<String, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())
        subject.send(payload)
        #expect(collector.values == [payload])
        // Verify byte-for-byte fidelity, not just String equality.
        #expect(collector.values.first.map(Array.init(_:)) == Array(payload))
        collector.cancel()
    }

    // MARK: - Integer boundaries

    @Test(arguments: [Int.min, -1, 0, 1, Int.max])
    func sendDeliversIntegerBoundaryValues(_ value: Int) {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())
        subject.send(value)
        #expect(collector.values == [value])
        collector.cancel()
    }

    @Test func sendDeliversDoubleExtremesIncludingNaN() {
        let subject = SendablePassthroughSubject<Double, Never>()
        let collector = Collector<Double, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(.infinity)
        subject.send(-.infinity)
        subject.send(.greatestFiniteMagnitude)
        subject.send(.leastNonzeroMagnitude)
        subject.send(.nan)
        subject.send(0.0)

        let received = collector.values
        #expect(received.count == 6)
        #expect(received[0] == .infinity)
        #expect(received[1] == -.infinity)
        #expect(received[2] == .greatestFiniteMagnitude)
        #expect(received[3] == .leastNonzeroMagnitude)
        #expect(received[4].isNaN)
        #expect(received[5] == 0.0)
        collector.cancel()
    }

    // MARK: - Completion: finished

    @Test func finishedCompletionTerminatesStream() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(1)
        subject.send(completion: .finished)
        // Sends after finished must be ignored by the underlying subject.
        subject.send(2)

        #expect(collector.values == [1])
        #expect(collector.completionCount == 1)
        if case .finished = collector.completion {
            // expected
        } else {
            Issue.record("Expected .finished completion, got \(String(describing: collector.completion))")
        }
        collector.cancel()
    }

    @Test func subscribingAfterFinishImmediatelyCompletes() {
        let subject = SendablePassthroughSubject<Int, Never>()
        subject.send(completion: .finished)

        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())
        subject.send(99) // ignored

        #expect(collector.values.isEmpty)
        #expect(collector.completionCount == 1)
        if case .finished = collector.completion {
            // expected: new subscribers to an already-finished subject complete at once
        } else {
            Issue.record("Expected immediate .finished, got \(String(describing: collector.completion))")
        }
        collector.cancel()
    }

    // MARK: - Completion: failure

    @Test func failureCompletionDeliversError() {
        let subject = SendablePassthroughSubject<Int, TestError>()
        let collector = Collector<Int, TestError>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(10)
        subject.send(completion: .failure(.boom))
        subject.send(20) // ignored after completion

        #expect(collector.values == [10])
        #expect(collector.completionCount == 1)
        if case let .failure(err) = collector.completion {
            #expect(err == .boom)
        } else {
            Issue.record("Expected .failure(.boom), got \(String(describing: collector.completion))")
        }
        collector.cancel()
    }

    @Test func failureCarriesAssociatedValue() {
        let subject = SendablePassthroughSubject<String, TestError>()
        let collector = Collector<String, TestError>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(completion: .failure(.other(123)))

        if case let .failure(err) = collector.completion {
            #expect(err == .other(123))
        } else {
            Issue.record("Expected .failure(.other(123))")
        }
        collector.cancel()
    }

    @Test func failureWithExistentialErrorTypeRoundTrips() {
        // Exercise the `Failure == any Error` generic instantiation.
        let subject = SendablePassthroughSubject<Int, Error>()
        let collector = Collector<Int, Error>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(1)
        subject.send(completion: .failure(TestError.other(7)))

        #expect(collector.values == [1])
        if case let .failure(err) = collector.completion {
            #expect((err as? TestError) == .other(7))
        } else {
            Issue.record("Expected an existential .failure carrying TestError.other(7)")
        }
        collector.cancel()
    }

    @Test func firstCompletionWinsSecondIsIgnored() {
        let subject = SendablePassthroughSubject<Int, TestError>()
        let collector = Collector<Int, TestError>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(completion: .failure(.boom))
        // A second completion (even a different one) must not override the first.
        subject.send(completion: .finished)
        subject.send(completion: .failure(.other(9)))

        #expect(collector.completionCount == 1)
        if case let .failure(err) = collector.completion {
            #expect(err == .boom)
        } else {
            Issue.record("Expected the first completion (.failure(.boom)) to win")
        }
        collector.cancel()
    }

    // MARK: - Completion via async confirmation

    @Test func confirmationObservesFinishedCompletionExactlyOnce() async {
        let subject = SendablePassthroughSubject<Int, Never>()
        await confirmation("completion fires once", expectedCount: 1) { confirm in
            let cancellable = subject.eraseToAnyPublisher().sink(
                receiveCompletion: { completion in
                    if case .finished = completion { confirm() }
                },
                receiveValue: { _ in }
            )
            subject.send(completion: .finished)
            // Extra completion must NOT fire the confirmation again.
            subject.send(completion: .finished)
            cancellable.cancel()
        }
    }

    @Test func confirmationObservesFailureCompletionExactlyOnce() async {
        let subject = SendablePassthroughSubject<Int, TestError>()
        await confirmation("failure fires once", expectedCount: 1) { confirm in
            let cancellable = subject.eraseToAnyPublisher().sink(
                receiveCompletion: { completion in
                    if case .failure(.boom) = completion { confirm() }
                },
                receiveValue: { _ in }
            )
            subject.send(completion: .failure(.boom))
            subject.send(completion: .failure(.boom)) // ignored after first
            cancellable.cancel()
        }
    }

    @Test func confirmationObservesEachValueExactlyOnce() async {
        let subject = SendablePassthroughSubject<Int, Never>()
        await confirmation("three values", expectedCount: 3) { confirm in
            let cancellable = subject.eraseToAnyPublisher().sink { _ in confirm() }
            subject.send(1)
            subject.send(2)
            subject.send(3)
            cancellable.cancel()
        }
    }

    // MARK: - Cancellation

    @Test func cancelledSubscriberStopsReceivingValues() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(1)
        #expect(collector.values == [1])

        collector.cancel()
        subject.send(2)
        subject.send(3)

        // No further values after cancellation.
        #expect(collector.values == [1])
        #expect(collector.completion == nil)
    }

    @Test func cancellingOneSubscriberDoesNotAffectOthers() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let a = Collector<Int, Never>()
        let b = Collector<Int, Never>()
        a.subscribe(to: subject.eraseToAnyPublisher())
        b.subscribe(to: subject.eraseToAnyPublisher())

        subject.send(1)
        a.cancel()
        subject.send(2)

        #expect(a.values == [1])
        #expect(b.values == [1, 2])
        b.cancel()
    }

    // MARK: - Combine operator interop

    @Test func worksWithMapOperator() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<String, Never>()
        let mapped = subject.eraseToAnyPublisher()
            .map { "v=\($0)" }
            .eraseToAnyPublisher()
        collector.subscribe(to: mapped)

        subject.send(1)
        subject.send(2)

        #expect(collector.values == ["v=1", "v=2"])
        collector.cancel()
    }

    @Test func worksWithFilterOperator() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        let filtered = subject.eraseToAnyPublisher()
            .filter { $0 % 2 == 0 }
            .eraseToAnyPublisher()
        collector.subscribe(to: filtered)

        for i in 0..<10 { subject.send(i) }

        #expect(collector.values == [0, 2, 4, 6, 8])
        collector.cancel()
    }

    @Test func worksWithCollectUntilCompletion() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<[Int], Never>()
        let collected = subject.eraseToAnyPublisher()
            .collect()
            .eraseToAnyPublisher()
        collector.subscribe(to: collected)

        subject.send(1)
        subject.send(2)
        subject.send(3)
        // Before completion, .collect() has emitted nothing.
        #expect(collector.values.isEmpty)

        subject.send(completion: .finished)

        // .collect() emits the buffered array only at completion.
        #expect(collector.values == [[1, 2, 3]])
        collector.cancel()
    }

    // MARK: - Concurrency

    @Test func concurrentSendsDeliverAllValuesNoLoss() async {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let total = 1000
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                group.addTask {
                    subject.send(i)
                }
            }
        }

        let received = collector.values
        // No value should be lost; the lock serializes all sends.
        #expect(received.count == total)
        // Every index 0..<total must be present exactly once.
        #expect(Set(received) == Set(0..<total))
        #expect(collector.completion == nil)
        collector.cancel()
    }

    @Test func concurrentSendsFromManyTasksKeepCountConsistent() async {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let tasks = 100
        let perTask = 50
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<tasks {
                group.addTask {
                    for _ in 0..<perTask {
                        subject.send(1)
                    }
                }
            }
        }

        let received = collector.values
        #expect(received.count == tasks * perTask)
        #expect(received.allSatisfy { $0 == 1 })
        #expect(received.reduce(0, +) == tasks * perTask)
        collector.cancel()
    }

    @Test func concurrentSendsThenCompletionTerminatesCleanly() async {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let total = 500
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                group.addTask {
                    subject.send(i)
                }
            }
        }
        subject.send(completion: .finished)
        // Post-completion send must be ignored.
        subject.send(99999)

        let received = collector.values
        #expect(received.count == total)
        #expect(!received.contains(99999))
        #expect(collector.completionCount == 1)
        if case .finished = collector.completion {
            // expected
        } else {
            Issue.record("Expected .finished after concurrent sends")
        }
        collector.cancel()
    }

    @Test func sharingSubjectAcrossTasksIsSendable() async {
        // Verifies the @unchecked Sendable conformance lets the instance cross
        // task boundaries without data races at the lock level.
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        async let a: Void = {
            for i in 0..<200 { subject.send(i) }
        }()
        async let b: Void = {
            for i in 200..<400 { subject.send(i) }
        }()
        _ = await (a, b)

        let received = collector.values
        #expect(received.count == 400)
        #expect(Set(received) == Set(0..<400))
        collector.cancel()
    }

    @Test func concurrentSendsWithMultipleConcurrentSubscribers() async {
        // Several lock-guarded collectors observing the same subject while many
        // tasks send concurrently: each subscriber must see the full set.
        let subject = SendablePassthroughSubject<Int, Never>()
        let collectors = (0..<4).map { _ in Collector<Int, Never>() }
        for c in collectors { c.subscribe(to: subject.eraseToAnyPublisher()) }

        let total = 600
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                group.addTask { subject.send(i) }
            }
        }

        for c in collectors {
            let received = c.values
            #expect(received.count == total)
            #expect(Set(received) == Set(0..<total))
        }
        for c in collectors { c.cancel() }
    }

    // MARK: - Large data

    @Test func largeVolumeOfSendsIsDeliveredFully() {
        let subject = SendablePassthroughSubject<Int, Never>()
        let collector = Collector<Int, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let count = 100_000
        for i in 0..<count {
            subject.send(i)
        }

        let received = collector.values
        #expect(received.count == count)
        #expect(received.first == 0)
        #expect(received.last == count - 1)
        // Order is preserved exactly across the whole large run (spot-check).
        #expect(received[count / 2] == count / 2)
        collector.cancel()
    }

    @Test func largeStringPayloadDeliveredIntact() {
        let subject = SendablePassthroughSubject<String, Never>()
        let collector = Collector<String, Never>()
        collector.subscribe(to: subject.eraseToAnyPublisher())

        let big = String(repeating: "🎉a", count: 50_000)
        subject.send(big)

        #expect(collector.values.count == 1)
        #expect(collector.values.first == big)
        #expect(collector.values.first?.count == big.count)
        #expect(collector.values.first?.unicodeScalars.count == big.unicodeScalars.count)
        collector.cancel()
    }

    // MARK: - Reentrancy (NSRecursiveLock)

    @Test func reentrantSendFromWithinSinkDoesNotDeadlock() {
        // The implementation uses NSRecursiveLock, so a send triggered while the
        // current thread already holds the lock (re-entry via the sink callback)
        // must not deadlock. The re-entrant value must also be delivered.
        let subject = SendablePassthroughSubject<Int, Never>()
        var received: [Int] = []
        var reentrantSent = false

        let cancellable = subject.eraseToAnyPublisher().sink { value in
            received.append(value)
            // On the first value, synchronously re-enter send() while the
            // recursive lock is already held by the outer send(1).
            if value == 1 && !reentrantSent {
                reentrantSent = true
                subject.send(2)
            }
        }

        subject.send(1)

        #expect(reentrantSent)
        // Both the original and the re-entrant value reach the subscriber.
        #expect(received.contains(1))
        #expect(received.contains(2))
        #expect(received.count == 2)
        cancellable.cancel()
    }
}
