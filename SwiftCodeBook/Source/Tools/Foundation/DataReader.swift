//
//  DataReader.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/24.
//

import Foundation
import os

public final class DataReader: Sendable {
    @frozen public enum Error: Swift.Error, Sendable {
        case outOfBounds
    }
    
    private let data: Data
    private let offset = OSAllocatedUnfairLock(initialState: 0)
    
    public init(data: Data) {
        self.data = data
    }
    
    public var currentOffset: Int {
        offset.withLock { $0 }
    }
    
    public func moveToStart() {
        offset.withLock { $0 = 0 }
    }
    
    public func moveToOffset(_ newOffset: Int) throws {
        try offset.withLock { offset in
            guard newOffset >= 0 && newOffset < data.count else {
                throw Error.outOfBounds
            }
            offset = newOffset
        }
    }
    
    public func readNext<T>(as type: T.Type) throws -> T where T: Sendable {
        try offset.withLock { offset in
            let alignment = MemoryLayout<T>.alignment
            let atMisalignedOffset = offset % alignment > 0
            if atMisalignedOffset {
                offset = (offset / alignment + 1) * alignment
            }
            guard offset + MemoryLayout<T>.size <= data.count else {
                throw Error.outOfBounds
            }
            let value = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: offset, as: type)
            }
            offset += MemoryLayout<T>.size
            return value
        }
    }
}
