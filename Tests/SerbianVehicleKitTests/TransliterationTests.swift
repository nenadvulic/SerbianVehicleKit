import XCTest
@testable import SerbianVehicleKit

final class TransliterationTests: XCTestCase {

    func testLatinPassesThrough() {
        // Vehicle cards store Latin already — must be unchanged.
        XCTAssertEqual(SerbianTransliteration.toLatin("NENAD VULIC"), "NENAD VULIC")
        XCTAssertEqual(SerbianTransliteration.toLatin("KEEPONAPPS DOO"), "KEEPONAPPS DOO")
        XCTAssertEqual(SerbianTransliteration.toLatin("BENZIN 98"), "BENZIN 98")
    }

    func testCyrillicIsConverted() {
        XCTAssertEqual(SerbianTransliteration.toLatin("ВУЛИЋ"), "VULIĆ")
        XCTAssertEqual(SerbianTransliteration.toLatin("ЊЕГОШ"), "NJEGOŠ")
    }

    func testDocumentLatinized() {
        var doc = VehicleDocument()
        doc.ownerName = "НЕНАД"
        doc.vehicleMake = "ZASTAVA"      // already latin
        let latin = doc.latinized()
        XCTAssertEqual(latin.ownerName, "NENAD")
        XCTAssertEqual(latin.vehicleMake, "ZASTAVA")
    }
}
