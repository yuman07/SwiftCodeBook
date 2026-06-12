//
//  CurrentValuePublisherTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for:
//    Source/Tools/Foundation/CurrentValuePublisher.swift
//
//  Covers the `CurrentValuePublisher` protocol, its conformances on
//  `CurrentValueSubject` / `Just` / `Published.Publisher` /
//  `NSObject.KeyValueObservingPublisher`, the `_getValue()` helper, the
//  `eraseToAnyCurrentValuePublisher()` convenience, and the
//  `AnyCurrentValuePublisher` type-eraser (all of its initializers,
//  `value`, and `receive(subscriber:)` republishing behavior).
//

import Combine
import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct CurrentValuePublisherTests {
    // MARK: - Helpers

    /// A minimal observable model used to exercise `Published.Publisher`.
    private final class Model: ObservableObject {
        @Published var count: Int = 0
        @Published var text: String = "initial"
    }

    /// KVO-observable NSObject for `KeyValueObservingPublisher`.
    @objc private final class KVOModel: NSObject {
        @objc dynamic var number: Int = 0
        @objc dynamic var name: String = "start"
    }

    private struct Point: Equatable {
        var x: Int
        var y: Int
    }

    private enum SampleError: Error, Equatable {
        case boom
    }

    /// Collects all values from a publisher synchronously by retaining the
    /// subscription for the duration of the `body` closure (which typically
    /// drives further `send(_:)` calls), then cancels.
    ///
    /// Combine delivers synchronously for `CurrentValueSubject` / `Just` on
    /// the calling thread, so there is no timing race and no sleeps are needed.
    private func collect<P: Publisher>(_ publisher: P, _ body: (inout [P.Output]) -> Void) -> [P.Output] {
        var values: [P.Output] = []
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { values.append($0) }
        )
        body(&values)
        cancellable.cancel()
        return values
    }

    /// Drives a publisher, capturing both values and completion synchronously.
    private func drain<P: Publisher>(
        _ publisher: P,
        _ body: () -> Void
    ) -> (values: [P.Output], completion: Subscribers.Completion<P.Failure>?) {
        var values: [P.Output] = []
        var completion: Subscribers.Completion<P.Failure>?
        let cancellable = publisher.sink(
            receiveCompletion: { completion = $0 },
            receiveValue: { values.append($0) }
        )
        body()
        cancellable.cancel()
        return (values, completion)
    }

    // MARK: - CurrentValueSubject.value (its own stored property)

    @Test func currentValueSubjectExposesValue() {
        let subject = CurrentValueSubject<Int, Never>(7)
        // CurrentValueSubject has its own `value`; conformance just declares it.
        #expect(subject.value == 7)
        subject.value = 99
        #expect(subject.value == 99)
        subject.send(123)
        #expect(subject.value == 123)
    }

    @Test func currentValueSubjectConformsToProtocol() {
        let subject = CurrentValueSubject<String, Never>("hello")
        // Use it through the protocol generic surface.
        func currentValue<P: CurrentValuePublisher>(_ p: P) -> P.Output { p.value }
        #expect(currentValue(subject) == "hello")
    }

    // MARK: - Just.value (via _getValue / Failure == Never extension)

    @Test(arguments: [Int.min, -1, 0, 1, 42, Int.max])
    func justValueReturnsWrappedValue(_ raw: Int) {
        let just = Just(raw)
        #expect(just.value == raw)
        // Reading twice must be stable (each read re-subscribes / re-replays).
        #expect(just.value == raw)
    }

    @Test func justValueWithStringAndUnicode() {
        #expect(Just("").value == "")
        #expect(Just("a").value == "a")
        // Emoji ZWJ sequence plus a decomposed combining mark: must round-trip
        // byte-for-byte without normalization surprises.
        let emoji = "👩‍👩‍👧‍👦é\u{0301}"
        #expect(Just(emoji).value == emoji)
        #expect(Just(emoji).value.unicodeScalars.count == emoji.unicodeScalars.count)
    }

    @Test func justValueWithReferenceAndOptional() {
        let optional: Int? = nil
        #expect(Just(optional).value == nil)
        let some: Int? = 5
        #expect(Just(some).value == 5)
    }

    @Test func justValueWithDoubleTolerance() {
        // Float comparison uses a tolerance rather than exact equality.
        let just = Just(0.1 + 0.2)
        #expect(abs(just.value - 0.3) < 1e-9)
    }

    @Test func justValueWithEmptyAndSingleCollection() {
        #expect(Just([Int]())._getValue().isEmpty)
        let single: [Int] = [42]
        #expect(Just(single)._getValue() == single)
    }

    // MARK: - _getValue() helper directly

    @Test func getValueReturnsFirstEmittedValue() {
        // CurrentValueSubject emits its current value immediately on subscribe,
        // so _getValue() must observe exactly that.
        let subject = CurrentValueSubject<Int, Never>(314)
        #expect(subject._getValue() == 314)
        subject.send(271)
        #expect(subject._getValue() == 271)
    }

    @Test func getValueOnJust() {
        #expect(Just(true)._getValue() == true)
        let array: [Int] = [1, 2, 3]
        #expect(Just(array)._getValue() == array)
    }

    @Test func getValueOnPublishedPublisher() {
        let model = Model()
        #expect(model.$count._getValue() == 0)
        model.count = -17
        #expect(model.$count._getValue() == -17)
    }

    @Test func getValueOnKVOPublisher() {
        let obj = KVOModel()
        let publisher = obj.publisher(for: \.number, options: [.initial, .new])
        #expect(publisher._getValue() == 0)
        obj.number = 99
        #expect(publisher._getValue() == 99)
    }

    // MARK: - Published.Publisher.value

    @Test func publishedPublisherValueReflectsCurrent() {
        let model = Model()
        #expect(model.$count.value == 0)
        model.count = 88
        #expect(model.$count.value == 88)
        // Boundary values through the @Published wrapper.
        model.count = Int.max
        #expect(model.$count.value == Int.max)
        model.count = Int.min
        #expect(model.$count.value == Int.min)
    }

    @Test func publishedPublisherValueString() {
        let model = Model()
        #expect(model.$text.value == "initial")
        model.text = "updated"
        #expect(model.$text.value == "updated")
    }

    // MARK: - KeyValueObservingPublisher.value

    @Test func kvoPublisherValueReflectsCurrent() {
        let obj = KVOModel()
        let publisher = obj.publisher(for: \.number, options: [.initial, .new])
        #expect(publisher.value == 0)
        obj.number = 555
        #expect(publisher.value == 555)
    }

    @Test func kvoPublisherValueString() {
        let obj = KVOModel()
        let publisher = obj.publisher(for: \.name, options: [.initial, .new])
        #expect(publisher.value == "start")
        obj.name = "renamed"
        #expect(publisher.value == "renamed")
    }

    // MARK: - eraseToAnyCurrentValuePublisher()

    @Test func eraseToAnyCurrentValuePublisherPreservesValue() {
        let subject = CurrentValueSubject<Int, Never>(11)
        let erased: AnyCurrentValuePublisher<Int, Never> = subject.eraseToAnyCurrentValuePublisher()
        #expect(erased.value == 11)
        subject.send(22)
        #expect(erased.value == 22)
    }

    @Test func eraseToAnyCurrentValuePublisherRepublishes() {
        let subject = CurrentValueSubject<Int, Never>(1)
        let erased = subject.eraseToAnyCurrentValuePublisher()
        let received = collect(erased) { _ in
            subject.send(2)
            subject.send(3)
        }
        // Current value (1) emitted on subscribe, then 2, 3.
        #expect(received == [1, 2, 3])
    }

    @Test func eraseToAnyCurrentValuePublisherOnJust() {
        let erased = Just("x").eraseToAnyCurrentValuePublisher()
        #expect(erased.value == "x")
        let received = collect(erased) { _ in }
        #expect(received == ["x"])
    }

    @Test func eraseToAnyCurrentValuePublisherOnPublished() {
        let model = Model()
        let erased = model.$count.eraseToAnyCurrentValuePublisher()
        #expect(erased.value == 0)
        let received = collect(erased) { _ in
            model.count = 5
            model.count = 6
        }
        // @Published replays its current value on subscribe, then forwards.
        #expect(received == [0, 5, 6])
        #expect(erased.value == 6)
    }

    @Test func eraseToAnyCurrentValuePublisherReErasure() {
        // Erasing an already-erased publisher must keep value + stream intact.
        let subject = CurrentValueSubject<Int, Never>(42)
        let once = subject.eraseToAnyCurrentValuePublisher()
        let twice = once.eraseToAnyCurrentValuePublisher()
        #expect(twice.value == 42)
        let received = collect(twice) { _ in subject.send(43) }
        #expect(received == [42, 43])
    }

    // MARK: - AnyCurrentValuePublisher: passthrough init (Root.Output == Output)

    @Test func anyPublisherPassthroughValue() {
        let subject = CurrentValueSubject<Int, Never>(100)
        let any = AnyCurrentValuePublisher(subject)
        #expect(any.value == 100)
        subject.value = 200
        #expect(any.value == 200)
    }

    @Test func anyPublisherPassthroughRepublishes() {
        let subject = CurrentValueSubject<String, Never>("a")
        let any = AnyCurrentValuePublisher(subject)
        let received = collect(any) { _ in
            subject.send("b")
            subject.send("c")
        }
        #expect(received == ["a", "b", "c"])
    }

    // MARK: - AnyCurrentValuePublisher: transform init

    @Test func anyPublisherTransformValue() {
        let subject = CurrentValueSubject<Int, Never>(3)
        let any = AnyCurrentValuePublisher(subject) { $0 * 10 }
        #expect(any.value == 30)
        subject.value = 4
        #expect(any.value == 40)
    }

    @Test func anyPublisherTransformRepublishes() {
        let subject = CurrentValueSubject<Int, Never>(1)
        let any = AnyCurrentValuePublisher(subject) { "n=\($0)" }
        let received = collect(any) { _ in
            subject.send(2)
            subject.send(3)
        }
        #expect(received == ["n=1", "n=2", "n=3"])
    }

    @Test func anyPublisherTransformChangesType() {
        let subject = CurrentValueSubject<String, Never>("hello")
        let any = AnyCurrentValuePublisher(subject) { $0.count }
        #expect(any.value == 5)
        subject.value = ""
        #expect(any.value == 0)
    }

    @Test func anyPublisherTransformToFloatingPoint() {
        // Type-changing transform producing a Double; assert with tolerance.
        let subject = CurrentValueSubject<Int, Never>(10)
        let any = AnyCurrentValuePublisher(subject) { Double($0) / 3.0 }
        #expect(abs(any.value - 3.3333333333) < 1e-6)
        subject.value = 0
        #expect(abs(any.value - 0.0) < 1e-9)
    }

    // MARK: - AnyCurrentValuePublisher: keyPath init

    @Test func anyPublisherKeyPathValue() {
        let subject = CurrentValueSubject<Point, Never>(Point(x: 1, y: 2))
        let any = AnyCurrentValuePublisher(subject, keyPath: \.x)
        #expect(any.value == 1)
        subject.value = Point(x: 9, y: 8)
        #expect(any.value == 9)
    }

    @Test func anyPublisherKeyPathRepublishes() {
        let subject = CurrentValueSubject<Point, Never>(Point(x: 0, y: 0))
        let any = AnyCurrentValuePublisher(subject, keyPath: \.y)
        let received = collect(any) { _ in
            subject.send(Point(x: 1, y: 10))
            subject.send(Point(x: 2, y: 20))
        }
        #expect(received == [0, 10, 20])
    }

    // MARK: - AnyCurrentValuePublisher: unsafeSubject inits

    @Test func anyPublisherUnsafeSubjectPassthrough() {
        let subject = CurrentValueSubject<Int, Never>(42)
        let any = AnyCurrentValuePublisher(unsafeSubject: subject, value: { subject.value })
        #expect(any.value == 42)
        subject.value = 7
        #expect(any.value == 7)
        let received = collect(any) { _ in subject.send(8) }
        #expect(received == [7, 8])
    }

    @Test func anyPublisherUnsafeSubjectWithTransform() {
        let subject = CurrentValueSubject<Int, Never>(5)
        let any = AnyCurrentValuePublisher(
            unsafeSubject: subject,
            value: { subject.value * 2 },
            transform: { $0 * 2 }
        )
        #expect(any.value == 10)
        subject.value = 6
        #expect(any.value == 12)
        let received = collect(any) { _ in subject.send(7) }
        #expect(received == [12, 14])
    }

    @Test func anyPublisherUnsafeSubjectFromArbitraryPublisher() {
        // unsafeSubject permits non-CurrentValuePublisher upstreams; `value` is
        // supplied explicitly and is decoupled from the stream.
        let passthrough = PassthroughSubject<Int, Never>()
        let any = AnyCurrentValuePublisher(unsafeSubject: passthrough, value: { -1 })
        #expect(any.value == -1)
        let received = collect(any) { _ in
            passthrough.send(10)
            passthrough.send(20)
        }
        // PassthroughSubject does not replay; only post-subscribe values appear.
        #expect(received == [10, 20])
        // value remains the constant supplied to the initializer.
        #expect(any.value == -1)
    }

    @Test func anyPublisherUnsafeSubjectTransformDecoupledFromStreamValue() {
        // The `value` closure can be entirely independent of upstream content:
        // here `value` reads a separate counter while the stream maps upstream.
        var counter = 0
        let passthrough = PassthroughSubject<Int, Never>()
        let any = AnyCurrentValuePublisher(
            unsafeSubject: passthrough,
            value: { counter },
            transform: { $0 + 1000 }
        )
        #expect(any.value == 0)
        counter = 5
        #expect(any.value == 5)
        let received = collect(any) { _ in
            passthrough.send(1)
            passthrough.send(2)
        }
        #expect(received == [1001, 1002])
        // value still tracks the external counter, not the stream.
        #expect(any.value == 5)
    }

    // MARK: - Failure != Never path

    @Test func anyPublisherWithFailureType() {
        let subject = CurrentValueSubject<Int, SampleError>(0)
        let any = AnyCurrentValuePublisher(subject)
        #expect(any.value == 0)
        subject.value = 5
        #expect(any.value == 5)

        let (values, completion) = drain(any) {
            subject.send(6)
            subject.send(completion: .failure(.boom))
        }

        #expect(values == [5, 6])
        if case .failure(let err) = completion {
            #expect(err == .boom)
        } else {
            Issue.record("Expected failure completion, got \(String(describing: completion))")
        }
    }

    @Test func anyPublisherFinishCompletionForwarded() {
        let subject = CurrentValueSubject<Int, Never>(1)
        let any = AnyCurrentValuePublisher(subject)
        let (values, completion) = drain(any) {
            subject.send(completion: .finished)
        }
        #expect(values == [1])
        if case .finished = completion {
            // expected
        } else {
            Issue.record("Expected finished completion, got \(String(describing: completion))")
        }
    }

    @Test func anyPublisherTransformForwardsFailure() {
        // Transform path must forward both mapped values and the failure.
        let subject = CurrentValueSubject<Int, SampleError>(1)
        let any = AnyCurrentValuePublisher(subject) { $0 * 100 }
        #expect(any.value == 100)
        let (values, completion) = drain(any) {
            subject.send(2)
            subject.send(completion: .failure(.boom))
        }
        #expect(values == [100, 200])
        if case .failure(let err) = completion {
            #expect(err == .boom)
        } else {
            Issue.record("Expected failure completion, got \(String(describing: completion))")
        }
    }

    @Test func anyPublisherKeyPathForwardsFailure() {
        let subject = CurrentValueSubject<Point, SampleError>(Point(x: 7, y: 0))
        let any = AnyCurrentValuePublisher(subject, keyPath: \.x)
        #expect(any.value == 7)
        let (values, completion) = drain(any) {
            subject.send(Point(x: 8, y: 0))
            subject.send(completion: .failure(.boom))
        }
        #expect(values == [7, 8])
        if case .failure(.boom) = completion {
            // expected
        } else {
            Issue.record("Expected .failure(.boom), got \(String(describing: completion))")
        }
    }

    // MARK: - Multiple subscribers

    @Test func anyPublisherSupportsMultipleSubscribers() {
        let subject = CurrentValueSubject<Int, Never>(0)
        let any = AnyCurrentValuePublisher(subject)

        var a: [Int] = []
        var b: [Int] = []
        let ca = any.sink(receiveValue: { a.append($0) })
        let cb = any.sink(receiveValue: { b.append($0) })
        subject.send(1)
        subject.send(2)
        ca.cancel()
        cb.cancel()

        #expect(a == [0, 1, 2])
        #expect(b == [0, 1, 2])
    }

    @Test func anyPublisherCancellationStopsDelivery() {
        // After cancel, later sends must NOT be observed.
        let subject = CurrentValueSubject<Int, Never>(0)
        let any = AnyCurrentValuePublisher(subject)
        var received: [Int] = []
        let cancellable = any.sink(receiveValue: { received.append($0) })
        subject.send(1)
        cancellable.cancel()
        subject.send(2)
        subject.send(3)
        #expect(received == [0, 1])
    }

    // MARK: - Combine operator chaining on AnyCurrentValuePublisher

    @Test func anyPublisherChainsWithOperators() {
        let subject = CurrentValueSubject<Int, Never>(1)
        let any = AnyCurrentValuePublisher(subject)
        var received: [Int] = []
        let cancellable = any
            .filter { $0 % 2 == 0 }
            .sink(receiveValue: { received.append($0) })
        subject.send(2)
        subject.send(3)
        subject.send(4)
        cancellable.cancel()
        #expect(received == [2, 4])
    }

    @Test func anyPublisherMapAndRemoveDuplicates() {
        let subject = CurrentValueSubject<Int, Never>(1)
        let any = AnyCurrentValuePublisher(subject)
        var received: [Int] = []
        let cancellable = any
            .map { $0 * 2 }
            .removeDuplicates()
            .sink(receiveValue: { received.append($0) })
        subject.send(1) // duplicate of current 1 -> 2 collapses
        subject.send(2)
        subject.send(2)
        subject.send(3)
        cancellable.cancel()
        // 1 (->2), dup 1 dropped, 2 (->4), dup 2 dropped, 3 (->6).
        #expect(received == [2, 4, 6])
    }

    // MARK: - Concurrency

    @Test func concurrentValueReadsAreConsistent() async {
        // Each task builds its OWN subject + eraser (nothing crosses the task
        // boundary), exercising the `value` read path from many threads at
        // once. Every read must return the seeded constant.
        let bad = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    let subject = CurrentValueSubject<Int, Never>(777)
                    return subject.eraseToAnyCurrentValuePublisher().value
                }
            }
            var bad = 0
            for await v in group where v != 777 {
                bad += 1
            }
            return bad
        }
        #expect(bad == 0)
    }

    @Test func concurrentGetValueReads() async {
        // Hammer the `_getValue()` synchronous-first-value path concurrently,
        // each task with an independent Just instance.
        let sum = await withTaskGroup(of: Int.self) { group in
            for i in 0..<500 {
                group.addTask { Just(i)._getValue() }
            }
            var sum = 0
            for await v in group {
                sum += v
            }
            return sum
        }
        // Sum of 0..<500 == 499 * 500 / 2.
        #expect(sum == 499 * 500 / 2)
    }

    @Test func concurrentSharedSubjectReadsAndWrites() async {
        // Hammer a single shared subject. CurrentValueSubject is not Sendable
        // under strict concurrency, but its value access is internally locked;
        // nonisolated(unsafe) is the idiomatic test escape hatch. We assert no
        // crash and a deterministic terminal value after an ordered final send.
        nonisolated(unsafe) let subject = CurrentValueSubject<Int, Never>(0)
        await withTaskGroup(of: Int.self) { group in
            for i in 1...1000 {
                group.addTask {
                    subject.send(i)
                    return subject.value
                }
            }
            for await _ in group {}
        }
        // A final, ordered send pins the terminal value deterministically.
        subject.send(-1)
        #expect(subject.value == -1)
        #expect(subject._getValue() == -1)
    }

    @Test func concurrentTransformErasureReads() async {
        // Stress the transform-init `value` path under concurrency, each task
        // with its own subject + eraser so nothing escapes the task boundary.
        let bad = await withTaskGroup(of: Int.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    let subject = CurrentValueSubject<Int, Never>(i)
                    let any = AnyCurrentValuePublisher(subject) { $0 * 2 }
                    return any.value
                }
            }
            var bad = 0
            for await v in group where v % 2 != 0 {
                bad += 1
            }
            return bad
        }
        #expect(bad == 0)
    }

    // MARK: - Large data

    @Test func largeCollectionValueRoundTrip() {
        let big = Array(0..<100_000)
        let just = Just(big)
        let read = just.value
        #expect(read.count == 100_000)
        #expect(read.first == 0)
        #expect(read.last == 99_999)
    }

    @Test func longStringTransform() {
        let long = String(repeating: "x", count: 100_000)
        let subject = CurrentValueSubject<String, Never>(long)
        let any = AnyCurrentValuePublisher(subject, keyPath: \.count)
        #expect(any.value == 100_000)
    }

    @Test func manyBoundedSendsRepublishInOrder() {
        // Bounded burst of sends must replay current + all subsequent in order.
        let subject = CurrentValueSubject<Int, Never>(0)
        let any = AnyCurrentValuePublisher(subject)
        let received = collect(any) { _ in
            for i in 1...5_000 {
                subject.send(i)
            }
        }
        #expect(received.count == 5_001)
        #expect(received.first == 0)
        #expect(received.last == 5_000)
        #expect(received == Array(0...5_000))
    }

    // MARK: - Async republish via confirmation

    @Test func anyPublisherDeliversValuesViaConfirmation() async {
        let subject = CurrentValueSubject<Int, Never>(0)
        let any = AnyCurrentValuePublisher(subject) { $0 + 1 }
        // Initial replayed value (0 -> 1) plus two sends -> 3 deliveries total.
        await confirmation(expectedCount: 3) { confirm in
            let cancellable = any.sink(receiveValue: { _ in confirm() })
            subject.send(10)
            subject.send(20)
            cancellable.cancel()
        }
    }
}
