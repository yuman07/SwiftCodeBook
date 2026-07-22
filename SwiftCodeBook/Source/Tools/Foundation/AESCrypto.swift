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

@frozen public enum AESCrypto: Sendable {
    private static let blockSize = kCCBlockSizeAES128
    private static let gcmAuthenticationTagSize = 16

    public static func encrypt(
        _ data: Data,
        using key: Data,
        mode: AESMode
    ) throws -> AESEncryptedPayload {
        try validateKey(key)

        switch mode {
        case let .gcm(requestedNonce, authenticatedData):
            let nonceData = try encryptionInitializationValue(
                for: mode,
                requestedValue: requestedNonce
            )
            do {
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
                    authenticationTag: sealedBox.tag,
                    authenticatedData: authenticatedData
                )
            } catch let error as CryptoKitError {
                throw AESCryptoError.cryptoKitFailed(error: error)
            }
        case .cbc, .ecb, .cfb, .cfb8, .ctr, .ofb:
            return try encryptCommonCrypto(data, using: key, mode: mode)
        }
    }

    public static func decrypt(
        _ payload: AESEncryptedPayload,
        using key: Data
    ) throws -> Data {
        try validateKey(key)

        switch payload {
        case let .gcm(encryptedData, nonceData, authenticationTag, authenticatedData):
            try validateInitializationValue(nonceData, for: .gcm(nonce: nonceData))
            guard authenticationTag.count == gcmAuthenticationTagSize else {
                throw AESCryptoError.invalidAuthenticationTagLength(
                    expected: gcmAuthenticationTagSize,
                    actual: authenticationTag.count
                )
            }
            do {
                let nonce = try AES.GCM.Nonce(data: nonceData)
                let sealedBox = try AES.GCM.SealedBox(
                    nonce: nonce,
                    ciphertext: encryptedData,
                    tag: authenticationTag
                )
                return try AES.GCM.open(
                    sealedBox,
                    using: SymmetricKey(data: key),
                    authenticating: authenticatedData
                )
            } catch let error as CryptoKitError {
                throw AESCryptoError.cryptoKitFailed(error: error)
            }
        case let .cbc(encryptedData, iv, padding):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cbc(iv: iv, padding: padding)
            )
        case let .ecb(encryptedData, padding):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ecb(padding: padding)
            )
        case let .cfb(encryptedData, iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cfb(iv: iv)
            )
        case let .cfb8(encryptedData, iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .cfb8(iv: iv)
            )
        case let .ctr(encryptedData, initialCounter):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ctr(initialCounter: initialCounter)
            )
        case let .ofb(encryptedData, iv):
            return try decryptCommonCrypto(
                encryptedData,
                using: key,
                mode: .ofb(iv: iv)
            )
        }
    }
    
    /// Generates a cryptographically secure random AES key.
    public static func generateRandomKey(size: AESKeySize = .bits256) throws -> Data {
        try randomData(count: size.byteCount)
    }
}

@frozen public enum AESMode: Sendable {
    /// Uses a secure random 12-byte nonce when `nonce` is `nil`.
    case gcm(nonce: Data? = nil, authenticating: Data = Data())
    /// Uses a secure random 16-byte IV when `iv` is `nil`.
    case cbc(iv: Data? = nil, padding: AESPadding = .pkcs7)
    /// ECB encrypts each block independently, so it does not use an IV.
    case ecb(padding: AESPadding = .pkcs7)
    /// CFB uses 128-bit segments and a secure random 16-byte IV when `iv` is `nil`.
    case cfb(iv: Data? = nil)
    /// CFB8 uses 8-bit segments and a secure random 16-byte IV when `iv` is `nil`.
    case cfb8(iv: Data? = nil)
    /// Uses a secure random 16-byte counter block when `initialCounter` is `nil`.
    case ctr(initialCounter: Data? = nil)
    /// Uses a secure random 16-byte IV when `iv` is `nil`.
    case ofb(iv: Data? = nil)
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

@frozen public enum AESEncryptedPayload: Sendable {
    case gcm(
        encryptedData: Data,
        nonce: Data,
        authenticationTag: Data,
        authenticatedData: Data = Data()
    )
    case cbc(encryptedData: Data, iv: Data, padding: AESPadding)
    case ecb(encryptedData: Data, padding: AESPadding)
    case cfb(encryptedData: Data, iv: Data)
    case cfb8(encryptedData: Data, iv: Data)
    case ctr(encryptedData: Data, initialCounter: Data)
    case ofb(encryptedData: Data, iv: Data)

    public var encryptedData: Data {
        switch self {
        case let .gcm(encryptedData, _, _, _): encryptedData
        case let .cbc(encryptedData, _, _): encryptedData
        case let .ecb(encryptedData, _): encryptedData
        case let .cfb(encryptedData, _): encryptedData
        case let .cfb8(encryptedData, _): encryptedData
        case let .ctr(encryptedData, _): encryptedData
        case let .ofb(encryptedData, _): encryptedData
        }
    }
}

public enum AESCryptoError: Error, Equatable, Sendable, LocalizedError {
    case invalidKeyLength(actual: Int)
    case invalidInitializationValueLength(expected: Int, actual: Int)
    case invalidAuthenticationTagLength(expected: Int, actual: Int)
    case unsupportedMode
    case missingInitializationValue
    case initializationValueNotSupported
    case invalidInputLength(blockSize: Int, actual: Int)
    case cryptoKitFailed(error: CryptoKitError)
    case randomGenerationFailed(status: OSStatus)
    case commonCryptoFailed(status: CCCryptorStatus)
    
    public var errorDescription: String? {
        switch self {
        case let .invalidKeyLength(actual): "AES keys must contain 16, 24, or 32 bytes; received \(actual)."
        case let .invalidInitializationValueLength(expected, actual): "AES requires a \(expected)-byte initialization value; received \(actual)."
        case let .invalidAuthenticationTagLength(expected, actual): "AES-GCM requires a \(expected)-byte authentication tag; received \(actual)."
        case .unsupportedMode: "The selected AES mode is not supported by this operation."
        case .missingInitializationValue: "The selected AES mode requires an initialization value."
        case .initializationValueNotSupported: "The selected AES mode does not use an initialization value."
        case let .invalidInputLength(blockSize, actual): "AES input must be a multiple of \(blockSize) bytes; received \(actual)."
        case let .cryptoKitFailed(error): "CryptoKit failed with error \(error)."
        case let .randomGenerationFailed(status): "Secure random generation failed with OSStatus \(status)."
        case let .commonCryptoFailed(status): "CommonCrypto failed with status \(status)."
        }
    }
}

private extension AESMode {
    var requiresBlockAlignment: Bool {
        switch self {
        case .cbc, .ecb: true
        case .gcm, .cfb, .cfb8, .ctr, .ofb: false
        }
    }

    var requiresInitializationValue: Bool {
        switch self {
        case .ecb: false
        case .gcm, .cbc, .cfb, .cfb8, .ctr, .ofb: true
        }
    }

    var initializationValue: Data? {
        switch self {
        case let .gcm(nonce, _): nonce
        case let .cbc(iv, _), let .cfb(iv), let .cfb8(iv), let .ofb(iv): iv
        case let .ctr(initialCounter): initialCounter
        case .ecb: nil
        }
    }

    var padding: AESPadding {
        switch self {
        case let .cbc(_, padding), let .ecb(padding): padding
        case .gcm, .cfb, .cfb8, .ctr, .ofb: .none
        }
    }

    var commonCryptoMode: CCMode? {
        switch self {
        case .gcm: nil
        case .cbc: CCMode(kCCModeCBC)
        case .ecb: CCMode(kCCModeECB)
        case .cfb: CCMode(kCCModeCFB)
        case .cfb8: CCMode(kCCModeCFB8)
        case .ctr: CCMode(kCCModeCTR)
        case .ofb: CCMode(kCCModeOFB)
        }
    }

    var commonCryptoOptions: CCModeOptions {
        switch self {
        case .ctr: CCModeOptions(kCCModeOptionCTR_BE)
        case .gcm, .cbc, .ecb, .cfb, .cfb8, .ofb: CCModeOptions(0)
        }
    }
}

private extension AESCrypto {
    static func validateKey(_ key: Data) throws {
        guard AESKeySize.allCases.contains(where: { $0.byteCount == key.count }) else {
            throw AESCryptoError.invalidKeyLength(actual: key.count)
        }
    }

    static func validateBlockAlignment(of input: Data, for mode: AESMode) throws {
        guard mode.requiresBlockAlignment, !input.count.isMultiple(of: blockSize) else {
            return
        }
        throw AESCryptoError.invalidInputLength(
            blockSize: blockSize,
            actual: input.count
        )
    }

    static func encryptCommonCrypto(
        _ data: Data,
        using key: Data,
        mode: AESMode
    ) throws -> AESEncryptedPayload {
        if mode.padding == .none {
            try validateBlockAlignment(of: data, for: mode)
        }

        let initializationValue: Data?
        if mode.requiresInitializationValue {
            initializationValue = try encryptionInitializationValue(
                for: mode,
                requestedValue: mode.initializationValue
            )
        } else {
            initializationValue = nil
        }

        let encryptedData = try commonCrypto(
            data,
            operation: CCOperation(kCCEncrypt),
            key: key,
            mode: mode,
            padding: mode.padding,
            iv: initializationValue
        )

        switch mode {
        case .gcm:
            throw AESCryptoError.unsupportedMode
        case let .cbc(_, padding):
            return .cbc(
                encryptedData: encryptedData,
                iv: try requiredInitializationValue(initializationValue),
                padding: padding
            )
        case let .ecb(padding):
            return .ecb(encryptedData: encryptedData, padding: padding)
        case .cfb:
            return .cfb(
                encryptedData: encryptedData,
                iv: try requiredInitializationValue(initializationValue)
            )
        case .cfb8:
            return .cfb8(
                encryptedData: encryptedData,
                iv: try requiredInitializationValue(initializationValue)
            )
        case .ctr:
            return .ctr(
                encryptedData: encryptedData,
                initialCounter: try requiredInitializationValue(initializationValue)
            )
        case .ofb:
            return .ofb(
                encryptedData: encryptedData,
                iv: try requiredInitializationValue(initializationValue)
            )
        }
    }

    static func requiredInitializationValue(_ value: Data?) throws -> Data {
        guard let value else {
            throw AESCryptoError.missingInitializationValue
        }
        return value
    }

    static func encryptionInitializationValue(
        for mode: AESMode,
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
        for mode: AESMode
    ) throws {
        let expectedCount = try expectedInitializationValueSize(for: mode)
        guard value.count == expectedCount else {
            throw AESCryptoError.invalidInitializationValueLength(
                expected: expectedCount,
                actual: value.count
            )
        }
    }

    static func expectedInitializationValueSize(for mode: AESMode) throws -> Int {
        switch mode {
        case .gcm: 12
        case .cbc, .cfb, .cfb8, .ctr, .ofb: blockSize
        case .ecb: throw AESCryptoError.initializationValueNotSupported
        }
    }

    static func decryptCommonCrypto(
        _ encryptedData: Data,
        using key: Data,
        mode: AESMode
    ) throws -> Data {
        try validateBlockAlignment(of: encryptedData, for: mode)
        if let initializationValue = mode.initializationValue {
            try validateInitializationValue(initializationValue, for: mode)
        }
        return try commonCrypto(
            encryptedData,
            operation: CCOperation(kCCDecrypt),
            key: key,
            mode: mode,
            padding: mode.padding,
            iv: mode.initializationValue
        )
    }

    static func commonCrypto(
        _ input: Data,
        operation: CCOperation,
        key: Data,
        mode: AESMode,
        padding: AESPadding,
        iv: Data?
    ) throws -> Data {
        guard let commonCryptoMode = mode.commonCryptoMode else {
            throw AESCryptoError.unsupportedMode
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
                    mode.commonCryptoOptions,
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

private extension AESPadding {
    var commonCryptoPadding: CCPadding {
        switch self {
        case .none: CCPadding(ccNoPadding)
        case .pkcs7: CCPadding(ccPKCS7Padding)
        }
    }
}
