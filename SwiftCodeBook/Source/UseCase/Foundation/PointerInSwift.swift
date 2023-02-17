//
//  PointerInSwift.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/17.
//

import Foundation

private struct SampleStruct {
    let number: UInt32
    let flag: Bool
}

private final class SampleClass {
    let number: UInt32
    let flag: Bool
    
    init(number: UInt32, flag: Bool) {
        self.number = number
        self.flag = flag
    }
}

struct TestPointerInSwift {
    
    func testMemoryLayout() {
        // 返回5
        // 此为该结构体在内存中不考虑内存对齐下，理论占用大小
        // UInt32(4) + Bool(1) == 5
        print(MemoryLayout<SampleStruct>.size)
        
        // 返回4
        // 此为该结构体以多少来内存对齐，比如这里为4，即实际占用的Byte数必须为4的倍数
        print(MemoryLayout<SampleStruct>.alignment)
        
        // 返回8
        // 此结构体在内存中实际占用的大小
        print(MemoryLayout<SampleStruct>.stride)
        
        print("---------")
        
        // 返回8
        // 因为class存储在堆中，这里持有的只是指针，因此为8
        print(MemoryLayout<SampleClass>.size)
        
        // 返回8
        // 因为class存储在堆中，这里持有的只是指针，因此为8
        print(MemoryLayout<SampleClass>.alignment)
        
        // 返回8
        // 因为class存储在堆中，这里持有的只是指针，因此为8
        print(MemoryLayout<SampleClass>.stride)
    }
    
    func testPointer0() {
        // Swift中的原始指针类型看起来很多，有8种，但其实有规律可寻：
        // Unsafe[Mutable][Raw][Buffer]Pointer[<T>]
        // 所有指针都以'Unsafe'开头，表示该指针直接访问内存，是不安全的，使用时要多加注意
        // 'Mutable' 表示该指针是否支持写入
        // 'Raw' 表示该指针是否抹去了类型，即带了Raw表示该指针指向一个个Byte
        // 'Buffer' 表示该指针是否支持如集合一样的遍历
    }
    
    /// 使用Raw指针加载两个整数并输出
    func testPointer1() {
        let count = 2
        let alignment = MemoryLayout<Int>.alignment
        let size = MemoryLayout<Int>.stride
        
        // 因为要写入整数，所以为mutable
        let rawPoint = UnsafeMutableRawPointer.allocate(byteCount: count * size, alignment: alignment)
        // 一定要记得释放指针
        defer { rawPoint.deallocate() }
        
        // 存储数据
        rawPoint.storeBytes(of: 100, as: Int.self)
        // 前进size个Byte，继续存储数据
        // 注意调用advanced是返回一个新的pointer，原来的rawPoint仍没有变
        rawPoint.advanced(by: size).storeBytes(of: 200, as: Int.self)
        
        // 加载数据并输出
        print(rawPoint.load(as: Int.self))
        print(rawPoint.advanced(by: size).load(as: Int.self))
    }
    
    /// 使用Type指针加载两个整数并输出
    func testPointer2() {
        let count = 2
        
        // 因为有类型信息，因此只需要传入需要几个Int即可
        let pointer = UnsafeMutablePointer<Int>.allocate(capacity: count)
        // 先均初始化为0
        pointer.initialize(to: 0)
        // 注意有类型的指针的释放有两步，且顺序不能错
        defer {
            pointer.deinitialize(count: count)
            pointer.deallocate()
        }
        
        pointer.pointee = 100
        pointer.advanced(by: 1).pointee = 200
        
        print(pointer.pointee)
        print(pointer.advanced(by: 1).pointee)
        
        print("---------")
        
        // 使用bufferPointer进行遍历
        let bufferPointer = UnsafeBufferPointer(start: pointer, count: 2)
        bufferPointer.enumerated().forEach { index, value in
            print(value)
        }
        // 注意bufferPointer不需要释放，因为bufferPointer是pointer的包装，而pointer已经在上面释放过了
    }
    
    /// RawPointer <--> TypePointer
    func testPointer3() {
        let count = 2
        let alignment = MemoryLayout<Int>.alignment
        let size = MemoryLayout<Int>.stride
        
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: size * count, alignment: alignment)
        defer { rawPointer.deallocate() }
        
        // 通过内存绑定使得rawPointer转为一个typePointer
        // 但注意其实两者共享内存，因此也只需要释放一次即可
        // 另外只能绑定一次，且类型必须正确
        let pointer = rawPointer.bindMemory(to: Int.self, capacity: count)
        
        rawPointer.storeBytes(of: 100, as: Int.self)
        rawPointer.advanced(by: size).storeBytes(of: 200, as: Int.self)
        
        print(pointer.pointee)
        print(pointer.advanced(by: 1).pointee)
        
        pointer.pointee = 300
        pointer.advanced(by: 1).pointee = 400
        
        print(rawPointer.load(as: Int.self))
        print(rawPointer.advanced(by: size).load(as: Int.self))
    }
    
    /// 获取一个现有实例的Pointer
    func testPointer4() {
        var sampleStruct = SampleStruct(number: 25, flag: true)
        
        // 注意以下都千万不要从 withUnsafeXXX 中返回指针
        // 只应该在{}内使用，而不要传到外部
        
        // 该结构体的RawPointer，即Bytes
        withUnsafeBytes(of: &sampleStruct) { bytes in
            for byte in bytes { print(byte) }
        }

        print("---------")
        
        // 该结构体的类型指针
        withUnsafePointer(to: sampleStruct) { pointer in
            print(pointer.pointee)
        }
        
        print("---------")
        
        // 该结构体的可变Bytes
        // 这里尝试修改flag为false
        withUnsafeMutableBytes(of: &sampleStruct) { bytes in
            bytes.storeBytes(of: false, toByteOffset: MemoryLayout<UInt32>.stride, as: Bool.self)
        }
        print(sampleStruct)
        
        print("---------")
        
        // 该结构体的可变类型指针
        // 这里尝试修改该结构体为(number: 30, flag: true)
        withUnsafeMutablePointer(to: &sampleStruct) { pointer in
            pointer.pointee = SampleStruct(number: 30, flag: true)
        }
        print(sampleStruct)
        
        print("---------")
        
        // 数组获取buffer指针
        let array = [SampleStruct(number: 10, flag: true), SampleStruct(number: 20, flag: false)]
        array.withUnsafeBufferPointer { pointer in
            pointer.enumerated().forEach { index, value in
                print(value)
            }
        }
        
        print("---------")
        
        // 注意由于class存储在堆中，这里实际遍历的是class指针的Bytes
        let sampleClass = SampleClass(number: 25, flag: true)
        withUnsafeBytes(of: sampleClass) { bytes in
            for byte in bytes {
                print(byte)
            }
        }
    }
}
