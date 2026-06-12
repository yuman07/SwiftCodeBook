//
//  PropertyWrapperTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/UseCase/Foundation/PropertyWrapper.swift
//
//  Source under test (all types are `internal`, visible via @testable):
//
//      @propertyWrapper struct Limit0To1Case1            // clamps wrappedValue to [0, 1]; default 0; no explicit init
//      @propertyWrapper struct Limit0To1Case2            // clamps to [0, 1]; init(initValue: Double = 0) clamps initValue
//      @propertyWrapper struct LimitAToB                 // clamps to [minNum, maxNum]; init(initValue:minNum:maxNum:) clamps initValue
//      @propertyWrapper struct UserDefaultWrapper<T>     // backs an Optional<T> by a UserDefaults.standard key
//      class propertyWrapperCase                         // demo class using all four wrappers; has test()
//
//  Clamp semantics under test: set { number = max(minLo, min(hi, newValue)) }.
//  Because the stored `number` is `private`, only the synthesized no-arg
//  init() (for Limit0To1Case1) and the explicit inits are reachable from the
//  test module; the private memberwise init(number:) is NOT. We therefore
//  drive the wrappers via their public init + wrappedValue surface, and also
//  via the `propertyWrapperCase` demo class (whose stored wrappers are private,
//  so we exercise them through num1/num2/num3/value).
//
//  Notes on UserDefaultWrapper tests:
//   - UserDefaults.standard is process-global shared state. Every test uses a
//     unique key (UUID) and removes it afterwards to stay hermetic and
//     parallel-safe. The single test that touches `propertyWrapperCase.value`
//     (fixed key "123") saves/restores that key and keeps ALL "123" assertions
//     in one @Test so parallel suite execution cannot collide on it.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct PropertyWrapperTests {

    // MARK: - Helpers

    /// A fresh, unique UserDefaults key for an individual test.
    private static func freshKey() -> String { "PWTests.\(UUID().uuidString)" }

    /// Run `body` with a unique key and guarantee removal afterwards.
    private static func withFreshKey(_ body: (String) -> Void) {
        let key = freshKey()
        defer { UserDefaults.standard.removeObject(forKey: key) }
        body(key)
    }

    // MARK: - Limit0To1Case1 : default value

    @Test func case1_defaultValueIsZero() {
        let w = Limit0To1Case1()
        #expect(w.wrappedValue == 0.0)
    }

    @Test func case1_valueInRangePassesThroughUnchanged() {
        var w = Limit0To1Case1()
        w.wrappedValue = 0.25
        #expect(w.wrappedValue == 0.25)
        w.wrappedValue = 0.0
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = 1.0
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = 0.5
        #expect(w.wrappedValue == 0.5)
    }

    @Test func case1_aboveUpperBoundClampsToOne() {
        var w = Limit0To1Case1()
        w.wrappedValue = 2.0
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = 1.0000001
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = 1_000_000.0
        #expect(w.wrappedValue == 1.0)
    }

    @Test func case1_belowLowerBoundClampsToZero() {
        var w = Limit0To1Case1()
        w.wrappedValue = -0.000001
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = -42.0
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = -.greatestFiniteMagnitude
        #expect(w.wrappedValue == 0.0)
    }

    @Test func case1_repeatedSetsAlwaysReflectMostRecentClampedValue() {
        var w = Limit0To1Case1()
        let inputs: [Double] = [0.3, 9, -9, 0.7, 1.0, 0.0, 5, 0.5]
        let expected: [Double] = [0.3, 1, 0, 0.7, 1.0, 0.0, 1, 0.5]
        for (i, v) in inputs.enumerated() {
            w.wrappedValue = v
            #expect(w.wrappedValue == expected[i])
        }
    }

    // Table-driven clamp coverage for the [0, 1] wrappers (Case1).
    @Test(arguments: [
        (-100.0, 0.0),
        (-0.0001, 0.0),
        (0.0, 0.0),
        (0.0001, 0.0001),
        (0.5, 0.5),
        (0.9999, 0.9999),
        (1.0, 1.0),
        (1.0001, 1.0),
        (100.0, 1.0),
    ] as [(Double, Double)])
    func case1_tableDrivenClamp(input: Double, expected: Double) {
        var w = Limit0To1Case1()
        w.wrappedValue = input
        #expect(w.wrappedValue == expected)
    }

    // MARK: - Limit0To1Case1 : floating point extremes

    @Test func case1_positiveInfinityClampsToOne() {
        var w = Limit0To1Case1()
        w.wrappedValue = .infinity
        #expect(w.wrappedValue == 1.0)
    }

    @Test func case1_negativeInfinityClampsToZero() {
        var w = Limit0To1Case1()
        w.wrappedValue = -.infinity
        #expect(w.wrappedValue == 0.0)
    }

    @Test func case1_nanResolvesToUpperBoundOne() {
        // Swift free `min(1, .nan)` returns 1 (the non-NaN side), then
        // `max(0, 1)` is 1. So assigning NaN deterministically yields 1.0 and
        // the stored value is NOT NaN.
        var w = Limit0To1Case1()
        w.wrappedValue = .nan
        #expect(w.wrappedValue == 1.0)
        #expect(!w.wrappedValue.isNaN)
    }

    @Test func case1_signedNegativeZeroStaysZero() {
        var w = Limit0To1Case1()
        w.wrappedValue = -0.0
        // max(0.0, min(1.0, -0.0)) keeps the (signed) zero; value compares == 0.
        #expect(w.wrappedValue == 0.0)
    }

    @Test func case1_smallestPositiveSubnormalIsInRange() {
        var w = Limit0To1Case1()
        w.wrappedValue = .leastNonzeroMagnitude
        #expect(w.wrappedValue == .leastNonzeroMagnitude)
    }

    // MARK: - Limit0To1Case2 : init clamps initValue

    @Test func case2_defaultInitIsZero() {
        let w = Limit0To1Case2()
        #expect(w.wrappedValue == 0.0)
    }

    @Test func case2_initValueInRangeIsKept() {
        #expect(Limit0To1Case2(initValue: 0.5).wrappedValue == 0.5)
        #expect(Limit0To1Case2(initValue: 0.0).wrappedValue == 0.0)
        #expect(Limit0To1Case2(initValue: 1.0).wrappedValue == 1.0)
    }

    @Test func case2_initValueAboveRangeIsClampedAtInit() {
        #expect(Limit0To1Case2(initValue: 2.0).wrappedValue == 1.0)
        #expect(Limit0To1Case2(initValue: .infinity).wrappedValue == 1.0)
    }

    @Test func case2_initValueBelowRangeIsClampedAtInit() {
        #expect(Limit0To1Case2(initValue: -2.0).wrappedValue == 0.0)
        #expect(Limit0To1Case2(initValue: -.infinity).wrappedValue == 0.0)
    }

    @Test func case2_setterClampsAfterInit() {
        var w = Limit0To1Case2(initValue: 0.4)
        #expect(w.wrappedValue == 0.4)
        w.wrappedValue = 9
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = -9
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = 0.6
        #expect(w.wrappedValue == 0.6)
    }

    @Test func case2_initNaNResolvesToOne() {
        #expect(Limit0To1Case2(initValue: .nan).wrappedValue == 1.0)
    }

    @Test(arguments: [
        (-5.0, 0.0), (0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (5.0, 1.0),
    ] as [(Double, Double)])
    func case2_tableDrivenInitClamp(initValue: Double, expected: Double) {
        #expect(Limit0To1Case2(initValue: initValue).wrappedValue == expected)
    }

    // MARK: - LimitAToB : custom range

    @Test func atoB_defaultArgsBehaveLikeZeroToOne() {
        var w = LimitAToB()
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = 2.0
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = -2.0
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = 0.5
        #expect(w.wrappedValue == 0.5)
    }

    @Test func atoB_initValueClampedIntoCustomRange() {
        #expect(LimitAToB(initValue: 10, minNum: 0, maxNum: 5).wrappedValue == 5.0)
        #expect(LimitAToB(initValue: -10, minNum: 0, maxNum: 5).wrappedValue == 0.0)
        #expect(LimitAToB(initValue: 3, minNum: 0, maxNum: 5).wrappedValue == 3.0)
    }

    @Test func atoB_negativeRangeClamping() {
        var w = LimitAToB(initValue: 0.5, minNum: -1, maxNum: 1)
        #expect(w.wrappedValue == 0.5)
        w.wrappedValue = 5
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = -5
        #expect(w.wrappedValue == -1.0)
        w.wrappedValue = -1.0
        #expect(w.wrappedValue == -1.0)
        w.wrappedValue = 0.0
        #expect(w.wrappedValue == 0.0)
    }

    @Test func atoB_fullyNegativeRange() {
        var w = LimitAToB(initValue: -5, minNum: -10, maxNum: -3)
        #expect(w.wrappedValue == -5.0)
        w.wrappedValue = 0
        #expect(w.wrappedValue == -3.0)   // above upper bound -3
        w.wrappedValue = -100
        #expect(w.wrappedValue == -10.0)  // below lower bound -10
    }

    @Test func atoB_degenerateRangeWhereMinEqualsMaxPinsValue() {
        // min == max == 2 means every assignment collapses to 2.
        var w = LimitAToB(initValue: 0, minNum: 2, maxNum: 2)
        #expect(w.wrappedValue == 2.0)
        w.wrappedValue = 100
        #expect(w.wrappedValue == 2.0)
        w.wrappedValue = -100
        #expect(w.wrappedValue == 2.0)
    }

    @Test func atoB_invertedRangeAlwaysYieldsMinNum() {
        // With minNum > maxNum, max(minNum, min(maxNum, x)) is always minNum,
        // because min(maxNum, x) <= maxNum < minNum so the outer max picks minNum.
        var w = LimitAToB(initValue: 0, minNum: 1, maxNum: -1)
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = 100
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = -100
        #expect(w.wrappedValue == 1.0)
        w.wrappedValue = 0.0
        #expect(w.wrappedValue == 1.0)
    }

    @Test func atoB_infinityBoundsActAsNoOpClamp() {
        var w = LimitAToB(initValue: 0, minNum: -.infinity, maxNum: .infinity)
        #expect(w.wrappedValue == 0.0)
        w.wrappedValue = 1_000_000
        #expect(w.wrappedValue == 1_000_000.0)
        w.wrappedValue = -1_000_000
        #expect(w.wrappedValue == -1_000_000.0)
    }

    @Test func atoB_initValueExactlyOnBoundsIsKept() {
        #expect(LimitAToB(initValue: -1, minNum: -1, maxNum: 1).wrappedValue == -1.0)
        #expect(LimitAToB(initValue: 1, minNum: -1, maxNum: 1).wrappedValue == 1.0)
    }

    @Test(arguments: [
        (-2.0, -1.0),
        (-1.0, -1.0),
        (-0.5, -0.5),
        (0.0, 0.0),
        (0.75, 0.75),
        (1.0, 1.0),
        (2.0, 1.0),
    ] as [(Double, Double)])
    func atoB_tableDrivenSetterClampMinusOneToOne(input: Double, expected: Double) {
        var w = LimitAToB(initValue: 0, minNum: -1, maxNum: 1)
        w.wrappedValue = input
        #expect(w.wrappedValue == expected)
    }

    // MARK: - LimitAToB value semantics (struct copy independence)

    @Test func atoB_copyIsIndependentOfOriginal() {
        var original = LimitAToB(initValue: 0.2, minNum: 0, maxNum: 1)
        var copy = original
        copy.wrappedValue = 0.9
        original.wrappedValue = 0.1
        #expect(copy.wrappedValue == 0.9)
        #expect(original.wrappedValue == 0.1)
    }

    @Test func case2_copyIsIndependentOfOriginal() {
        let a = Limit0To1Case2(initValue: 0.3)
        var b = a
        b.wrappedValue = 0.9
        #expect(a.wrappedValue == 0.3)
        #expect(b.wrappedValue == 0.9)
    }

    // MARK: - UserDefaultWrapper : round trips for various T

    @Test func userDefault_unsetKeyReturnsNil() {
        Self.withFreshKey { key in
            let w = UserDefaultWrapper<String>(key)
            #expect(w.wrappedValue == nil)
        }
    }

    @Test func userDefault_setThenGetStringRoundTrips() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<String>(key)
            w.wrappedValue = "hello"
            #expect(w.wrappedValue == "hello")
            // Confirms it actually wrote to the standard store under `key`.
            #expect(UserDefaults.standard.string(forKey: key) == "hello")
        }
    }

    @Test func userDefault_setNilRemovesValue() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<String>(key)
            w.wrappedValue = "v"
            #expect(w.wrappedValue == "v")
            w.wrappedValue = nil
            #expect(w.wrappedValue == nil)
            #expect(UserDefaults.standard.object(forKey: key) == nil)
        }
    }

    @Test func userDefault_intRoundTrip() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<Int>(key)
            w.wrappedValue = 12345
            #expect(w.wrappedValue == 12345)
            w.wrappedValue = Int.min
            #expect(w.wrappedValue == Int.min)
            w.wrappedValue = Int.max
            #expect(w.wrappedValue == Int.max)
            w.wrappedValue = 0
            #expect(w.wrappedValue == 0)
        }
    }

    @Test func userDefault_boolRoundTrip() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<Bool>(key)
            w.wrappedValue = true
            #expect(w.wrappedValue == true)
            w.wrappedValue = false
            #expect(w.wrappedValue == false)
        }
    }

    @Test func userDefault_doubleRoundTrip() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<Double>(key)
            w.wrappedValue = 3.14159
            #expect(w.wrappedValue == 3.14159)
        }
    }

    @Test func userDefault_stringArrayRoundTrip() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<[String]>(key)
            w.wrappedValue = ["x", "y", "z"]
            #expect(w.wrappedValue == ["x", "y", "z"])
            w.wrappedValue = []
            #expect(w.wrappedValue == [])
        }
    }

    @Test func userDefault_dictionaryRoundTrip() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<[String: Int]>(key)
            w.wrappedValue = ["a": 1, "b": 2]
            #expect(w.wrappedValue == ["a": 1, "b": 2])
        }
    }

    @Test func userDefault_emptyStringValueRoundTrips() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<String>(key)
            w.wrappedValue = ""
            #expect(w.wrappedValue == "")
            // Empty string is a stored object, distinct from "unset" (nil).
            #expect(UserDefaults.standard.object(forKey: key) != nil)
        }
    }

    @Test func userDefault_unicodeAndEmojiStringRoundTrips() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<String>(key)
            let s = "héllo 世界 👨‍👩‍👧‍👦 e\u{0301}"
            w.wrappedValue = s
            #expect(w.wrappedValue == s)
        }
    }

    @Test func userDefault_emptyKeyStillStoresAndReads() {
        let key = ""
        defer { UserDefaults.standard.removeObject(forKey: key) }
        var w = UserDefaultWrapper<String>(key)
        w.wrappedValue = "emptyKeyValue"
        #expect(w.wrappedValue == "emptyKeyValue")
    }

    @Test func userDefault_typeMismatchOnReadReturnsNil() {
        Self.withFreshKey { key in
            // Store an Int directly, then read it through a String-typed wrapper.
            // The `as? T` cast fails, so the getter yields nil.
            UserDefaults.standard.set(42, forKey: key)
            let w = UserDefaultWrapper<String>(key)
            #expect(w.wrappedValue == nil)
        }
    }

    @Test func userDefault_twoWrappersSameKeyShareStorage() {
        Self.withFreshKey { key in
            var w1 = UserDefaultWrapper<String>(key)
            let w2 = UserDefaultWrapper<String>(key)
            w1.wrappedValue = "shared"
            // w2 reads through the same UserDefaults key.
            #expect(w2.wrappedValue == "shared")
        }
    }

    @Test func userDefault_overwriteUpdatesValue() {
        Self.withFreshKey { key in
            var w = UserDefaultWrapper<String>(key)
            w.wrappedValue = "first"
            #expect(w.wrappedValue == "first")
            w.wrappedValue = "second"
            #expect(w.wrappedValue == "second")
        }
    }

    // MARK: - propertyWrapperCase : demo class exercising all wrappers

    @Test func demoClass_initialValues() {
        let p = propertyWrapperCase()
        #expect(p.num1 == 0.0)   // Limit0To1Case1 default
        #expect(p.num2 == 0.5)   // Limit0To1Case2(initValue: 0.5)
        #expect(p.num3 == 0.5)   // LimitAToB(initValue: 0.5, minNum: -1, maxNum: 1)
    }

    @Test func demoClass_num1ClampsToZeroToOne() {
        let p = propertyWrapperCase()
        p.num1 = 0.5
        #expect(p.num1 == 0.5)
        p.num1 = 2.0
        #expect(p.num1 == 1.0)
        p.num1 = -1.0
        #expect(p.num1 == 0.0)
    }

    @Test func demoClass_num2ClampsToZeroToOne() {
        let p = propertyWrapperCase()
        p.num2 = 5.0
        #expect(p.num2 == 1.0)
        p.num2 = -5.0
        #expect(p.num2 == 0.0)
        p.num2 = 0.25
        #expect(p.num2 == 0.25)
    }

    @Test func demoClass_num3ClampsToMinusOneToOne() {
        let p = propertyWrapperCase()
        p.num3 = 5.0
        #expect(p.num3 == 1.0)
        p.num3 = -5.0
        #expect(p.num3 == -1.0)
        p.num3 = 0.0
        #expect(p.num3 == 0.0)
        p.num3 = -0.75
        #expect(p.num3 == -0.75)
    }

    @Test func demoClass_testMethodSetsNum1ToTwoWhichClampsToOne() {
        let p = propertyWrapperCase()
        #expect(p.num1 == 0.0)
        // test() prints num1 then assigns num1 = 2.0, which clamps to 1.0.
        p.test()
        #expect(p.num1 == 1.0)
    }

    @Test func demoClass_independentInstancesHaveIndependentNumerics() {
        let p1 = propertyWrapperCase()
        let p2 = propertyWrapperCase()
        p1.num1 = 0.3
        p2.num1 = 0.7
        #expect(p1.num1 == 0.3)
        #expect(p2.num1 == 0.7)
        p1.num3 = -0.4
        #expect(p2.num3 == 0.5) // untouched, still at its init value
    }

    // All assertions touching the FIXED UserDefaults key "123" (used by
    // propertyWrapperCase.value) live in this single @Test so concurrent suite
    // execution cannot race on that shared key. The original value is saved and
    // restored to leave the standard store as we found it.
    @Test func demoClass_valueBacksFixedKey123AndIsSharedAcrossInstances() {
        let fixedKey = "123"
        let saved = UserDefaults.standard.object(forKey: fixedKey)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: fixedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: fixedKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: fixedKey)
        let p = propertyWrapperCase()
        #expect(p.value == nil)

        p.value = "stored"
        #expect(p.value == "stored")
        // Confirms the wrapper writes to UserDefaults under the literal "123".
        #expect(UserDefaults.standard.string(forKey: fixedKey) == "stored")

        // Because the key is fixed, a second instance observes the SAME value.
        let p2 = propertyWrapperCase()
        #expect(p2.value == "stored")

        p.value = nil
        #expect(p.value == nil)
        #expect(p2.value == nil)
        #expect(UserDefaults.standard.object(forKey: fixedKey) == nil)
    }

    // MARK: - Large data / time-bounded stress

    @Test func case1_manySetsRemainClampedAndFinalValueCorrect() {
        var w = Limit0To1Case1()
        // Sweep a large number of assignments; every one must stay in [0, 1].
        var allInRange = true
        for i in 0..<100_000 {
            // Values oscillate well outside [0,1] to keep clamping busy.
            let v = Double(i % 7) - 3.0          // in [-3, 3]
            w.wrappedValue = v
            if w.wrappedValue < 0.0 || w.wrappedValue > 1.0 { allInRange = false }
        }
        #expect(allInRange)
        // Last i is 99_999; 99_999 % 7 == 4 -> v = 4 - 3 = 1.0 -> stays 1.0.
        #expect(w.wrappedValue == 1.0)
    }

    @Test func userDefault_manyDistinctKeysRoundTrip() {
        // Bounded: 2_000 keys, each written and read back, then cleaned up.
        let keys = (0..<2_000).map { "PWTests.bulk.\(UUID().uuidString).\($0)" }
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
        var ok = 0
        for (i, key) in keys.enumerated() {
            var w = UserDefaultWrapper<Int>(key)
            w.wrappedValue = i
            if w.wrappedValue == i { ok += 1 }
        }
        #expect(ok == keys.count)
    }

    // MARK: - Concurrency
    //
    // The wrappers are non-Sendable value-type structs. To exercise them under
    // concurrency safely (Swift 6 strict concurrency), each child task builds
    // and mutates its OWN wrapper instance entirely inside the task and returns
    // only a Sendable Bool. This still runs the clamp logic on many threads
    // simultaneously and asserts the invariant holds everywhere.

    @Test func concurrent_case1ClampInvariantHoldsAcrossTasks() async {
        let taskCount = 1_000
        let okCount: Int = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    var w = Limit0To1Case1()
                    // Drive a mix of out-of-range values.
                    let inputs: [Double] = [Double(i), -Double(i), 0.5, -1, 2, .infinity, -.infinity]
                    for v in inputs {
                        w.wrappedValue = v
                        if w.wrappedValue < 0.0 || w.wrappedValue > 1.0 { return false }
                    }
                    // After the last input (-.infinity) it must be 0.0.
                    return w.wrappedValue == 0.0
                }
            }
            var total = 0
            for await ok in group where ok { total += 1 }
            return total
        }
        #expect(okCount == taskCount)
    }

    @Test func concurrent_atoBClampInvariantHoldsAcrossTasks() async {
        let taskCount = 1_000
        let okCount: Int = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    var w = LimitAToB(initValue: 0, minNum: -1, maxNum: 1)
                    w.wrappedValue = Double(i)        // -> clamps to 1 (for i>=1) or 0
                    if w.wrappedValue < -1.0 || w.wrappedValue > 1.0 { return false }
                    w.wrappedValue = -Double(i) - 5   // strongly negative -> -1
                    return w.wrappedValue == -1.0
                }
            }
            var total = 0
            for await ok in group where ok { total += 1 }
            return total
        }
        #expect(okCount == taskCount)
    }

    @Test func concurrent_userDefaultDistinctKeysRoundTrip() async {
        // Each task uses its own unique key (no shared key contention), writes
        // its index, reads it back, and reports success. Keys are removed after.
        let taskCount = 500
        let prefix = "PWTests.concurrent.\(UUID().uuidString)."
        defer {
            for i in 0..<taskCount {
                UserDefaults.standard.removeObject(forKey: prefix + String(i))
            }
        }
        let okCount: Int = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<taskCount {
                let key = prefix + String(i)
                group.addTask {
                    var w = UserDefaultWrapper<Int>(key)
                    w.wrappedValue = i
                    return w.wrappedValue == i
                }
            }
            var total = 0
            for await ok in group where ok { total += 1 }
            return total
        }
        #expect(okCount == taskCount)
    }
}
