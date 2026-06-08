import XCTest
@testable import TvingLoginManager

final class KeychainServiceTests: XCTestCase {

    let service = KeychainService()
    var testAccountId: UUID!

    override func setUp() {
        super.setUp()
        testAccountId = UUID()
    }

    override func tearDown() {
        service.deletePassword(forAccountId: testAccountId)
        super.tearDown()
    }

    func testSaveAndLoad() {
        let saved = service.savePassword("mySecret123", forAccountId: testAccountId)
        XCTAssertTrue(saved)
        let loaded = service.loadPassword(forAccountId: testAccountId)
        XCTAssertEqual(loaded, "mySecret123")
    }

    func testLoadNonExistent() {
        let loaded = service.loadPassword(forAccountId: UUID())
        XCTAssertNil(loaded)
    }

    func testUpdate() {
        service.savePassword("old", forAccountId: testAccountId)
        let updated = service.updatePassword("new", forAccountId: testAccountId)
        XCTAssertTrue(updated)
        let loaded = service.loadPassword(forAccountId: testAccountId)
        XCTAssertEqual(loaded, "new")
    }

    func testDelete() {
        service.savePassword("toDelete", forAccountId: testAccountId)
        service.deletePassword(forAccountId: testAccountId)
        let loaded = service.loadPassword(forAccountId: testAccountId)
        XCTAssertNil(loaded)
    }

    func testSaveOrUpdateCreatesIfNotExist() {
        service.saveOrUpdate(password: "first", forAccountId: testAccountId)
        XCTAssertEqual(service.loadPassword(forAccountId: testAccountId), "first")
        service.saveOrUpdate(password: "second", forAccountId: testAccountId)
        XCTAssertEqual(service.loadPassword(forAccountId: testAccountId), "second")
    }
}
