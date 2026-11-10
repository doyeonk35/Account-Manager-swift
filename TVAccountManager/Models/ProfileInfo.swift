import Foundation

/// 로그인 중 프로필 화면에서 수집한 TVING 프로필. PIN은 여기 두지 않는다 — Keychain 전용.
struct ProfileInfo: Codable, Identifiable, Equatable, Sendable {
    let profileNo: Int
    var name: String
    var isLocked: Bool
    var isMain: Bool        // profileType "M"
    var gradeCode: String

    var id: Int { profileNo }

    enum CodingKeys: String, CodingKey {
        case name
        case profileNo = "profile_no"
        case isLocked = "is_locked"
        case isMain = "is_main"
        case gradeCode = "grade_code"
    }

    /// 연령 설정 표시용. `CPTG0019`(제한 없음)만 실제 화면으로 확인했다.
    var gradeDisplayName: String {
        switch gradeCode {
        case "CPTG0019": String(localized: "No limit")
        // 아래 매핑은 코드 번호로 추정한 것이다 (웹 번들에 보이는 값). 틀리면 여기만 고친다.
        case "CPTG0000": String(localized: "All ages")
        case "CPTG0007": "7+"
        case "CPTG0012": "12+"
        case "CPTG0015": "15+"
        default: gradeCode
        }
    }

    /// 프로필 PIN은 숫자 4자리.
    static func isValidPin(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
