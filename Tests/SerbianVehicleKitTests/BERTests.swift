import XCTest
@testable import SerbianVehicleKit

final class BERTests: XCTestCase {

    /// Builds a BER element: tag byte(s) + short length + value.
    private func element(_ tag: [UInt8], _ value: [UInt8]) -> [UInt8] {
        precondition(value.count < 0x80)
        return tag + [UInt8(value.count)] + value
    }

    func testParsesNestedStructure() throws {
        let make = element([0x87], Array("ZASTAVA".utf8))          // primitive
        let a3 = element([0xA3], make)                             // constructed
        let reg = element([0x81], Array("BG123-AA".utf8))          // primitive
        let node71 = element([0x71], reg + a3)                     // constructed

        let root = try BER.parse(node71)
        XCTAssertEqual(root.access([0x71, 0x81]).map { String(bytes: $0, encoding: .utf8) }, "BG123-AA")
        XCTAssertEqual(root.string(0x71, 0xA3, 0x87), "ZASTAVA")
        XCTAssertNil(root.string(0x71, 0x99))                      // missing tag
    }

    func testMultiByteTag() throws {
        // 0x9F33 is a two-byte tag (first byte has low 5 bits set).
        let node = element([0x71], element([0x9F, 0x33], Array("SRB".utf8)))
        let root = try BER.parse(node)
        XCTAssertEqual(root.string(0x71, 0x9F33), "SRB")
    }

    func testParseLengthForms() throws {
        XCTAssertEqual(try BER.parseLength([0x7F]).0, 0x7F)                 // short form
        XCTAssertEqual(try BER.parseLength([0x81, 0x90]).0, 0x90)          // 1-byte long form
        XCTAssertEqual(try BER.parseLength([0x82, 0x01, 0x00]).0, 0x0100)  // 2-byte long form
        XCTAssertThrowsError(try BER.parseLength([0x80]))                  // indefinite → invalid
    }

    func testMergeCombinesChildren() throws {
        let fileA = element([0x71], element([0x81], Array("REG".utf8)))
        let fileB = element([0x72], element([0x98], Array("M1".utf8)))
        let root = try BER.parse(fileA)
        try root.merge(try BER.parse(fileB))
        XCTAssertEqual(root.string(0x71, 0x81), "REG")
        XCTAssertEqual(root.string(0x72, 0x98), "M1")
    }
}
