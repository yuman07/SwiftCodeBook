//
//  PublisherToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for:
//    Source/Tools/Extension/Foundation/Publisher+Tools.swift
//
//  Covers the two `Publisher` extension members:
//    - `sinkToResult(_:)`: maps received values to `.success`, `.failure`
//      completion to `.failure(error)`, and `.finished` completion to `nil`,
//      while returning a retaining `AnyCancellable`.
//    - `withPrevious()`: emits `(previous: Output?, current: Output)` tuples,
//      with `previous == nil` for the first element and the prior value
//      thereafter, forwarding the upstream `Failure`.
//

import Combine
import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct PublisherToolsTests {
    // MARK: - Helpers

    private enum SampleError: Error, Equatable {
        case boom
        case other
    }

    /// A Sendable, Equatable struct used to exercise non-primitive Output.
    private struct Point: Equatable, Sendable {
        var x: Int
        var y: Int
    }

    /// Drives `withPrevious()` on a finite sequence of values and returns the
    /// emitted (previous, current) pairs as a plain, comparable array.
    private func previousPairs<Value: Equatable>(
        from values: [Value]
    ) -> [(previous: Value?, current: Value)] {
        let subject = PassthroughSubject<Value, Never>()
        var collected: [(previous: Value?, current: Value)] = []
        let cancellable = subject
            .withPrevious()
            .sink(receiveValue: { collected.append($0) })
        for v in values {
            subject.send(v)
        }
        cancellable.cancel()
        return collected
    }

    // MARK: - sinkToResult: value mapping

    @Test func sinkToResultDeliversSuccessForValue() throws {
        let subject = PassthroughSubject<Int, SampleError>()
        var results: [Result<Int, SampleError>?] = []
        let cancellable = subject.sinkToResult { results.append($0) }
        subject.send(42)
        cancellable.cancel()

        #expect(results.count == 1)
        let first = try #require(results.first)
        let result = try #require(first)
        // Round-trip through Result.get() to assert the success payload.
        #expect(try result.get() == 42)
    }

    @Test func sinkToResultDeliversEachValueInOrder() {
        let subject = PassthroughSubject<Int, Never>()
        var values: [Int] = []
        let cancellable = subject.sinkToResult { result in
            if case .success(let v)? = result {
                values.append(v)
            } else {
                Issue.record("Unexpected non-success: \(String(describing: result))")
            }
        }
        subject.send(1)
        subject.send(2)
        subject.send(3)
        cancellable.cancel()
        #expect(values == [1, 2, 3])
    }

    // MARK: - sinkToResult: finished completion -> nil

    @Test func sinkToResultDeliversNilOnFinished() {
        let subject = PassthroughSubject<Int, Never>()
        var sawNil = false
        var nilCount = 0
        let cancellable = subject.sinkToResult { result in
            if result == nil {
                sawNil = true
                nilCount += 1
            }
        }
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(sawNil)
        #expect(nilCount == 1)
    }

    @Test func sinkToResultValuesThenNilOnFinished() {
        let subject = PassthroughSubject<String, Never>()
        // Encode each callback into a token sequence for an exact ordering check.
        var tokens: [String] = []
        let cancellable = subject.sinkToResult { result in
            switch result {
            case .none: tokens.append("FINISHED")
            case .success(let v)?: tokens.append("V:\(v)")
            case .failure?: tokens.append("FAILURE")
            }
        }
        subject.send("a")
        subject.send("b")
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(tokens == ["V:a", "V:b", "FINISHED"])
    }

    @Test func sinkToResultFinishedBeforeAnyValueEmitsSingleNil() {
        // No values, immediate finish: exactly one nil callback, nothing else.
        let subject = PassthroughSubject<Int, Never>()
        var tokens: [String] = []
        let cancellable = subject.sinkToResult { result in
            tokens.append(result == nil ? "FINISHED" : "VALUE")
        }
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(tokens == ["FINISHED"])
    }

    // MARK: - sinkToResult: failure completion -> .failure(error)

    @Test func sinkToResultDeliversFailure() throws {
        let subject = PassthroughSubject<Int, SampleError>()
        var captured: Result<Int, SampleError>?
        var callbackCount = 0
        let cancellable = subject.sinkToResult { result in
            callbackCount += 1
            captured = result
        }
        subject.send(completion: .failure(.boom))
        cancellable.cancel()

        #expect(callbackCount == 1)
        let result = try #require(captured)
        if case .failure(let error) = result {
            #expect(error == .boom)
        } else {
            Issue.record("Expected .failure(.boom), got \(String(describing: result))")
        }
    }

    @Test func sinkToResultValuesThenFailure() {
        let subject = PassthroughSubject<Int, SampleError>()
        var tokens: [String] = []
        let cancellable = subject.sinkToResult { result in
            switch result {
            case .none: tokens.append("FINISHED")
            case .success(let v)?: tokens.append("V:\(v)")
            case .failure(let e)?: tokens.append("F:\(e)")
            }
        }
        subject.send(7)
        subject.send(8)
        subject.send(completion: .failure(.other))
        cancellable.cancel()
        #expect(tokens == ["V:7", "V:8", "F:other"])
    }

    @Test func sinkToResultFailureSuppressesLaterValues() {
        // Once a completion is delivered Combine stops the stream; the closure
        // must not be invoked again for post-completion sends.
        let subject = PassthroughSubject<Int, SampleError>()
        var callbackCount = 0
        let cancellable = subject.sinkToResult { _ in callbackCount += 1 }
        subject.send(completion: .failure(.boom))
        subject.send(100)
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(callbackCount == 1)
    }

    @Test func sinkToResultFinishedSuppressesLaterValues() {
        // Symmetric to the failure case: a finished terminal also stops the stream.
        let subject = PassthroughSubject<Int, Never>()
        var callbackCount = 0
        let cancellable = subject.sinkToResult { _ in callbackCount += 1 }
        subject.send(completion: .finished)
        subject.send(100)
        cancellable.cancel()
        #expect(callbackCount == 1)
    }

    // MARK: - sinkToResult: Just / Empty / Fail one-shot publishers

    @Test func sinkToResultOnJustEmitsSuccessThenNil() {
        var tokens: [String] = []
        let cancellable = Just(99).sinkToResult { result in
            switch result {
            case .none: tokens.append("FINISHED")
            case .success(let v)?: tokens.append("V:\(v)")
            case .failure?: tokens.append("FAILURE")
            }
        }
        cancellable.cancel()
        // Just emits its value then finishes synchronously on subscribe.
        #expect(tokens == ["V:99", "FINISHED"])
    }

    @Test func sinkToResultOnEmptyEmitsOnlyNil() {
        var tokens: [String] = []
        let cancellable = Empty<Int, Never>().sinkToResult { result in
            tokens.append(result == nil ? "FINISHED" : "OTHER")
        }
        cancellable.cancel()
        #expect(tokens == ["FINISHED"])
    }

    @Test func sinkToResultOnNonCompletingEmptyEmitsNothing() {
        // Empty(completeImmediately: false) never sends value or completion,
        // so the closure must never be invoked.
        var count = 0
        let cancellable = Empty<Int, Never>(completeImmediately: false)
            .sinkToResult { _ in count += 1 }
        cancellable.cancel()
        #expect(count == 0)
    }

    @Test func sinkToResultOnFailEmitsOnlyFailure() throws {
        var captured: Result<Int, SampleError>?
        var count = 0
        let cancellable = Fail<Int, SampleError>(error: .boom).sinkToResult { result in
            count += 1
            captured = result
        }
        cancellable.cancel()
        #expect(count == 1)
        let result = try #require(captured)
        if case .failure(let e) = result {
            #expect(e == .boom)
        } else {
            Issue.record("Expected .failure(.boom), got \(String(describing: result))")
        }
    }

    // MARK: - sinkToResult: return value is a live, retaining cancellable

    @Test func sinkToResultCancellableStopsDelivery() {
        let subject = PassthroughSubject<Int, Never>()
        var values: [Int] = []
        let cancellable = subject.sinkToResult { result in
            if case .success(let v)? = result { values.append(v) }
        }
        subject.send(1)
        cancellable.cancel()
        subject.send(2)
        subject.send(3)
        #expect(values == [1])
    }

    @Test func sinkToResultStopsWhenCancellableDeallocates() {
        // Dropping the only reference to the AnyCancellable tears down the
        // subscription, so subsequent sends must not reach the closure.
        let subject = PassthroughSubject<Int, Never>()
        var values: [Int] = []
        do {
            let cancellable = subject.sinkToResult { result in
                if case .success(let v)? = result { values.append(v) }
            }
            subject.send(10)
            _ = cancellable // keep alive within scope
        }
        subject.send(20)
        #expect(values == [10])
    }

    // MARK: - sinkToResult: Output types & boundaries

    @Test func sinkToResultWithStructOutput() {
        let subject = PassthroughSubject<Point, Never>()
        var captured: Point?
        let cancellable = subject.sinkToResult { result in
            if case .success(let p)? = result { captured = p }
        }
        subject.send(Point(x: 3, y: -4))
        cancellable.cancel()
        #expect(captured == Point(x: 3, y: -4))
    }

    @Test(arguments: [Int.min, -1, 0, 1, Int.max])
    func sinkToResultPreservesExtremeIntegers(_ raw: Int) {
        let subject = PassthroughSubject<Int, Never>()
        var captured: Int?
        let cancellable = subject.sinkToResult { result in
            if case .success(let v)? = result { captured = v }
        }
        subject.send(raw)
        cancellable.cancel()
        #expect(captured == raw)
    }

    @Test func sinkToResultWithOptionalOutput() {
        let subject = PassthroughSubject<Int?, Never>()
        var tokens: [String] = []
        let cancellable = subject.sinkToResult { result in
            switch result {
            case .none: tokens.append("FINISHED")
            case .success(let v)?: tokens.append("V:\(String(describing: v))")
            case .failure?: tokens.append("FAILURE")
            }
        }
        subject.send(nil)
        subject.send(5)
        subject.send(completion: .finished)
        cancellable.cancel()
        // A `nil` *value* is still a .success(nil), distinct from .finished.
        #expect(tokens == ["V:nil", "V:Optional(5)", "FINISHED"])
    }

    @Test func sinkToResultWithUnicodeStrings() {
        let subject = PassthroughSubject<String, Never>()
        var captured: [String] = []
        let cancellable = subject.sinkToResult { result in
            if case .success(let v)? = result { captured.append(v) }
        }
        let emoji = "👩‍👩‍👧‍👦"
        let combining = "e\u{0301}"
        subject.send("")
        subject.send(emoji)
        subject.send(combining)
        cancellable.cancel()
        #expect(captured == ["", emoji, combining])
    }

    // MARK: - sinkToResult: large data, time-bounded

    @Test func sinkToResultHandlesManyValues() {
        let subject = PassthroughSubject<Int, Never>()
        var sum = 0
        var count = 0
        let cancellable = subject.sinkToResult { result in
            if case .success(let v)? = result {
                sum += v
                count += 1
            }
        }
        for i in 0..<100_000 {
            subject.send(i)
        }
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(count == 100_000)
        #expect(sum == (99_999 * 100_000) / 2)
    }

    // MARK: - sinkToResult: async delivery via confirmation

    @Test func sinkToResultDeliversValuesViaConfirmation() async {
        let subject = PassthroughSubject<Int, Never>()
        // Three values + one terminal nil (finished) == 4 callbacks.
        await confirmation(expectedCount: 4) { confirm in
            let cancellable = subject.sinkToResult { _ in confirm() }
            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(completion: .finished)
            cancellable.cancel()
        }
    }

    // MARK: - withPrevious: first emission has nil previous

    @Test func withPreviousFirstElementHasNilPrevious() {
        let pairs = previousPairs(from: [1])
        #expect(pairs.count == 1)
        #expect(pairs[0].previous == nil)
        #expect(pairs[0].current == 1)
    }

    @Test func withPreviousEmptyUpstreamEmitsNothing() {
        let pairs = previousPairs(from: [Int]())
        #expect(pairs.isEmpty)
    }

    @Test func withPreviousChainsConsecutivePairs() {
        let pairs = previousPairs(from: [10, 20, 30, 40])
        #expect(pairs.count == 4)
        #expect(pairs[0].previous == nil)
        #expect(pairs[0].current == 10)
        #expect(pairs[1].previous == 10)
        #expect(pairs[1].current == 20)
        #expect(pairs[2].previous == 20)
        #expect(pairs[2].current == 30)
        #expect(pairs[3].previous == 30)
        #expect(pairs[3].current == 40)
    }

    @Test func withPreviousRepeatedValues() {
        // Duplicate values still produce pairs; nothing is deduplicated.
        let pairs = previousPairs(from: [5, 5, 5])
        #expect(pairs.count == 3)
        #expect(pairs[0].previous == nil)
        #expect(pairs[1].previous == 5)
        #expect(pairs[1].current == 5)
        #expect(pairs[2].previous == 5)
        #expect(pairs[2].current == 5)
    }

    @Test func withPreviousWithStringValues() {
        let pairs = previousPairs(from: ["a", "b", "c"])
        #expect(pairs.count == 3)
        #expect(pairs[0].previous == nil && pairs[0].current == "a")
        #expect(pairs[1].previous == "a" && pairs[1].current == "b")
        #expect(pairs[2].previous == "b" && pairs[2].current == "c")
    }

    @Test func withPreviousWithStructValues() {
        let p0 = Point(x: 0, y: 0)
        let p1 = Point(x: 1, y: 1)
        let pairs = previousPairs(from: [p0, p1])
        #expect(pairs.count == 2)
        #expect(pairs[0].previous == nil && pairs[0].current == p0)
        #expect(pairs[1].previous == p0 && pairs[1].current == p1)
    }

    // MARK: - withPrevious: Optional Output (nil is a legitimate value)

    @Test func withPreviousWithOptionalOutput() {
        // When Output is itself Optional, a `nil` *value* must still flow
        // through (compactMap only filters the wrapping (Output?, Output)?
        // accumulator, never the inner Output). previous is Output? == Int??.
        let subject = PassthroughSubject<Int?, Never>()
        var tokens: [String] = []
        let cancellable = subject
            .withPrevious()
            .sink(receiveValue: { pair in
                let prev = pair.previous.map { String(describing: $0) } ?? "nilPrev"
                let cur = pair.current.map { String($0) } ?? "nilCur"
                tokens.append("\(prev)|\(cur)")
            })
        subject.send(nil)
        subject.send(1)
        subject.send(nil)
        cancellable.cancel()

        // 1st: previous accumulator absent -> outer .map yields nil -> "nilPrev"; current nil -> "nilCur".
        // 2nd: previous == Optional(Optional.none) -> describing the inner Int?.none yields "nil"; current 1.
        // 3rd: previous == Optional(Optional(1)) -> describing yields "Optional(1)"; current nil -> "nilCur".
        #expect(tokens == ["nilPrev|nilCur", "nil|1", "Optional(1)|nilCur"])
    }

    // MARK: - withPrevious: completion forwarding

    @Test func withPreviousForwardsFinished() {
        let subject = PassthroughSubject<Int, Never>()
        var finished = false
        var values: [Int] = []
        let cancellable = subject
            .withPrevious()
            .sink(
                receiveCompletion: { if case .finished = $0 { finished = true } },
                receiveValue: { values.append($0.current) }
            )
        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(values == [1, 2])
        #expect(finished)
    }

    @Test func withPreviousSingleValueThenFinished() {
        // Off-by-one boundary: one value yields exactly one (nil, v) pair, then finished.
        let subject = PassthroughSubject<Int, Never>()
        var pairs: [(previous: Int?, current: Int)] = []
        var finished = false
        let cancellable = subject
            .withPrevious()
            .sink(
                receiveCompletion: { if case .finished = $0 { finished = true } },
                receiveValue: { pairs.append($0) }
            )
        subject.send(42)
        subject.send(completion: .finished)
        cancellable.cancel()
        #expect(pairs.count == 1)
        #expect(pairs.first?.previous == nil)
        #expect(pairs.first?.current == 42)
        #expect(finished)
    }

    @Test func withPreviousForwardsFailure() {
        let subject = PassthroughSubject<Int, SampleError>()
        var captured: SampleError?
        var values: [Int] = []
        let cancellable = subject
            .withPrevious()
            .sink(
                receiveCompletion: { if case .failure(let e) = $0 { captured = e } },
                receiveValue: { values.append($0.current) }
            )
        subject.send(1)
        subject.send(completion: .failure(.boom))
        cancellable.cancel()
        #expect(values == [1])
        #expect(captured == .boom)
    }

    @Test func withPreviousFailureBeforeAnyValue() {
        let subject = PassthroughSubject<Int, SampleError>()
        var captured: SampleError?
        var valueCount = 0
        let cancellable = subject
            .withPrevious()
            .sink(
                receiveCompletion: { if case .failure(let e) = $0 { captured = e } },
                receiveValue: { _ in valueCount += 1 }
            )
        subject.send(completion: .failure(.other))
        cancellable.cancel()
        #expect(valueCount == 0)
        #expect(captured == .other)
    }

    @Test func withPreviousOnFailPublisherForwardsFailureWithoutValue() {
        // One-shot Fail through withPrevious(): no pair, only the failure.
        var captured: SampleError?
        var valueCount = 0
        let cancellable = Fail<Int, SampleError>(error: .boom)
            .withPrevious()
            .sink(
                receiveCompletion: { if case .failure(let e) = $0 { captured = e } },
                receiveValue: { _ in valueCount += 1 }
            )
        cancellable.cancel()
        #expect(valueCount == 0)
        #expect(captured == .boom)
    }

    // MARK: - withPrevious: erased type & operator composition

    @Test func withPreviousReturnsErasedPublisher() {
        // Verify the return type is usable as AnyPublisher and chains further.
        let subject = PassthroughSubject<Int, Never>()
        let erased: AnyPublisher<(previous: Int?, current: Int), Never> = subject.withPrevious()
        var deltas: [Int] = []
        let cancellable = erased
            .compactMap { pair -> Int? in
                guard let prev = pair.previous else { return nil }
                return pair.current - prev
            }
            .sink(receiveValue: { deltas.append($0) })
        subject.send(1)
        subject.send(4)
        subject.send(9)
        cancellable.cancel()
        // Deltas skip the first (nil previous): 4-1=3, 9-4=5.
        #expect(deltas == [3, 5])
    }

    @Test func withPreviousOnJustEmitsSinglePair() {
        var pairs: [(previous: Int?, current: Int)] = []
        let cancellable = Just(7)
            .withPrevious()
            .sink(receiveValue: { pairs.append($0) })
        cancellable.cancel()
        #expect(pairs.count == 1)
        #expect(pairs[0].previous == nil)
        #expect(pairs[0].current == 7)
    }

    @Test func withPreviousOnEmptyEmitsNoPair() {
        // Empty completes immediately with no value -> withPrevious emits nothing.
        var pairCount = 0
        var finished = false
        let cancellable = Empty<Int, Never>()
            .withPrevious()
            .sink(
                receiveCompletion: { if case .finished = $0 { finished = true } },
                receiveValue: { _ in pairCount += 1 }
            )
        cancellable.cancel()
        #expect(pairCount == 0)
        #expect(finished)
    }

    // MARK: - withPrevious: cancellation stops mid-stream

    @Test func withPreviousCancellationStopsDelivery() {
        let subject = PassthroughSubject<Int, Never>()
        var currents: [Int] = []
        let cancellable = subject
            .withPrevious()
            .sink(receiveValue: { currents.append($0.current) })
        subject.send(1)
        subject.send(2)
        cancellable.cancel()
        subject.send(3)
        subject.send(4)
        #expect(currents == [1, 2])
    }

    // MARK: - withPrevious: large data, time-bounded

    @Test func withPreviousHandlesManyValues() {
        let subject = PassthroughSubject<Int, Never>()
        var pairCount = 0
        var firstPreviousWasNil = false
        var lastPair: (previous: Int?, current: Int)?
        let cancellable = subject
            .withPrevious()
            .sink(receiveValue: { pair in
                if pairCount == 0 { firstPreviousWasNil = (pair.previous == nil) }
                pairCount += 1
                lastPair = pair
            })
        for i in 0..<100_000 {
            subject.send(i)
        }
        cancellable.cancel()
        #expect(pairCount == 100_000)
        #expect(firstPreviousWasNil)
        #expect(lastPair?.previous == 99_998)
        #expect(lastPair?.current == 99_999)
    }

    // MARK: - withPrevious: async delivery via confirmation

    @Test func withPreviousDeliversViaConfirmation() async {
        let subject = PassthroughSubject<Int, Never>()
        // Four sends produce four (previous, current) emissions.
        await confirmation(expectedCount: 4) { confirm in
            let cancellable = subject
                .withPrevious()
                .sink(receiveValue: { _ in confirm() })
            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(4)
            cancellable.cancel()
        }
    }

    // MARK: - Concurrency: independent streams hammered in parallel

    @Test func concurrentSinkToResultIndependentStreams() async {
        // Each task owns its own subject + subscription (nothing crosses task
        // boundaries), exercising the closure-capture path under contention.
        // Every stream must report exactly its single seeded value.
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    let subject = PassthroughSubject<Int, Never>()
                    var captured: Int?
                    let cancellable = subject.sinkToResult { result in
                        if case .success(let v)? = result { captured = v }
                    }
                    subject.send(i)
                    cancellable.cancel()
                    return captured == i
                }
            }
            var failures = 0
            for await ok in group where !ok { failures += 1 }
            #expect(failures == 0)
        }
    }

    @Test func concurrentWithPreviousIndependentStreams() async {
        // Each task builds an independent withPrevious() chain over two values
        // and verifies the (nil, a) then (a, b) invariant under parallelism.
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    let subject = PassthroughSubject<Int, Never>()
                    var pairs: [(previous: Int?, current: Int)] = []
                    let cancellable = subject
                        .withPrevious()
                        .sink(receiveValue: { pairs.append($0) })
                    subject.send(i)
                    subject.send(i + 1)
                    cancellable.cancel()
                    guard pairs.count == 2 else { return false }
                    return pairs[0].previous == nil
                        && pairs[0].current == i
                        && pairs[1].previous == i
                        && pairs[1].current == i + 1
                }
            }
            var failures = 0
            for await ok in group where !ok { failures += 1 }
            #expect(failures == 0)
        }
    }
}
