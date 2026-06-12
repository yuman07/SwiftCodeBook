//
//  InfrastructureSmokeTests.swift
//  SwiftCodeBookTests
//
//  Verifies the test target is wired up: Swift Testing runs and the host
//  module is importable via @testable.
//

import Testing
@testable import SwiftCodeBook

@Suite struct InfrastructureSmokeTests {
    @Test func canImportHostModuleAndUseTypes() {
        let value = AnyJSONValue.int(42)
        #expect(value.intValue == 42)
        #expect(value.isNull == false)
        #expect(value.stringValue == nil)
    }
}
