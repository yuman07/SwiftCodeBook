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
        let mode: AESMode
        let ivHex: String?
        let ciphertextHex: String
    }

    private enum TestDataError: Error {
        case invalidHex
    }

    private static let nistPlaintext = "6bc1bee22e409f96e93d7e117393172a"
    private static let nistKey = "2b7e151628aed2a6abf7158809cf4f3c"
    private static let nistIV = "000102030405060708090a0b0c0d0e0f"

    // NIST SP 800-38A first-block vectors. CFB8 is section F.3.7.
    private static let modeVectors: [ModeVector] = [
        ModeVector(
            mode: .ecb,
            ivHex: nil,
            ciphertextHex: "3ad77bb40d7a3660a89ecaf32466ef97"
        ),
        ModeVector(
            mode: .cbc,
            ivHex: nistIV,
            ciphertextHex: "7649abac8119b246cee98e9b12e9197d"
        ),
        ModeVector(
            mode: .cfb,
            ivHex: nistIV,
            ciphertextHex: "3b3fd92eb72dad20333449f8e83cfb4a"
        ),
        ModeVector(
            mode: .cfb8,
            ivHex: nistIV,
            ciphertextHex: "3b79424c9c0dd436bace9e0ed4586a4f"
        ),
        ModeVector(
            mode: .ctr,
            ivHex: "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff",
            ciphertextHex: "874d6191b620e3261bef6864990db6ce"
        ),
        ModeVector(
            mode: .ofb,
            ivHex: nistIV,
            ciphertextHex: "3b3fd92eb72dad20333449f8e83cfb4a"
        ),
    ]

    @Test
    func allModesAndKeySizesRoundTrip() throws {
        let plaintext = Data((0..<37).map { UInt8(truncatingIfNeeded: $0 * 11) })

        for mode in AESMode.allCases {
            for keySize in AESKeySize.allCases {
                let key = try AESCrypto.generateKey(size: keySize)
                let payload = try plaintext.aesEncrypted(using: key, mode: mode)
                let decrypted = try payload.decrypted(using: key)

                #expect(decrypted == plaintext)
                #expect(payload.mode == mode)
                #expect(payload.padding == (mode == .cbc || mode == .ecb ? .pkcs7 : .none))
                #expect(payload.iv?.count == (mode == .gcm ? 12 : mode == .ecb ? nil : 16))
                #expect(payload.authenticationTag?.count == (mode == .gcm ? 16 : nil))
            }
        }
    }

    @Test
    func generatedKeysAndIVsUseRequiredSizes() throws {
        for keySize in AESKeySize.allCases {
            let first = try AESCrypto.generateKey(size: keySize)
            let second = try AESCrypto.generateKey(size: keySize)
            #expect(first.count == keySize.byteCount)
            #expect(second.count == keySize.byteCount)
            #expect(first != second)
        }

        for mode in AESMode.allCases {
            let iv = try AESCrypto.generateIV(for: mode)
            #expect(iv?.count == (mode == .gcm ? 12 : mode == .ecb ? nil : 16))
        }
    }

    @Test
    func cbcAndECBSupportPKCS7AndNoPadding() throws {
        let key = try AESCrypto.generateKey(size: .bits256)
        let alignedPlaintext = Data((0..<32).map { UInt8($0) })

        for mode in [AESMode.cbc, .ecb] {
            for padding in [AESPadding.pkcs7, .none] {
                let payload = try AESCrypto.encrypt(
                    alignedPlaintext,
                    using: key,
                    mode: mode,
                    padding: padding
                )
                #expect(payload.padding == padding)
                #expect(try AESCrypto.decrypt(payload, using: key) == alignedPlaintext)
            }
        }
    }

    @Test
    func cbcAndECBDefaultToPKCS7() throws {
        let key = try AESCrypto.generateKey()
        let unalignedPlaintext = Data("PKCS#7 is the block-mode default".utf8)

        for mode in [AESMode.cbc, .ecb] {
            let payload = try AESCrypto.encrypt(unalignedPlaintext, using: key, mode: mode)
            #expect(payload.padding == .pkcs7)
            #expect(try AESCrypto.decrypt(payload, using: key) == unalignedPlaintext)
        }
    }

    @Test
    func noPaddingRejectsNonBlockAlignedInput() throws {
        let key = try AESCrypto.generateKey()
        let unalignedPlaintext = Data(repeating: 0xA5, count: 15)

        for mode in [AESMode.cbc, .ecb] {
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
                    mode: mode,
                    padding: .none
                )
            }

            let malformedPayload = AESEncryptedPayload(
                ciphertext: unalignedPlaintext,
                iv: mode == .ecb ? nil : Data(repeating: 0, count: 16),
                authenticationTag: nil,
                mode: mode,
                padding: .none
            )
            #expect(
                throws: AESCryptoError.invalidInputLength(
                    mode: mode,
                    blockSize: 16,
                    actual: 15
                )
            ) {
                _ = try AESCrypto.decrypt(malformedPayload, using: key)
            }
        }
    }

    @Test
    func streamModesRejectPKCS7() throws {
        let key = try AESCrypto.generateKey()
        let plaintext = Data("stream modes do not pad".utf8)

        for mode in [AESMode.cfb, .cfb8, .ctr, .ofb] {
            #expect(throws: AESCryptoError.unsupportedPadding(.pkcs7, mode: mode)) {
                _ = try AESCrypto.encrypt(
                    plaintext,
                    using: key,
                    mode: mode,
                    padding: .pkcs7
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
                _ = try AESCrypto.encrypt(plaintext, using: key)
            }
        }
    }

    @Test
    func wrongGCMKeyFailsAuthentication() throws {
        let firstKey = try AESCrypto.generateKey()
        let secondKey = try AESCrypto.generateKey()
        let payload = try AESCrypto.encrypt(Data("authenticated".utf8), using: firstKey)

        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(payload, using: secondKey)
        }
    }

    @Test
    func missingAndInvalidIVsAreRejected() throws {
        let key = try AESCrypto.generateKey()
        let alignedCiphertext = Data(repeating: 0, count: 16)

        for mode in [AESMode.cbc, .cfb, .cfb8, .ctr, .ofb] {
            let missingIV = AESEncryptedPayload(
                ciphertext: alignedCiphertext,
                iv: nil,
                authenticationTag: nil,
                mode: mode,
                padding: .none
            )
            #expect(throws: AESCryptoError.missingIV(mode: mode)) {
                _ = try AESCrypto.decrypt(missingIV, using: key)
            }

            let invalidIV = AESEncryptedPayload(
                ciphertext: alignedCiphertext,
                iv: Data(repeating: 0, count: 15),
                authenticationTag: nil,
                mode: mode,
                padding: .none
            )
            #expect(
                throws: AESCryptoError.invalidIVLength(
                    mode: mode,
                    expected: 16,
                    actual: 15
                )
            ) {
                _ = try AESCrypto.decrypt(invalidIV, using: key)
            }
        }

        let missingNonce = AESEncryptedPayload(
            ciphertext: Data(),
            iv: nil,
            authenticationTag: Data(repeating: 0, count: 16),
            mode: .gcm,
            padding: .none
        )
        #expect(throws: AESCryptoError.missingIV(mode: .gcm)) {
            _ = try AESCrypto.decrypt(missingNonce, using: key)
        }

        #expect(
            throws: AESCryptoError.invalidIVLength(
                mode: .gcm,
                expected: 12,
                actual: 11
            )
        ) {
            _ = try AESCrypto.encrypt(
                Data(),
                using: key,
                mode: .gcm,
                iv: Data(repeating: 0, count: 11)
            )
        }
    }

    @Test
    func ecbRejectsAnIV() throws {
        let key = try AESCrypto.generateKey()
        let iv = Data(repeating: 0, count: 16)

        #expect(throws: AESCryptoError.unexpectedIV(mode: .ecb)) {
            _ = try AESCrypto.encrypt(Data(), using: key, mode: .ecb, iv: iv)
        }

        let payload = AESEncryptedPayload(
            ciphertext: Data(repeating: 0, count: 16),
            iv: iv,
            authenticationTag: nil,
            mode: .ecb,
            padding: .none
        )
        #expect(throws: AESCryptoError.unexpectedIV(mode: .ecb)) {
            _ = try AESCrypto.decrypt(payload, using: key)
        }
    }

    @Test
    func missingAndInvalidGCMTagsAreRejected() throws {
        let key = try AESCrypto.generateKey()
        let nonce = Data(repeating: 0, count: 12)

        let missingTag = AESEncryptedPayload(
            ciphertext: Data(),
            iv: nonce,
            authenticationTag: nil,
            mode: .gcm,
            padding: .none
        )
        #expect(throws: AESCryptoError.missingAuthenticationTag) {
            _ = try AESCrypto.decrypt(missingTag, using: key)
        }

        let invalidTag = AESEncryptedPayload(
            ciphertext: Data(),
            iv: nonce,
            authenticationTag: Data(repeating: 0, count: 15),
            mode: .gcm,
            padding: .none
        )
        #expect(
            throws: AESCryptoError.invalidAuthenticationTagLength(
                expected: 16,
                actual: 15
            )
        ) {
            _ = try AESCrypto.decrypt(invalidTag, using: key)
        }
    }

    @Test
    func tamperedGCMTagCiphertextAndAuthenticatedDataFail() throws {
        let key = try AESCrypto.generateKey()
        let authenticatedData = Data("header".utf8)
        let payload = try AESCrypto.encrypt(
            Data("secret payload".utf8),
            using: key,
            authenticating: authenticatedData
        )
        let tag = try #require(payload.authenticationTag)

        let tamperedTagPayload = AESEncryptedPayload(
            ciphertext: payload.ciphertext,
            iv: payload.iv,
            authenticationTag: Self.togglingFirstByte(of: tag),
            mode: .gcm,
            padding: .none
        )
        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(
                tamperedTagPayload,
                using: key,
                authenticating: authenticatedData
            )
        }

        let tamperedCiphertextPayload = AESEncryptedPayload(
            ciphertext: Self.togglingFirstByte(of: payload.ciphertext),
            iv: payload.iv,
            authenticationTag: tag,
            mode: .gcm,
            padding: .none
        )
        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(
                tamperedCiphertextPayload,
                using: key,
                authenticating: authenticatedData
            )
        }

        #expect(throws: AESCryptoError.authenticationFailed) {
            _ = try AESCrypto.decrypt(
                payload,
                using: key,
                authenticating: Data("different header".utf8)
            )
        }
    }

    @Test(arguments: modeVectors)
    func commonCryptoModesMatchNISTVectors(vector: ModeVector) throws {
        let key = try Self.data(hex: Self.nistKey)
        let plaintext = try Self.data(hex: Self.nistPlaintext)
        let iv = try vector.ivHex.map(Self.data(hex:))
        let expectedCiphertext = try Self.data(hex: vector.ciphertextHex)

        let payload = try AESCrypto.encrypt(
            plaintext,
            using: key,
            mode: vector.mode,
            padding: .none,
            iv: iv
        )
        #expect(payload.ciphertext == expectedCiphertext)

        let vectorPayload = AESEncryptedPayload(
            ciphertext: expectedCiphertext,
            iv: iv,
            authenticationTag: nil,
            mode: vector.mode,
            padding: .none
        )
        #expect(try AESCrypto.decrypt(vectorPayload, using: key) == plaintext)
    }

    @Test
    func gcmMatchesNISTEmptyPlaintextVector() throws {
        let key = Data(repeating: 0, count: 16)
        let nonce = Data(repeating: 0, count: 12)
        let expectedTag = try Self.data(hex: "58e2fccefa7e3061367f1d57a4e7455a")

        let payload = try AESCrypto.encrypt(Data(), using: key, mode: .gcm, iv: nonce)
        #expect(payload.ciphertext.isEmpty)
        #expect(payload.iv == nonce)
        #expect(payload.authenticationTag == expectedTag)
        #expect(try AESCrypto.decrypt(payload, using: key).isEmpty)
    }

    @Test
    func payloadCodableRoundTrips() throws {
        let key = try AESCrypto.generateKey()
        let payload = try AESCrypto.encrypt(Data("persisted payload".utf8), using: key)
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AESEncryptedPayload.self, from: encoded)

        #expect(decoded == payload)
        #expect(try AESCrypto.decrypt(decoded, using: key) == Data("persisted payload".utf8))
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

    private static func togglingFirstByte(of data: Data) -> Data {
        var result = data
        guard let firstIndex = result.indices.first else {
            return Data([1])
        }
        result[firstIndex] ^= 1
        return result
    }
}
