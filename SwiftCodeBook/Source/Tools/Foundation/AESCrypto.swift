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

@frozen public enum AESMode: Sendable {
    @frozen public enum Kind: Sendable {
        case gcm
        case cbc
        case ecb
        case cfb
        case cfb8
        case ctr
        case ofb
    }

    /// Uses a secure random 12-byte nonce when `nonce` is `nil`.
    case gcm(nonce: Data? = nil, authenticating: Data = Data())
    /// Uses a secure random 16-byte IV when `iv` is `nil`.
    case cbc(iv: Data? = nil, padding: AESPadding = .pkcs7)
    /// ECB does not use an IV.
    case ecb(padding: AESPadding = .pkcs7)
    /// CFB uses 128-bit segments and a secure random 16-byte IV when `iv` is `nil`.
    case cfb(iv: Data? = nil)
    /// CFB8 uses 8-bit segments and a secure random 16-byte IV when `iv` is `nil`.
    case cfb8(iv: Data? = nil)
    /// Uses a secure random 16-byte counter block when `initialCounter` is `nil`.
    case ctr(initialCounter: Data? = nil)
    /// Uses a secure random 16-byte IV when `iv` is `nil`.
    case ofb(iv: Data? = nil)

    public var kind: Kind {
        switch self {
        case .gcm: .gcm
        case .cbc: .cbc
        case .ecb: .ecb
        case .cfb: .cfb
        case .cfb8: .cfb8
        case .ctr: .ctr
        case .ofb: .ofb
        }
    }
}

@frozen public enum AESPadding: Sendable {
    case none
    case pkcs7
}

@frozen public enum AESKeySize: CaseIterable, Sendable {
    case bits128
    case bits192
    case bits256

    public var byteCount: Int {
        switch self {
        case .bits128: 16
        case .bits192: 24
        case .bits256: 32
        }
    }
}

public enum AESEncryptedPayload: Sendable {
    case gcm(encryptedData: Data, nonce: Data, authenticationTag: Data)
    case cbc(encryptedData: Data, iv: Data, padding: AESPadding)
    case ecb(encryptedData: Data, padding: AESPadding)
    case cfb(encryptedData: Data, iv: Data)
    case cfb8(encryptedData: Data, iv: Data)
    case ctr(encryptedData: Data, initialCounter: Data)
    case ofb(encryptedData: Data, iv: Data)

    public var encryptedData: Data {
        switch self {
        case .gcm(let encryptedData, _, _): encryptedData
        case .cbc(let encryptedData, _, _): encryptedData
        case .ecb(let encryptedData, _): encryptedData
        case .cfb(let encryptedData, _): encryptedData
        case .cfb8(let encryptedData, _): encryptedData
        case .ctr(let encryptedData, _): encryptedData
        case .ofb(let encryptedData, _): encryptedData
        }
    }
}

public enum AESCryptoError: Error, Equatable, Sendable {
    case invalidKeyLength(actual: Int)
    case invalidIVLength(mode: AESMode.Kind, expected: Int, actual: Int)
    case invalidAuthenticationTagLength(expected: Int, actual: Int)
    case unsupportedAuthenticatedData(mode: AESMode.Kind)
    case invalidInputLength(mode: AESMode.Kind, blockSize: Int, actual: Int)
    case authenticationFailed
    case randomGenerationFailed(status: OSStatus)
    case commonCryptoFailed(status: CCCryptorStatus)
}

extension AESCryptoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKeyLength(let actual): "AES keys must contain 16, 24, or 32 bytes; received \(actual)."
        case .invalidIVLength(let mode, let expected, let actual): "AES-\(mode) requires a \(expected)-byte IV or nonce; received \(actual)."
        case .invalidAuthenticationTagLength(let expected, let actual): "AES-GCM requires a \(expected)-byte authentication tag; received \(actual)."
        case .unsupportedAuthenticatedData(let mode): "AES-\(mode) does not support authenticated data."
        case .invalidInputLength(let mode, let blockSize, let actual): "AES-\(mode) input must be a multiple of \(blockSize) bytes; received \(actual)."
        case .authenticationFailed: "AES-GCM authentication failed."
        case .randomGenerationFailed(let status): "Secure random generation failed with OSStatus \(status)."
        case .commonCryptoFailed(let status): "CommonCrypto failed with status \(status)."
        }
    }
}

public enum AESCrypto {
    private static let blockSize = kCCBlockSizeAES128
    private static let gcmNonceSize = 12
    private static let gcmAuthenticationTagSize = 16

    /// Generates a cryptographically secure random AES key.
    public static func generateRandomKey(size: AESKeySize = .bits256) throws -> Data {
        try randomData(count: size.byteCount)
    }

    /// Encrypts data using the selected mode.
    public static func encrypt(
        _ data: Data,
        using key: Data,
        mode: AESMode
    ) throws -> AESEncryptedPayload {
        try validateKey(key)

        switch mode {
        case .gcm(let requestedNonce, let authenticatedData):
            let nonceData = try encryptionInitializationValue(
                for: .gcm,
                requestedValue: requestedNonce
            )
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.seal(
                data,
                using: SymmetricKey(data: key),
                nonce: nonce,
                authenticating: authenticatedData
            )
            return .gcm(
                encryptedData: sealedBox.ciphertext,
                nonce: Data(sealedBox.nonce),
                authenticationTag: sealedBox.tag
            )
        case .cbc(let requestedIV, let padding):
            return try makeCommonCryptoPayload(
                data,
                using: key,
                mode: .cbc,
                padding: padding,
                requestedIV: requestedIV
            )
        case .ecb(let padding):
            return try makeCommonCryptoPayload(
                data,
                using: key,
                mode: .ecb,
                padding: padding,
                requestedIV: nil
            )
        case .cfb(let requestedIV):
            return try makeCommonCryptoPayload(
                data,
                using: key,
                mode: .cfb,
                padding: .none,
                requestedIV: requestedIV
            )
        case .cfb8(let requestedIV):
            return try makeCommonCryptoPayload(
                data,
                using: key,
                mode: .cfb8,
                padding: .none,
                requestedIV: requestedIV
            )
        case .ctr(let requestedCounter):
            return try makeCommonCryptoPayload(
                data,
                using: key,
                mode: .ctr,
                padding: .none,
                requestedIV: requestedCounter
            )
        case .ofb(let requestedIV):
            return try makeCommonCryptoPayload(
                data,
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
        guard payload.kind == .gcm || authenticatedData.isEmpty else {
            throw AESCryptoError.unsupportedAuthenticatedData(mode: payload.kind)
        }

        switch payload {
        case .gcm(let encryptedData, let nonceData, let authenticationTag):
            try validateInitializationValue(nonceData, for: .gcm)
            guard authenticationTag.count == gcmAuthenticationTagSize else {
                throw AESCryptoError.invalidAuthenticationTagLength(
                    expected: gcmAuthenticationTagSize,
                    actual: authenticationTag.count
                )
            }
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: encryptedData,
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
        case .cbc(let encryptedData, let iv, let padding):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cbc,
                padding: padding,
                iv: iv
            )
        case .ecb(let encryptedData, let padding):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ecb,
                padding: padding,
                iv: nil
            )
        case .cfb(let encryptedData, let iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cfb,
                padding: .none,
                iv: iv
            )
        case .cfb8(let encryptedData, let iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cfb8,
                padding: .none,
                iv: iv
            )
        case .ctr(let encryptedData, let initialCounter):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ctr,
                padding: .none,
                iv: initialCounter
            )
        case .ofb(let encryptedData, let iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ofb,
                padding: .none,
                iv: iv
            )
        }
    }
}

public extension Data {
    func aesEncrypted(
        using key: Data,
        mode: AESMode
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
        _ data: Data,
        using key: Data,
        mode: AESMode.Kind,
        padding requestedPadding: AESPadding,
        requestedIV: Data?
    ) throws -> AESEncryptedPayload {
        if requestedPadding == .none {
            try validateBlockAlignment(of: data, for: mode)
        }
        let iv: Data?
        if mode == .ecb {
            iv = nil
        } else {
            iv = try encryptionInitializationValue(
                for: mode,
                requestedValue: requestedIV
            )
        }
        let encryptedData = try commonCrypto(
            data,
            operation: CCOperation(kCCEncrypt),
            key: key,
            mode: mode,
            padding: requestedPadding,
            iv: iv
        )
        switch mode {
        case .gcm:
            preconditionFailure("AES-GCM does not use CommonCrypto.")
        case .cbc:
            guard let iv else {
                preconditionFailure("AES-CBC requires an IV.")
            }
            return .cbc(encryptedData: encryptedData, iv: iv, padding: requestedPadding)
        case .ecb:
            return .ecb(encryptedData: encryptedData, padding: requestedPadding)
        case .cfb:
            guard let iv else {
                preconditionFailure("AES-CFB requires an IV.")
            }
            return .cfb(encryptedData: encryptedData, iv: iv)
        case .cfb8:
            guard let iv else {
                preconditionFailure("AES-CFB8 requires an IV.")
            }
            return .cfb8(encryptedData: encryptedData, iv: iv)
        case .ctr:
            guard let iv else {
                preconditionFailure("AES-CTR requires an initial counter.")
            }
            return .ctr(encryptedData: encryptedData, initialCounter: iv)
        case .ofb:
            guard let iv else {
                preconditionFailure("AES-OFB requires an IV.")
            }
            return .ofb(encryptedData: encryptedData, iv: iv)
        }
    }

    static func encryptionInitializationValue(
        for mode: AESMode.Kind,
        requestedValue: Data?
    ) throws -> Data {
        if let requestedValue {
            try validateInitializationValue(requestedValue, for: mode)
            return requestedValue
        }
        return try randomData(count: expectedInitializationValueSize(for: mode))
    }

    static func validateInitializationValue(
        _ value: Data,
        for mode: AESMode.Kind
    ) throws {
        let expectedCount = expectedInitializationValueSize(for: mode)
        guard value.count == expectedCount else {
            throw AESCryptoError.invalidIVLength(
                mode: mode,
                expected: expectedCount,
                actual: value.count
            )
        }
    }

    static func expectedInitializationValueSize(for mode: AESMode.Kind) -> Int {
        mode == .gcm ? gcmNonceSize : blockSize
    }

    static func decryptCommonCrypto(
        _ encryptedData: Data,
        using key: Data,
        mode: AESMode.Kind,
        padding: AESPadding,
        iv: Data?
    ) throws -> Data {
        try validateBlockAlignment(of: encryptedData, for: mode)
        if let iv {
            try validateInitializationValue(iv, for: mode)
        }
        return try commonCrypto(
            encryptedData,
            operation: CCOperation(kCCDecrypt),
            key: key,
            mode: mode,
            padding: padding,
            iv: iv
        )
    }

    static func commonCrypto(
        _ input: Data,
        operation: CCOperation,
        key: Data,
        mode: AESMode.Kind,
        padding: AESPadding,
        iv: Data?
    ) throws -> Data {
        var cryptor: CCCryptorRef?
        let createStatus: CCCryptorStatus = key.withUnsafeBytes { keyBytes in
            guard let keyAddress = keyBytes.baseAddress else {
                return CCCryptorStatus(kCCParamError)
            }

            func create(ivAddress: UnsafeRawPointer?) -> CCCryptorStatus {
                CCCryptorCreateWithMode(
                    operation,
                    mode.commonCryptoMode,
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
    var requiresBlockAlignment: Bool {
        self == .cbc || self == .ecb
    }

    var commonCryptoMode: CCMode {
        switch self {
        case .gcm: preconditionFailure("AES-GCM does not use CommonCrypto.")
        case .cbc: CCMode(kCCModeCBC)
        case .ecb: CCMode(kCCModeECB)
        case .cfb: CCMode(kCCModeCFB)
        case .cfb8: CCMode(kCCModeCFB8)
        case .ctr: CCMode(kCCModeCTR)
        case .ofb: CCMode(kCCModeOFB)
        }
    }
}

private extension AESEncryptedPayload {
    var kind: AESMode.Kind {
        switch self {
        case .gcm: .gcm
        case .cbc: .cbc
        case .ecb: .ecb
        case .cfb: .cfb
        case .cfb8: .cfb8
        case .ctr: .ctr
        case .ofb: .ofb
        }
    }
}

private extension AESPadding {
    var commonCryptoPadding: CCPadding {
        switch self {
        case .none: CCPadding(ccNoPadding)
        case .pkcs7: CCPadding(ccPKCS7Padding)
        }
    }
}
