import XCTest
@testable import SerbianVehicleKit

final class VehicleDocumentTests: XCTestCase {

    private func element(_ tag: [UInt8], _ value: [UInt8]) -> [UInt8] {
        precondition(value.count < 0x80)
        return tag + [UInt8(value.count)] + value
    }

    func testExtractsFieldsFromBER() throws {
        let reg = element([0x81], Array("BG123-AA".utf8))
        let make = element([0xA3], element([0x87], Array("ZASTAVA".utf8)))
        let owner = element([0xA1], element([0xA2], element([0x84], Array("PETAR".utf8))))
        let root = try BER.parse(element([0x71], reg + make + owner))

        let doc = VehicleDocument(ber: root)
        XCTAssertEqual(doc.registrationNumberOfVehicle, "BG123-AA")
        XCTAssertEqual(doc.vehicleMake, "ZASTAVA")
        XCTAssertEqual(doc.ownerName, "PETAR")
        XCTAssertEqual(doc.vehicleType, "")   // absent → empty
    }

    func testUserFallsBackToSecondFile() throws {
        // Users data present only under 0x72 (second file layout).
        let usersName = element([0x72], element([0xA1], element([0xA9], element([0x84], Array("ANA".utf8)))))
        let root = try BER.parse(usersName)
        let doc = VehicleDocument(ber: root)
        XCTAssertEqual(doc.usersName, "ANA")
    }

    func testDateFormatting() {
        XCTAssertEqual(VehicleDocument.formatDate("20170726"), "26.07.2017")
        XCTAssertEqual(VehicleDocument.formatDate("99991231"), "31.12.9999")
        XCTAssertEqual(VehicleDocument.formatDate(""), "")       // unchanged if malformed
        XCTAssertEqual(VehicleDocument.formatDate("2017"), "2017")
    }

    func testCodableRoundTrip() throws {
        var doc = VehicleDocument()
        doc.registrationNumberOfVehicle = "BG123-AA"
        doc.vehicleMake = "ZASTAVA"
        doc.ownerName = "PETAR"
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(VehicleDocument.self, from: data)
        XCTAssertEqual(decoded, doc)
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("\"vehicleMake\""))
    }
}
