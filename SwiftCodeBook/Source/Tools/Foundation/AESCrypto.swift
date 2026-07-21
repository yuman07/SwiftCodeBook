//
//  AESCrypto.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/7/10.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

@frozen public enum AESMode: Equatable, Sendable {
    @frozen public enum Kind: String, CaseIterable, Codable, Sendable {
        case gcm
        case cbc
        case ecb
        case cfb
        case cfb8
        case ctr
        case ofb
    }

    /// Generates a secure random 12-byte nonce when `nonce` is `nil`.
    case gcm(nonce: Data? = nil, authenticating: Data = Data())
    /// Generates a secure random 16-byte IV when `iv` is `nil`.
    case cbc(iv: Data? = nil, padding: AESPadding = .pkcs7)
    /// ECB does not use an IV.
    case ecb(padding: AESPadding = .pkcs7)
    /// CFB uses 128-bit segments and generates a secure random 16-byte IV when `iv` is `nil`.
    case cfb(iv: Data? = nil)
    /// CFB8 uses 8-bit segments and generates a secure random 16-byte IV when `iv` is `nil`.
    case cfb8(iv: Data? = nil)
    /// Generates a secure random 16-byte counter block when `initialCounter` is `nil`.
    case ctr(initialCounter: Data? = nil)
    /// Generates a secure random 16-byte IV when `iv` is `nil`.
    case ofb(iv: Data? = nil)

    public var kind: Kind {
        switch self {
        case .gcm:
            .gcm
        case .cbc:
            .cbc
        case .ecb:
            .ecb
        case .cfb:
            .cfb
        case .cfb8:
            .cfb8
        case .ctr:
            .ctr
        case .ofb:
            .ofb
        }
    }
}

@frozen public enum AESPadding: String, CaseIterable, Codable, Sendable {
    case none
    case pkcs7
}

@frozen public enum AESKeySize: Int, CaseIterable, Codable, Sendable {
    case bits128 = 128
    case bits192 = 192
    case bits256 = 256

    public var byteCount: Int {
        rawValue / 8
    }
}

public struct AESEncryptedPayload: Codable, Equatable, Sendable {
    public let ciphertext: Data
    /// A 12-byte nonce for GCM, no value for ECB, or a 16-byte IV for other modes.
    public let iv: Data?
    public let authenticationTag: Data?
    public let mode: AESMode.Kind
    public let padding: AESPadding

    public init(
        ciphertext: Data,
        iv: Data?,
        authenticationTag: Data?,
        mode: AESMode.Kind,
        padding: AESPadding
    ) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.authenticationTag = authenticationTag
        self.mode = mode
        self.padding = padding
    }
}

public enum AESCryptoError: Error, Equatable, Sendable {
    case invalidKeyLength(actual: Int)
    case missingIV(mode: AESMode.Kind)
    case unexpectedIV(mode: AESMode.Kind)
    case invalidIVLength(mode: AESMode.Kind, expected: Int, actual: Int)
    case missingAuthenticationTag
    case unexpectedAuthenticationTag(mode: AESMode.Kind)
    case invalidAuthenticationTagLength(expected: Int, actual: Int)
    case unsupportedAuthenticatedData(mode: AESMode.Kind)
    case unsupportedPadding(AESPadding, mode: AESMode.Kind)
    case invalidInputLength(mode: AESMode.Kind, blockSize: Int, actual: Int)
    case authenticationFailed
    case randomGenerationFailed(status: OSStatus)
    case commonCryptoFailed(status: CCCryptorStatus)
}

extension AESCryptoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKeyLength(let actual):
            "AES keys must contain 16, 24, or 32 bytes; received \(actual)."
        case .missingIV(let mode):
            "AES-\(mode.rawValue.uppercased()) requires an IV or nonce."
        case .unexpectedIV(let mode):
            "AES-\(mode.rawValue.uppercased()) does not accept an IV."
        case .invalidIVLength(let mode, let expected, let actual):
            "AES-\(mode.rawValue.uppercased()) requires a \(expected)-byte IV or nonce; received \(actual)."
        case .missingAuthenticationTag:
            "AES-GCM requires an authentication tag."
        case .unexpectedAuthenticationTag(let mode):
            "AES-\(mode.rawValue.uppercased()) does not use an authentication tag."
        case .invalidAuthenticationTagLength(let expected, let actual):
            "AES-GCM requires a \(expected)-byte authentication tag; received \(actual)."
        case .unsupportedAuthenticatedData(let mode):
            "AES-\(mode.rawValue.uppercased()) does not support authenticated data."
        case .unsupportedPadding(let padding, let mode):
            "AES-\(mode.rawValue.uppercased()) does not support \(padding.rawValue) padding."
        case .invalidInputLength(let mode, let blockSize, let actual):
            "AES-\(mode.rawValue.uppercased()) input must be a multiple of \(blockSize) bytes; received \(actual)."
        case .authenticationFailed:
            "AES-GCM authentication failed."
        case .randomGenerationFailed(let status):
            "Secure random generation failed with OSStatus \(status)."
        case .commonCryptoFailed(let status):
            "CommonCrypto failed with status \(status)."
        }
    }
}

public enum AESCrypto {
    public static let blockSize = kCCBlockSizeAES128
    public static let gcmNonceSize = 12
    public static let gcmAuthenticationTagSize = 16

    public static func generateKey(size: AESKeySize = .bits256) throws -> Data {
        try randomData(count: size.byteCount)
    }

    /// Generates a mode-appropriate nonce or IV. ECB returns `nil`.
    public static func generateIV(for mode: AESMode.Kind) throws -> Data? {
        switch mode {
        case .gcm:
            try randomData(count: gcmNonceSize)
        case .ecb:
            nil
        case .cbc, .cfb, .cfb8, .ctr, .ofb:
            try randomData(count: blockSize)
        }
    }

    /// Encrypts data using GCM by default. Each mode exposes only its supported parameters.
    public static func encrypt(
        _ plaintext: Data,
        using key: Data,
        mode: AESMode = .gcm()
    ) throws -> AESEncryptedPayload {
        try validateKey(key)

        switch mode {
        case .gcm(let requestedNonce, let authenticatedData):
            let nonceData = try encryptionIV(for: .gcm, requestedIV: requestedNonce)
            guard let nonceData else {
                throw AESCryptoError.missingIV(mode: .gcm)
            }
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.seal(
                plaintext,
                using: SymmetricKey(data: key),
                nonce: nonce,
                authenticating: authenticatedData
            )
            return AESEncryptedPayload(
                ciphertext: sealedBox.ciphertext,
                iv: Data(sealedBox.nonce),
                authenticationTag: sealedBox.tag,
                mode: .gcm,
                padding: .none
            )
        case .cbc(let requestedIV, let padding):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .cbc,
                padding: padding,
                requestedIV: requestedIV
            )
        case .ecb(let padding):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .ecb,
                padding: padding,
                requestedIV: nil
            )
        case .cfb(let requestedIV):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .cfb,
                padding: .none,
                requestedIV: requestedIV
            )
        case .cfb8(let requestedIV):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .cfb8,
                padding: .none,
                requestedIV: requestedIV
            )
        case .ctr(let requestedCounter):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .ctr,
                padding: .none,
                requestedIV: requestedCounter
            )
        case .ofb(let requestedIV):
            return try makeCommonCryptoPayload(
                plaintext,
                using: key,
                mode: .ofb,
                padding: .none,
                requestedIV: requestedIV
            )
        }
    }

    public static func decrypt(
        _ payload: AESEncryptedPayload,
        using key: Data,
        authenticating authenticatedData: Data = Data()
    ) throws -> Data {
        try validateKey(key)
        _ = try validatedPadding(payload.padding, for: payload.mode)
        guard payload.mode == .gcm || authenticatedData.isEmpty else {
            throw AESCryptoError.unsupportedAuthenticatedData(mode: payload.mode)
        }

        if payload.mode == .gcm {
            let nonceData = try decryptionIV(for: .gcm, payloadIV: payload.iv)
            guard let nonceData else {
                throw AESCryptoError.missingIV(mode: .gcm)
            }
            guard let authenticationTag = payload.authenticationTag else {
                throw AESCryptoError.missingAuthenticationTag
            }
            guard authenticationTag.count == gcmAuthenticationTagSize else {
                throw AESCryptoError.invalidAuthenticationTagLength(
                    expected: gcmAuthenticationTagSize,
                    actual: authenticationTag.count
                )
            }

            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: payload.ciphertext,
                tag: authenticationTag
            )
            do {
                return try AES.GCM.open(
                    sealedBox,
                    using: SymmetricKey(data: key),
                    authenticating: authenticatedData
                )
            } catch CryptoKitError.authenticationFailure {
                throw AESCryptoError.authenticationFailed
            }
        }

        if payload.authenticationTag != nil {
            throw AESCryptoError.unexpectedAuthenticationTag(mode: payload.mode)
        }
        try validateBlockAlignment(of: payload.ciphertext, for: payload.mode)
        let iv = try decryptionIV(for: payload.mode, payloadIV: payload.iv)
        return try commonCrypto(
            payload.ciphertext,
            operation: CCOperation(kCCDecrypt),
            key: key,
            mode: payload.mode,
            padding: payload.padding,
            iv: iv
        )
    }
}

public extension Data {
    func aesEncrypted(
        using key: Data,
        mode: AESMode = .gcm()
    ) throws -> AESEncryptedPayload {
        try AESCrypto.encrypt(self, using: key, mode: mode)
    }
}

public extension AESEncryptedPayload {
    func decrypted(
        using key: Data,
        authenticating authenticatedData: Data = Data()
    ) throws -> Data {
        try AESCrypto.decrypt(self, using: key, authenticating: authenticatedData)
    }
}

private extension AESCrypto {
    static func validateKey(_ key: Data) throws {
        guard AESKeySize.allCases.contains(where: { $0.byteCount == key.count }) else {
            throw AESCryptoError.invalidKeyLength(actual: key.count)
        }
    }

    static func validatedPadding(
        _ padding: AESPadding,
        for mode: AESMode.Kind
    ) throws -> AESPadding {
        guard padding == .none || mode.supportsPKCS7 else {
            throw AESCryptoError.unsupportedPadding(padding, mode: mode)
        }
        return padding
    }

    static func validateBlockAlignment(of input: Data, for mode: AESMode.Kind) throws {
        guard mode.requiresBlockAlignment, !input.count.isMultiple(of: blockSize) else {
            return
        }
        throw AESCryptoError.invalidInputLength(
            mode: mode,
            blockSize: blockSize,
            actual: input.count
        )
    }

    static func makeCommonCryptoPayload(
        _ plaintext: Data,
        using key: Data,
        mode: AESMode.Kind,
        padding requestedPadding: AESPadding,
        requestedIV: Data?
    ) throws -> AESEncryptedPayload {
        let padding = try validatedPadding(requestedPadding, for: mode)
        if padding == .none {
            try validateBlockAlignment(of: plaintext, for: mode)
        }
        let iv = try encryptionIV(for: mode, requestedIV: requestedIV)
        let ciphertext = try commonCrypto(
            plaintext,
            operation: CCOperation(kCCEncrypt),
            key: key,
            mode: mode,
            padding: padding,
            iv: iv
        )
        return AESEncryptedPayload(
            ciphertext: ciphertext,
            iv: iv,
            authenticationTag: nil,
            mode: mode,
            padding: padding
        )
    }

    static func encryptionIV(for mode: AESMode.Kind, requestedIV: Data?) throws -> Data? {
        if mode == .ecb {
            guard requestedIV == nil else {
                throw AESCryptoError.unexpectedIV(mode: mode)
            }
            return nil
        }

        let expectedCount = mode == .gcm ? gcmNonceSize : blockSize
        if let requestedIV {
            guard requestedIV.count == expectedCount else {
                throw AESCryptoError.invalidIVLength(
                    mode: mode,
                    expected: expectedCount,
                    actual: requestedIV.count
                )
            }
            return requestedIV
        }
        return try randomData(count: expectedCount)
    }

    static func decryptionIV(for mode: AESMode.Kind, payloadIV: Data?) throws -> Data? {
        if mode == .ecb {
            guard payloadIV == nil else {
                throw AESCryptoError.unexpectedIV(mode: mode)
            }
            return nil
        }

        guard let payloadIV else {
            throw AESCryptoError.missingIV(mode: mode)
        }
        let expectedCount = mode == .gcm ? gcmNonceSize : blockSize
        guard payloadIV.count == expectedCount else {
            throw AESCryptoError.invalidIVLength(
                mode: mode,
                expected: expectedCount,
                actual: payloadIV.count
            )
        }
        return payloadIV
    }

    static func commonCrypto(
        _ input: Data,
        operation: CCOperation,
        key: Data,
        mode: AESMode.Kind,
        padding: AESPadding,
        iv: Data?
    ) throws -> Data {
        guard let commonCryptoMode = mode.commonCryptoMode else {
            throw AESCryptoError.commonCryptoFailed(status: CCCryptorStatus(kCCParamError))
        }

        var cryptor: CCCryptorRef?
        let createStatus: CCCryptorStatus = key.withUnsafeBytes { keyBytes in
            guard let keyAddress = keyBytes.baseAddress else {
                return CCCryptorStatus(kCCParamError)
            }

            func create(ivAddress: UnsafeRawPointer?) -> CCCryptorStatus {
                CCCryptorCreateWithMode(
                    operation,
                    commonCryptoMode,
                    CCAlgorithm(kCCAlgorithmAES),
                    padding.commonCryptoPadding,
                    ivAddress,
                    keyAddress,
                    key.count,
                    nil,
                    0,
                    0,
                    mode == .ctr
                        ? CCModeOptions(kCCModeOptionCTR_BE)
                        : CCModeOptions(0),
                    &cryptor
                )
            }

            if let iv {
                return iv.withUnsafeBytes { ivBytes in
                    guard let ivAddress = ivBytes.baseAddress else {
                        return CCCryptorStatus(kCCParamError)
                    }
                    return create(ivAddress: ivAddress)
                }
            }
            return create(ivAddress: nil)
        }

        guard createStatus == kCCSuccess, let cryptor else {
            throw AESCryptoError.commonCryptoFailed(status: createStatus)
        }
        defer { CCCryptorRelease(cryptor) }

        let outputCapacity = CCCryptorGetOutputLength(cryptor, input.count, true)
        var output = Data(count: max(outputCapacity, 1))
        var updateLength = 0
        let updateStatus = input.withUnsafeBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                CCCryptorUpdate(
                    cryptor,
                    inputBytes.baseAddress,
                    inputBytes.count,
                    outputBytes.baseAddress,
                    outputBytes.count,
                    &updateLength
                )
            }
        }
        guard updateStatus == kCCSuccess else {
            throw AESCryptoError.commonCryptoFailed(status: updateStatus)
        }

        var finalLength = 0
        let finalStatus = output.withUnsafeMutableBytes { outputBytes in
            CCCryptorFinal(
                cryptor,
                outputBytes.baseAddress?.advanced(by: updateLength),
                outputBytes.count - updateLength,
                &finalLength
            )
        }
        guard finalStatus == kCCSuccess else {
            throw AESCryptoError.commonCryptoFailed(status: finalStatus)
        }

        output.removeSubrange((updateLength + finalLength)..<output.count)
        return output
    }

    static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status: OSStatus = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, bytes.count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw AESCryptoError.randomGenerationFailed(status: status)
        }
        return data
    }
}

private extension AESMode.Kind {
    var supportsPKCS7: Bool {
        self == .cbc || self == .ecb
    }

    var requiresBlockAlignment: Bool {
        self == .cbc || self == .ecb
    }

    var commonCryptoMode: CCMode? {
        switch self {
        case .gcm:
            nil
        case .cbc:
            CCMode(kCCModeCBC)
        case .ecb:
            CCMode(kCCModeECB)
        case .cfb:
            CCMode(kCCModeCFB)
        case .cfb8:
            CCMode(kCCModeCFB8)
        case .ctr:
            CCMode(kCCModeCTR)
        case .ofb:
            CCMode(kCCModeOFB)
        }
    }
}

private extension AESPadding {
    var commonCryptoPadding: CCPadding {
        switch self {
        case .none:
            CCPadding(ccNoPadding)
        case .pkcs7:
            CCPadding(ccPKCS7Padding)
        }
    }
}
