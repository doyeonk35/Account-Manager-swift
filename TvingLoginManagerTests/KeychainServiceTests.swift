import Testing
import Foundation
@testable import TvingLoginManager

@Suite("KeychainService")
struct KeychainServiceTests {

    let service = KeychainService()

    @Test("비밀번호를 저장하고 로드한다")
    func saveAndLoad() {
        let id = UUID()
        defer { service.deletePassword(forAccountId: id) }

        let saved = service.savePassword("mySecret123", forAccountId: id)
        #expect(saved == true)
        #expect(service.loadPassword(forAccountId: id) == "mySecret123")
    }

    @Test("존재하지 않는 비밀번호는 nil을 반환한다")
    func loadNonExistent() {
        #expect(service.loadPassword(forAccountId: UUID()) == nil)
    }

    @Test("비밀번호를 업데이트한다")
    func update() {
        let id = UUID()
        defer { service.deletePassword(forAccountId: id) }

        service.savePassword("old", forAccountId: id)
        let updated = service.updatePassword("new", forAccountId: id)
        #expect(updated == true)
        #expect(service.loadPassword(forAccountId: id) == "new")
    }

    @Test("비밀번호를 삭제한다")
    func delete() {
        let id = UUID()

        service.savePassword("toDelete", forAccountId: id)
        service.deletePassword(forAccountId: id)
        #expect(service.loadPassword(forAccountId: id) == nil)
    }

    @Test("saveOrUpdate로 생성 및 업데이트한다")
    func saveOrUpdateCreatesAndUpdates() {
        let id = UUID()
        defer { service.deletePassword(forAccountId: id) }

        service.saveOrUpdate(password: "first", forAccountId: id)
        #expect(service.loadPassword(forAccountId: id) == "first")
        service.saveOrUpdate(password: "second", forAccountId: id)
        #expect(service.loadPassword(forAccountId: id) == "second")
    }
}
