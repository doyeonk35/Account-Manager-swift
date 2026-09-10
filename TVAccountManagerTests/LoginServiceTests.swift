import Testing
import Foundation
@testable import TVAccountManager

@Suite("LoginService 프로필 선택")
struct LoginServiceProfilePickTests {

    private func candidate(_ name: String, locked: Bool = false, restricted: Bool = false) -> ProfileCandidate {
        ProfileCandidate(name: name, locked: locked, restricted: restricted)
    }

    @Test("잠금 없는 첫 프로필을 고른다")
    func picksFirstUnlocked() {
        let rows = [
            candidate("도도"),
            candidate("재히"),
            candidate("규혁"),
        ]

        #expect(LoginService.pickProfile(from: rows) == 0)
    }

    @Test("잠긴 프로필은 건너뛴다")
    func skipsLocked() {
        let rows = [
            candidate("도도", locked: true),
            candidate("재히", locked: true),
            candidate("규혁"),
        ]

        #expect(LoginService.pickProfile(from: rows) == 2)
    }

    @Test("연령 제한 프로필은 후순위로 밀고 제한 없는 프로필을 고른다")
    func prefersUnrestricted() {
        let rows = [
            candidate("He", restricted: true),
            candidate("재히", restricted: true),
            candidate("규혁"),
        ]

        #expect(LoginService.pickProfile(from: rows) == 2)
    }

    @Test("제한 없는 프로필이 없으면 연령 제한 프로필이라도 고른다")
    func fallsBackToRestricted() {
        let rows = [
            candidate("도도", locked: true),
            candidate("He", restricted: true),
            candidate("규혁", restricted: true),
        ]

        #expect(LoginService.pickProfile(from: rows) == 1)
    }

    @Test("잠긴 프로필만 있으면 자동 선택을 포기한다")
    func givesUpWhenAllLocked() {
        let rows = [
            candidate("도도", locked: true),
            candidate("He", locked: true),
        ]

        #expect(LoginService.pickProfile(from: rows) == nil)
    }

    @Test("프로필이 없으면 자동 선택을 포기한다")
    func givesUpWhenEmpty() {
        #expect(LoginService.pickProfile(from: []) == nil)
    }

    @Test("잠금이 연령 제한보다 우선한다 — 잠긴 무제한 프로필보다 안 잠긴 제한 프로필을 고른다")
    func lockBeatsRestriction() {
        let rows = [
            candidate("도도", locked: true, restricted: false),
            candidate("He", locked: false, restricted: true),
        ]

        #expect(LoginService.pickProfile(from: rows) == 1)
    }

    // MARK: - 페이지에서 읽은 JSON 파싱

    @Test("프로필 테이블 JSON을 파싱한다")
    func decodesProfileTable() throws {
        let json = """
        [{"name":"도도","locked":false,"restricted":false},
         {"name":"He","locked":true,"restricted":true}]
        """

        let rows = try JSONDecoder().decode([ProfileCandidate].self, from: Data(json.utf8))

        #expect(rows.count == 2)
        #expect(rows[0].name == "도도")
        #expect(!rows[0].locked)
        #expect(rows[1].locked)
        #expect(rows[1].restricted)
        #expect(LoginService.pickProfile(from: rows) == 0)
    }
}
