//
//  ResultToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Extension/Foundation/Result+Tools.swift
//
//  The source adds three pure, synchronous computed properties to the standard
//  library `Result`:
//
//    var isSuccess: Bool       // true on .success, false on .failure
//    var value: Success?       // the success payload, or nil on .failure
//    var error: Failure?       // the failure value, or nil on .success
//
//  Because the accessors are pure and value-typed, the concurrency tests are
//  deterministic and bounded (no sleeps, no timing races). Reference types are
//  modelled with an immutable, Sendable `Box` so they can be captured across
//  tasks under Swift 6 strict concurrency.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct ResultToolsTests {

    // MARK: - Test support types

    /// A small Equatable + Sendable error used across most failure tests.
    private enum SampleError: Error, Equatable, Sendable {
        case boom
        case withCode(Int)
        case message(String)
    }

    /// A struct error to exercise non-enum Failure types.
    private struct StructError: Error, Equatable, Sendable {
        let code: Int
        let reason: String
    }

    /// An immutable reference type used to assert identity (===) semantics of
    /// the `value` accessor. Marked Sendable (only an immutable `let`) so it can
    /// cross task boundaries under strict concurrency.
    private final class Box: Sendable, Equatable {
        let id: Int
        init(_ id: Int) { self.id = id }
        static func == (lhs: Box, rhs: Box) -> Bool { lhs.id == rhs.id }
    }

    // MARK: - isSuccess

    @Test func isSuccessTrueOnSuccess() {
        let r: Result<Int, SampleError> = .success(42)
        #expect(r.isSuccess)
    }

    @Test func isSuccessFalseOnFailure() {
        let r: Result<Int, SampleError> = .failure(.boom)
        #expect(!r.isSuccess)
    }

    @Test func isSuccessWithVoidSuccess() {
        let ok: Result<Void, SampleError> = .success(())
        let bad: Result<Void, SampleError> = .failure(.boom)
        #expect(ok.isSuccess)
        #expect(!bad.isSuccess)
    }

    // MARK: - value: happy path & nil-on-failure

    @Test func valueReturnsPayloadOnSuccess() {
        let r: Result<String, SampleError> = .success("hello")
        #expect(r.value == "hello")
    }

    @Test func valueIsNilOnFailure() {
        let r: Result<String, SampleError> = .failure(.boom)
        #expect(r.value == nil)
    }

    // MARK: - error: happy path & nil-on-success

    @Test func errorReturnsFailureOnFailure() {
        let r: Result<Int, SampleError> = .failure(.withCode(7))
        #expect(r.error == .withCode(7))
    }

    @Test func errorIsNilOnSuccess() {
        let r: Result<Int, SampleError> = .success(1)
        #expect(r.error == nil)
    }

    // MARK: - Exactly-one-non-nil invariant (parameterized over both cases)

    @Test(arguments: [true, false])
    func exactlyOneOfValueOrErrorIsNonNil(_ succeed: Bool) {
        let r: Result<Int, SampleError> = succeed ? .success(99) : .failure(.boom)
        if succeed {
            #expect(r.isSuccess)
            #expect(r.value != nil)
            #expect(r.error == nil)
        } else {
            #expect(!r.isSuccess)
            #expect(r.value == nil)
            #expect(r.error != nil)
        }
        // The two accessors are mutually exclusive: never both set, never both nil.
        let valueSet = r.value != nil
        let errorSet = r.error != nil
        #expect(valueSet != errorSet)
    }

    // MARK: - Int boundary round-trips

    @Test(arguments: [Int.min, -1, 0, 1, Int.max])
    func intBoundaryRoundTrips(_ n: Int) {
        let r: Result<Int, SampleError> = .success(n)
        #expect(r.value == n)
        #expect(r.isSuccess)
        #expect(r.error == nil)
    }

    @Test(arguments: [Int.min, -1, 0, 1, Int.max])
    func intFailureCarriesCode(_ n: Int) {
        let r: Result<Int, SampleError> = .failure(.withCode(n))
        #expect(r.value == nil)
        #expect(r.error == .withCode(n))
        #expect(!r.isSuccess)
    }

    // MARK: - String round-trips (empty, single, unicode, multiline)

    @Test(arguments: [
        "",
        "a",
        "Hello, world",
        "😀",                 // single emoji scalar pair
        "👨‍👩‍👧‍👦",            // ZWJ family sequence
        "e\u{0301}",          // combining acute accent
        "café",
        "中文字符",
        "line1\nline2\nline3", // multiline
        "  leading/trailing  ",
        String(repeating: "x", count: 10_000),
    ])
    func stringRoundTrips(_ s: String) {
        let r: Result<String, SampleError> = .success(s)
        #expect(r.value == s)
        #expect(r.isSuccess)
    }

    @Test(arguments: ["", "💥", "boundary message"])
    func stringErrorMessageRoundTrips(_ msg: String) {
        let r: Result<Int, SampleError> = .failure(.message(msg))
        #expect(r.error == .message(msg))
        #expect(r.value == nil)
    }

    // MARK: - Double specials

    @Test func doubleNaNSuccess() {
        let r: Result<Double, SampleError> = .success(.nan)
        // NaN != NaN, so compare via isNaN rather than ==.
        #expect(r.value?.isNaN == true)
        #expect(r.isSuccess)
    }

    @Test func doubleInfinities() {
        let pos: Result<Double, SampleError> = .success(.infinity)
        let neg: Result<Double, SampleError> = .success(-.infinity)
        #expect(pos.value == .infinity)
        #expect(neg.value == -.infinity)
    }

    @Test func doubleZeros() {
        let positiveZero: Result<Double, SampleError> = .success(0.0)
        let negativeZero: Result<Double, SampleError> = .success(-0.0)
        #expect(positiveZero.value == 0.0)
        #expect(negativeZero.value == 0.0)
        // Distinguish the two zeros by sign bit, which the accessor must preserve.
        #expect(positiveZero.value?.sign == .plus)
        #expect(negativeZero.value?.sign == .minus)
    }

    // MARK: - Array payloads (empty & large-but-bounded)

    @Test func emptyArrayPayload() {
        let r: Result<[Int], SampleError> = .success([])
        #expect(r.value == [])
        #expect(r.value?.isEmpty == true)
        #expect(r.isSuccess)
    }

    @Test func largeArrayPayloadRoundTrips() {
        let big = Array(0..<100_000)
        let r: Result<[Int], SampleError> = .success(big)
        #expect(r.value?.count == 100_000)
        #expect(r.value?.first == 0)
        #expect(r.value?.last == 99_999)
        #expect(r.value == big)
    }

    // MARK: - Reference-type identity

    @Test func valuePreservesReferenceIdentity() {
        let box = Box(7)
        let r: Result<Box, SampleError> = .success(box)
        // Identity must be preserved, not just equality.
        #expect(r.value === box)
        #expect(r.value == box)
    }

    @Test func distinctBoxesAreNotIdentical() {
        let a = Box(1)
        let b = Box(1) // equal by value, distinct by identity
        let r: Result<Box, SampleError> = .success(a)
        #expect(r.value === a)
        #expect(!(r.value === b))
        #expect(r.value == b) // still equal by ==
    }

    // MARK: - Double-optional: Success is itself Optional

    @Test func optionalSuccessSomeValueIsDoubleSome() {
        let r: Result<Int?, SampleError> = .success(5)
        // value has type Int??. On success it is .some(.some(5)).
        let v: Int?? = r.value
        #expect(v != nil)          // outer optional is non-nil (it's a success)
        #expect(v! == 5)           // inner optional carries 5
    }

    @Test func optionalSuccessNilIsSomeNoneNotFailure() {
        let r: Result<Int?, SampleError> = .success(nil)
        let v: Int?? = r.value
        // Tricky: .success(nil) must yield .some(.none), i.e. the OUTER optional
        // is non-nil (we did succeed) but the inner payload is nil.
        #expect(v != nil)          // outer optional non-nil: this was a success
        #expect(v! == nil)         // inner payload is nil
        #expect(r.isSuccess)
        #expect(r.error == nil)
    }

    @Test func optionalSuccessFailureIsOuterNil() {
        let r: Result<Int?, SampleError> = .failure(.boom)
        let v: Int?? = r.value
        // On failure the OUTER optional is nil, distinguishing it from
        // .success(nil) above which produced .some(.none).
        #expect(v == nil)
        #expect(r.error == .boom)
    }

    // MARK: - error round-trips over varied Failure types

    @Test func errorBoomRoundTrip() {
        let r: Result<Int, SampleError> = .failure(.boom)
        #expect(r.error == .boom)
    }

    @Test(arguments: [0, -1, Int.max, Int.min, 42])
    func errorWithCodeRoundTrip(_ code: Int) {
        let r: Result<Int, SampleError> = .failure(.withCode(code))
        #expect(r.error == .withCode(code))
    }

    @Test func structErrorRoundTrip() {
        let err = StructError(code: 503, reason: "unavailable")
        let r: Result<Int, StructError> = .failure(err)
        #expect(r.error == err)
        #expect(r.value == nil)
    }

    @Test func nsErrorRoundTrip() {
        let nsError = NSError(domain: "MyDomain", code: 99, userInfo: nil)
        let r: Result<Int, NSError> = .failure(nsError)
        #expect(r.error?.domain == "MyDomain")
        #expect(r.error?.code == 99)
        #expect(r.value == nil)
    }

    @Test func anyErrorExistentialShapeWithDowncast() throws {
        let r: Result<Int, any Error> = .failure(SampleError.message("oops"))
        // r.error has type (any Error)?; #require unwraps to `any Error`.
        let err: any Error = try #require(r.error)
        #expect((err as? SampleError) == .message("oops"))
        #expect(r.value == nil)
    }

    // MARK: - Cross-checks against stdlib get()

    @Test func valueMatchesGetOnSuccess() throws {
        let r: Result<Int, SampleError> = .success(123)
        let viaGet = try r.get()
        #expect(r.value == viaGet)
    }

    @Test func getThrowsOnFailureWhileValueIsNil() {
        let r: Result<Int, SampleError> = .failure(.boom)
        #expect(r.value == nil)
        #expect(throws: SampleError.boom) {
            _ = try r.get()
        }
    }

    @Test func getSucceedsWhenIsSuccess() throws {
        let r: Result<String, SampleError> = .success("ok")
        #expect(r.isSuccess)
        #expect(try r.get() == "ok")
    }

    // MARK: - Accessors preserve semantics through map / mapError

    @Test func mapPreservesValueAccessor() {
        let r: Result<Int, SampleError> = .success(10)
        let mapped = r.map { $0 * 2 }
        #expect(mapped.value == 20)
        #expect(mapped.isSuccess)
        #expect(mapped.error == nil)
    }

    @Test func mapOnFailureLeavesErrorIntact() {
        let r: Result<Int, SampleError> = .failure(.withCode(5))
        let mapped = r.map { $0 * 2 }
        #expect(mapped.value == nil)
        #expect(mapped.error == .withCode(5))
        #expect(!mapped.isSuccess)
    }

    @Test func mapErrorPreservesErrorAccessor() {
        let r: Result<Int, SampleError> = .failure(.boom)
        let mapped: Result<Int, StructError> = r.mapError { _ in
            StructError(code: -1, reason: "remapped")
        }
        #expect(mapped.error == StructError(code: -1, reason: "remapped"))
        #expect(mapped.value == nil)
    }

    @Test func mapErrorOnSuccessKeepsValue() {
        let r: Result<Int, SampleError> = .success(8)
        let mapped: Result<Int, StructError> = r.mapError { _ in
            StructError(code: 0, reason: "n/a")
        }
        #expect(mapped.value == 8)
        #expect(mapped.error == nil)
        #expect(mapped.isSuccess)
    }

    // MARK: - Determinism / purity (repeated reads are stable)

    @Test func repeatedReadsAreStable() {
        let ok: Result<Int, SampleError> = .success(5)
        let bad: Result<Int, SampleError> = .failure(.boom)
        #expect(ok.value == 5)
        #expect(ok.value == 5)
        #expect(ok.isSuccess)
        #expect(ok.isSuccess)
        #expect(bad.error == .boom)
        #expect(bad.error == .boom)
        #expect(!bad.isSuccess)
    }

    // MARK: - Concurrency: hammer the read-only accessors from many tasks

    @Test func concurrentReadsOnSharedSuccessAreConsistent() async {
        // A shared, Sendable success Result read from many tasks. Every task
        // must observe the same payload — no torn or lost reads.
        let payload = Array(1...1_000)
        let expectedSum = payload.reduce(0, +)
        let shared: Result<[Int], SampleError> = .success(payload)

        let observedSums = await withTaskGroup(of: Int?.self, returning: [Int?].self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    // Read both accessors; isSuccess must agree with value != nil.
                    guard shared.isSuccess, let v = shared.value else { return nil }
                    return v.reduce(0, +)
                }
            }
            var acc: [Int?] = []
            for await s in group { acc.append(s) }
            return acc
        }

        #expect(observedSums.count == 1_000)
        #expect(observedSums.allSatisfy { $0 == expectedSum })
        #expect(observedSums.allSatisfy { $0 != nil })
    }

    @Test func concurrentReadsOnSharedFailureAreConsistent() async {
        let shared: Result<Int, SampleError> = .failure(.withCode(777))

        let observations = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    // Each task must observe: not success, nil value, error == .withCode(777).
                    !shared.isSuccess && shared.value == nil && shared.error == .withCode(777)
                }
            }
            var acc: [Bool] = []
            for await ok in group { acc.append(ok) }
            return acc
        }

        #expect(observations.count == 1_000)
        #expect(observations.allSatisfy { $0 })
    }
}
