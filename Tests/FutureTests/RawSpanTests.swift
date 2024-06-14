//===--- RawSpanTests.swift -----------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import XCTest
import Future

final class RawSpanTests: XCTestCase {

  func testOptionalStorage() {
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.size, MemoryLayout<RawSpan?>.size
//    )
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.stride, MemoryLayout<RawSpan?>.stride
//    )
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.alignment, MemoryLayout<RawSpan?>.alignment
//    )
  }

  func testInitWithSpanOfIntegers() {
    let capacity = 4
    let a = Array(0..<capacity)
    let span = RawSpan(a.storage)
    XCTAssertEqual(span.count, capacity*MemoryLayout<Int>.stride)
    XCTAssertFalse(span.isEmpty)
  }

  func testInitWithEmptySpanOfIntegers() {
    let a: [Int] = []
    let span = RawSpan(a.storage)
    XCTAssertTrue(span.isEmpty)
  }

  func testInitWithRawBytes() {
    let capacity = 4
    let a = Array(0..<capacity)
    a.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: a)
      XCTAssertEqual(span.count, capacity*MemoryLayout<Int>.stride)
    }
  }

  func testWithRawPointer() {
    let capacity = 4
    let a = Array(0..<capacity)
    a.withUnsafeBytes {
      let pointer = $0.baseAddress!
      let span = RawSpan(
        unsafeRawPointer: pointer, count: capacity*MemoryLayout<Int>.stride, owner: a
      )
      XCTAssertEqual(span.count, capacity*MemoryLayout<Int>.stride)
    }
  }

  func testLoad() {
    let capacity = 4
    let s = (0..<capacity).map({ "\(#file)+\(#function) #\($0)" })
    s.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)
      let stride = MemoryLayout<String>.stride

      let s0 = span.load(as: String.self)
      XCTAssertEqual(s0.contains("0"), true)
      let s1 = span.load(fromByteOffset: stride, as: String.self)
      XCTAssertEqual(s1.contains("1"), true)
      let s2 = span.load(fromUncheckedByteOffset: 2*stride, as: String.self)
      XCTAssertEqual(s2.contains("2"), true)
    }
  }

  func testLoadUnaligned() {
    let capacity = 64
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)

      let u0 = span.dropFirst(2).loadUnaligned(as: UInt64.self)
      XCTAssertEqual(u0 & 0xff, 2)
      XCTAssertEqual(u0.byteSwapped & 0xff, 9)
      let u1 = span.loadUnaligned(fromByteOffset: 6, as: UInt64.self)
      XCTAssertEqual(u1 & 0xff, 6)
      let u3 = span.loadUnaligned(fromUncheckedByteOffset: 7, as: UInt32.self)
      XCTAssertEqual(u3 & 0xff, 7)
    }
  }

  func testSubscript() {
    let capacity = 4
    let b = (0..<capacity).map(Int8.init)
    b.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)
      let sub1 = span[offsets: 0..<2]
      let sub2 = span[offsets: ..<2]
      let sub3 = span[offsets: ...]
      let sub4 = span[uncheckedOffsets: 2...]
      XCTAssertTrue(
        sub1.view(as: UInt8.self)._elementsEqual(sub2.view(as: UInt8.self))
      )
      XCTAssertTrue(
        sub3.view(as: Int8.self)._elementsEqual(span.view(as: Int8.self))
      )
      XCTAssertFalse(
        sub4.view(as: Int8.self)._elementsEqual(sub3.view(as: Int8.self))
      )
    }
  }

  func testUncheckedSubscript() {
    let capacity = 32
    let b = (0..<capacity).map(UInt8.init)
    b.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)
      let prefix = span[offsets: 0..<8]
      let beyond = prefix[uncheckedOffsets: 16..<24]
      XCTAssertEqual(beyond.count, 8)
      XCTAssertEqual(beyond.load(as: UInt8.self), 16)
    }
  }

  func testUnsafeBytes() {
    let capacity = 4
    let array = Array(0..<capacity)
    let span = RawSpan(array.storage)
    array.withUnsafeBytes {  b1 in
      span.withUnsafeBytes { b2 in
        XCTAssertTrue(b1.elementsEqual(b2))
      }
    }

//FIXME: rdar://128694495 (Faulty escape diagnostic)
// Should we be able to derive a non-escapable value from a Span via unsafe pointers?
//    let copy = span.withUnsafeBytes {
//      RawSpan(unsafeBytes: copy $0, owner: span)
//    }
//    _ = copy
  }

  func testStrangeBorrow() {
    let array: [String] = ["0", "1", "2", "3"]
    _ = array

//    let rs = RawSpan(array.storage) // Initializer 'init(_:)' requires that 'String' conform to 'BitwiseCopyable'

//    let rs1 = array.storage.withUnsafeBufferPointer {
//      RawSpan(unsafeBytes: UnsafeRawBufferPointer($0), owner: array)
//    }                               // Lifetime-dependent value escapes its scope
//    _ = rs1

//    let rs2 = array.storage.withUnsafeBufferPointer {
//      UnsafeRawBufferPointer($0).withMemoryRebound(to: UInt8.self) { // requires that `Span` conform to `Escapable`
//        return Span(unsafeBufferPointer: $0, owner: array)
//      }
//    }
//    _ = rs2
  }

  func testPrefix() {
    let capacity = 4
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)
      XCTAssertEqual(span.count, capacity)
      XCTAssertEqual(span.prefix(1).load(as: UInt8.self), 0)
      XCTAssertEqual(
        span.prefix(capacity).load(fromByteOffset: capacity-1, as: UInt8.self),
        UInt8(capacity-1)
      )
      XCTAssertTrue(span.dropLast(capacity).isEmpty)
      XCTAssertEqual(
        span.dropLast(1).load(fromByteOffset: capacity-2, as: UInt8.self),
        UInt8(capacity-2)
      )

      XCTAssertTrue(span.prefix(upTo: 0).isEmpty)
      XCTAssertEqual(
        span.prefix(upTo: span.count).load(
          fromByteOffset: span.indices.last!, as: UInt8.self
        ),
        UInt8(capacity-1)
      )

      XCTAssertFalse(span.prefix(through: 0).isEmpty)
      XCTAssertEqual(
        span.prefix(through: 2).load(fromByteOffset: 2, as: UInt8.self), 2
      )
    }
  }

  func testSuffix() {
    let capacity = 4
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(unsafeBytes: $0, owner: $0)
      XCTAssertEqual(span.count, capacity)
      XCTAssertEqual(span.suffix(capacity).load(as: UInt8.self), 0)
      XCTAssertEqual(span.suffix(capacity-1).load(as: UInt8.self), 1)
      XCTAssertEqual(span.suffix(1).load(as: UInt8.self), UInt8(capacity-1))
      XCTAssertTrue(span.dropFirst(capacity).isEmpty)
      XCTAssertEqual(span.dropFirst(1).load(as: UInt8.self), 1)

      XCTAssertEqual(span.suffix(from: 0).count, a.count)
      XCTAssertTrue(span.suffix(from: span.count).isEmpty)
    }
  }

  func testBoundsChecking() {
    let capacity = 4
    let a = Array(0..<capacity)
    let span = RawSpan(a.storage)
    for o in span.indices {
      span.boundsCheckPrecondition(o)
    }
    // span.boundsCheckPrecondition(span.count)
  }
}
