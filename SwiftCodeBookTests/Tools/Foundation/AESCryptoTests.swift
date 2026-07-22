//
//  AESCryptoTests.swift
//  SwiftCodeBookTests
//
//  Created by yuman on 2026/7/10.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct AESCryptoTests {
    struct ModeVector: Sendable {
        let mode: AESMode.Kind
        let ivHex: String?
        let encryptedDataHex: String
    }

    private enum TestDataError: Error {
        case invalidHex
    }

    private static let nistPlaintext = "6bc1bee22e409f96e93d7e117393172a"
    private static let nistKey = "2b7e151628aed2a6abf7158809cf4f3c"
    private static let nistIV = "000102030405060708090a0b0c0d0e0f"
    private static let defaultModes: [AESMode] = [
        .gcm(),
        .cbc(),
        .ecb(),
        .cfb(),
        .cfb8(),
        .ctr(),
        .ofb(),
    ]

    // NIST SP 800-38A first-block vectors. CFB8 is section F.3.7.
    private static let modeVectors: [ModeVector] = [
        ModeVector(
            mode: .ecb,
            ivHex: nil,
            encryptedDataHex: "3ad77bb40d7a3660a89ecaf32466ef97"
        ),
        ModeVector(
            mode: .cbc,
            ivHex: nistIV,
            encryptedDataHex: "7649abac8119b246cee98e9b12e9197d"
        ),
        ModeVector(
            mode: .cfb,
            ivHex: nistIV,
            encryptedDataHex: "3b3fd92eb72dad20333449f8e83cfb4a"
        ),
        ModeVector(
            mode: .cfb8,
            ivHex: nistIV,
            encryptedDataHex: "3b79424c9c0dd436bace9e0ed4586a4f"
        ),
        ModeVector(
            mode: .ctr,
            ivHex: "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff",
            encryptedDataHex: "874d6191b620e3261bef6864990db6ce"
        ),
        ModeVector(
            mode: .ofb,
            ivHex: nistIV,
            encryptedDataHex: "3b3fd92eb72dad20333449f8e83cfb4a"
        ),
    ]

    @Test
    func allModesAndKeySizesRoundTrip() throws {
        let plaintext = Data((0..<37).map { UInt8(truncatingIfNeeded: $0 * 11) })

        for mode in Self.defaultModes {
            for keySize in AESKeySize.allCases {
                let key = try AESCrypto.generateRandomKey(size: keySize)
                let payload = try plaintext.aesEncrypted(using: key, mode: mode)
                let decrypted = try payload.decrypted(using: key)

                #expect(decrypted == plaintext)
                Self.expectMetadata(of: payload, matches: mode)
            }
        }
    }

    @Test
    func generatedRandomKeysUseRequiredSizes() throws {
        for keySize in AESKeySize.allCases {
            let first = try AESCrypto.generateRandomKey(size: keySize)
            let second = try AESCrypto.generateRandomKey(size: keySize)
            #expect(first.count == keySize.byteCount)
            #expect(second.count == keySize.byteCount)
            #expect(first != second)
        }
    }

    @Test
    func cbcAndECBSupportPKCS7AndNoPadding() throws {
        let key = try AESCrypto.generateRandomKey(size: .bits256)
        let alignedPlaintext = Data((0..<32).map { UInt8($0) })

        for mode in [AESMode.Kind.cbc, .ecb] {
            for padding in [AESPadding.pkcs7, .none] {
                let payload = try AESCrypto.encrypt(
                    alignedPlaintext,
                    using: key,
                    mode: Self.configuredMode(mode, padding: padding)
                )
                #expect(Self.padding(of: payload) == padding)
                #expect(try AESCrypto.decrypt(payload, using: key) == alignedPlaintext)
            }
        }
    }

    @Test
    func cbcAndECBDefaultToPKCS7() throws {
        let key = try AESCrypto.generateRandomKey()
        let unalignedPlaintext = Data("PKCS#7 is the block-mode default".utf8)

        for mode in [AESMode.cbc(), .ecb()] {
            let payload = try AESCrypto.encrypt(unalignedPlaintext, using: key, mode: mode)
            #expect(Self.padding(of: payload) == .pkcs7)
            #expect(try AESCrypto.decrypt(payload, using: key) == unalignedPlaintext)
        }
    }

    @Test
    func noPaddingRejectsNonBlockAlignedInput() throws {
        let key = try AESCrypto.generateRandomKey()
        let unalignedPlaintext = Data(repeating: 0xA5, count: 15)

        for mode in [AESMode.Kind.cbc, .ecb] {
            #expect(
                throws: AESCryptoError.invalidInputLength(
                    mode: mode,
                    blockSize: 16,
                    actual: 15
                )
            ) {
                _ = try AESCrypto.encrypt(
                    unalignedPlaintext,
                    using: key,
                    mode: Self.configuredMode(mode, padding: .none)
                )
            }
        }
    }

    @Test
    func nonGCMDecryptionRejectsAuthenticatedData() throws {
        let key = try AESCrypto.generateRandomKey()
        let authenticatedData = Data("header".utf8)

        for mode in [AESMode.cbc(), .ecb(), .cfb(), .cfb8(), .ctr(), .ofb()] {
            let payload = try AESCrypto.encrypt(Data("plaintext".utf8), using: key, mode: mode)
            #expect(throws: AESCryptoError.unsupportedAuthenticatedData(mode: mode.kind)) {
                _ = try AESCrypto.decrypt(
                    payload,
                    using: key,
                    authenticating: authenticatedData
                )
            }
        }
    }

    @Test
    func invalidKeyLengthsAreRejected() throws {
        let plaintext = Data("invalid key".utf8)

        for byteCount in [0, 15, 17, 23, 25, 31, 33] {
            let key = Data(repeating: 0, count: byteCount)
            #expect(throws: AESCryptoError.invalidKeyLength(actual: byteCount)) {
                _ = try AESCrypto.encrypt(plaintext, using: key, mode: .gcm())
            }
        }
    }

    @Test
    func wrongGCMKeyFailsAuthentication() throws {
        let firstKey = try AESCrypto.generateRandomKey()
        let secondKey = try AESCrypto.generateRandomKey()
        let payload = try AESCrypto.encrypt(
            Data("authenticated".utf8),
            using: firstKey,
            mode: .gcm()
        )

        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(payload, using: secondKey)
        }
    }

    @Test
    func invalidInitializationValueLengthsAreRejected() throws {
        let key = try AESCrypto.generateRandomKey()
        let invalidIV = Data(repeating: 0, count: 15)
        let invalidModes: [(AESMode, AESMode.Kind, Int, Int)] = [
            (.gcm(nonce: Data(repeating: 0, count: 11)), .gcm, 12, 11),
            (.cbc(iv: invalidIV), .cbc, 16, 15),
            (.cfb(iv: invalidIV), .cfb, 16, 15),
            (.cfb8(iv: invalidIV), .cfb8, 16, 15),
            (.ctr(initialCounter: invalidIV), .ctr, 16, 15),
            (.ofb(iv: invalidIV), .ofb, 16, 15),
        ]

        for (mode, kind, expected, actual) in invalidModes {
            #expect(
                throws: AESCryptoError.invalidIVLength(
                    mode: kind,
                    expected: expected,
                    actual: actual
                )
            ) {
                _ = try AESCrypto.encrypt(Data(), using: key, mode: mode)
            }
        }
    }

    @Test
    func wrongGCMAuthenticatedDataFails() throws {
        let key = try AESCrypto.generateRandomKey()
        let authenticatedData = Data("header".utf8)
        let payload = try AESCrypto.encrypt(
            Data("secret payload".utf8),
            using: key,
            mode: .gcm(authenticating: authenticatedData)
        )

        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(
                payload,
                using: key,
                authenticating: Data("different header".utf8)
            )
        }
    }

    @Test
    func malformedEncryptedPayloadsAreRejected() throws {
        let key = try AESCrypto.generateRandomKey()
        let alignedCiphertext = Data(repeating: 0, count: 16)
        let validIV = Data(repeating: 0, count: 16)
        let invalidIV = Data(repeating: 0, count: 15)
        let invalidInitializationValues: [(AESEncryptedPayload, AESMode.Kind, Int)] = [
            (
                .gcm(
                    encryptedData: Data(),
                    nonce: Data(repeating: 0, count: 11),
                    authenticationTag: Data(repeating: 0, count: 16)
                ),
                .gcm,
                12
            ),
            (.cbc(encryptedData: alignedCiphertext, iv: invalidIV, padding: .none), .cbc, 16),
            (.cfb(encryptedData: Data(), iv: invalidIV), .cfb, 16),
            (.cfb8(encryptedData: Data(), iv: invalidIV), .cfb8, 16),
            (.ctr(encryptedData: Data(), initialCounter: invalidIV), .ctr, 16),
            (.ofb(encryptedData: Data(), iv: invalidIV), .ofb, 16),
        ]

        for (payload, mode, expected) in invalidInitializationValues {
            #expect(
                throws: AESCryptoError.invalidIVLength(
                    mode: mode,
                    expected: expected,
                    actual: mode == .gcm ? 11 : 15
                )
            ) {
                _ = try AESCrypto.decrypt(payload, using: key)
            }
        }

        let invalidTagPayload = AESEncryptedPayload.gcm(
            encryptedData: Data(),
            nonce: Data(repeating: 0, count: 12),
            authenticationTag: Data(repeating: 0, count: 15)
        )
        #expect(
            throws: AESCryptoError.invalidAuthenticationTagLength(
                expected: 16,
                actual: 15
            )
        ) {
            _ = try AESCrypto.decrypt(invalidTagPayload, using: key)
        }

        for payload in [
            AESEncryptedPayload.cbc(
                encryptedData: Data(repeating: 0, count: 15),
                iv: validIV,
                padding: .none
            ),
            .ecb(encryptedData: Data(repeating: 0, count: 15), padding: .none),
        ] {
            #expect(
                throws: AESCryptoError.invalidInputLength(
                    mode: Self.kind(of: payload),
                    blockSize: 16,
                    actual: 15
                )
            ) {
                _ = try AESCrypto.decrypt(payload, using: key)
            }
        }
    }

    @Test
    func tamperedGCMPayloadFailsAuthentication() throws {
        let key = try AESCrypto.generateRandomKey()
        let payload = try AESCrypto.encrypt(
            Data("secret payload".utf8),
            using: key,
            mode: .gcm()
        )
        guard case .gcm(let encryptedData, let nonce, let authenticationTag) = payload else {
            Issue.record("Expected a GCM payload.")
            return
        }

        let tamperedPayloads = [
            AESEncryptedPayload.gcm(
                encryptedData: Self.togglingFirstByte(of: encryptedData),
                nonce: nonce,
                authenticationTag: authenticationTag
            ),
            .gcm(
                encryptedData: encryptedData,
                nonce: nonce,
                authenticationTag: Self.togglingFirstByte(of: authenticationTag)
            ),
        ]

        for tamperedPayload in tamperedPayloads {
            #expect(throws: AESCryptoError.authenticationFailed) {
                _ = try AESCrypto.decrypt(tamperedPayload, using: key)
            }
        }
    }

    @Test(arguments: modeVectors)
    func commonCryptoModesMatchNISTVectors(vector: ModeVector) throws {
        let key = try Self.data(hex: Self.nistKey)
        let plaintext = try Self.data(hex: Self.nistPlaintext)
        let iv = try vector.ivHex.map(Self.data(hex:))
        let expectedEncryptedData = try Self.data(hex: vector.encryptedDataHex)

        let payload = try AESCrypto.encrypt(
            plaintext,
            using: key,
            mode: Self.configuredMode(vector.mode, iv: iv, padding: .none)
        )
        #expect(payload.encryptedData == expectedEncryptedData)
        #expect(try AESCrypto.decrypt(payload, using: key) == plaintext)
    }

    @Test
    func gcmMatchesNISTEmptyPlaintextVector() throws {
        let key = Data(repeating: 0, count: 16)
        let nonce = Data(repeating: 0, count: 12)
        let expectedTag = try Self.data(hex: "58e2fccefa7e3061367f1d57a4e7455a")

        let payload = try AESCrypto.encrypt(Data(), using: key, mode: .gcm(nonce: nonce))
        #expect(payload.encryptedData.isEmpty)
        guard case .gcm(_, let actualNonce, let authenticationTag) = payload else {
            Issue.record("Expected a GCM payload.")
            return
        }
        #expect(actualNonce == nonce)
        #expect(authenticationTag == expectedTag)
        #expect(try AESCrypto.decrypt(payload, using: key).isEmpty)
    }

    private static func data(hex: String) throws -> Data {
        guard hex.count.isMultiple(of: 2) else {
            throw TestDataError.invalidHex
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                throw TestDataError.invalidHex
            }
            bytes.append(byte)
            index = nextIndex
        }
        return Data(bytes)
    }

    private static func configuredMode(
        _ mode: AESMode.Kind,
        iv: Data? = nil,
        padding: AESPadding
    ) -> AESMode {
        switch mode {
        case .gcm:
            .gcm(nonce: iv)
        case .cbc:
            .cbc(iv: iv, padding: padding)
        case .ecb:
            .ecb(padding: padding)
        case .cfb:
            .cfb(iv: iv)
        case .cfb8:
            .cfb8(iv: iv)
        case .ctr:
            .ctr(initialCounter: iv)
        case .ofb:
            .ofb(iv: iv)
        }
    }

    private static func expectMetadata(
        of payload: AESEncryptedPayload,
        matches mode: AESMode
    ) {
        switch (payload, mode) {
        case (.gcm(_, let nonce, let tag), .gcm):
            #expect(nonce.count == 12)
            #expect(tag.count == 16)
        case (.cbc(_, let iv, let padding), .cbc(_, let expectedPadding)):
            #expect(iv.count == 16)
            #expect(padding == expectedPadding)
        case (.ecb(_, let padding), .ecb(let expectedPadding)):
            #expect(padding == expectedPadding)
        case (.cfb(_, let iv), .cfb):
            #expect(iv.count == 16)
        case (.cfb8(_, let iv), .cfb8):
            #expect(iv.count == 16)
        case (.ctr(_, let initialCounter), .ctr):
            #expect(initialCounter.count == 16)
        case (.ofb(_, let iv), .ofb):
            #expect(iv.count == 16)
        default:
            Issue.record("Encrypted payload does not match the requested AES mode.")
        }
    }

    private static func padding(of payload: AESEncryptedPayload) -> AESPadding? {
        switch payload {
        case .cbc(_, _, let padding), .ecb(_, let padding): padding
        default: nil
        }
    }

    private static func kind(of payload: AESEncryptedPayload) -> AESMode.Kind {
        switch payload {
        case .gcm: .gcm
        case .cbc: .cbc
        case .ecb: .ecb
        case .cfb: .cfb
        case .cfb8: .cfb8
        case .ctr: .ctr
        case .ofb: .ofb
        }
    }

    private static func togglingFirstByte(of data: Data) -> Data {
        var result = data
        guard let firstIndex = result.indices.first else {
            return Data([1])
        }
        result[firstIndex] ^= 1
        return result
    }

}
