import Foundation

@MainActor
final class AccountUseCase: Sendable {
    private let repository: AccountRepository

    init(repository: AccountRepository) {
        self.repository = repository
    }

    func loadAccounts() -> [AccountInfo] {
        var accounts = repository.loadAccounts()
        var needsResave = false

        for i in accounts.indices {
            if !accounts[i].password.isEmpty {
                repository.savePassword(accounts[i].password, forAccountId: accounts[i].id)
                accounts[i].password = ""
                needsResave = true
            } else {
                accounts[i].password = repository.loadPassword(forAccountId: accounts[i].id) ?? ""
            }
            accounts[i].profilePins = loadPins(accountId: accounts[i].id, profiles: accounts[i].profiles)
        }

        if needsResave {
            repository.saveAccounts(accounts)
        }

        return accounts
    }

    func addAccount(to accounts: inout [AccountInfo], title: String, username: String,
                    password: String, accountType: AccountType, planType: PlanType, memo: String,
                    isPinned: Bool = false) {
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? AccountInfo.generateRandomTitle() : title
        let account = AccountInfo(
            title: finalTitle, username: username, password: password,
            accountType: accountType, planType: planType, memo: memo,
            isPinned: isPinned, pinnedAt: isPinned ? Date() : nil
        )
        repository.savePassword(password, forAccountId: account.id)
        accounts.append(account)
        repository.saveAccounts(accounts)
    }

    func updateAccount(in accounts: inout [AccountInfo], id: UUID, title: String, username: String,
                       password: String, accountType: AccountType, planType: PlanType, memo: String,
                       isPinned: Bool, profilePins: [Int: String]? = nil) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].title = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? AccountInfo.generateRandomTitle() : title
        accounts[index].username = username
        accounts[index].password = password
        accounts[index].accountType = accountType
        accounts[index].planType = planType
        accounts[index].memo = memo
        let wasPinned = accounts[index].isPinned
        accounts[index].isPinned = isPinned
        if isPinned && !wasPinned {
            accounts[index].pinnedAt = Date()
        } else if !isPinned {
            accounts[index].pinnedAt = nil
        }
        repository.savePassword(password, forAccountId: id)
        if let profilePins {
            // 빈 값 = PIN 삭제. 4자리가 아닌 값은 폼 검증에서 막히지만 여기서도 저장하지 않는다.
            for profile in accounts[index].profiles where profile.isLocked {
                // 폼에 없던 프로필(편집 중 새로 수집됨)은 건드리지 않는다
                guard let pin = profilePins[profile.profileNo] else { continue }
                if ProfileInfo.isValidPin(pin) {
                    repository.saveProfilePin(pin, forAccountId: id, profileNo: profile.profileNo)
                    accounts[index].profilePins[profile.profileNo] = pin
                } else if pin.isEmpty {
                    repository.deleteProfilePin(forAccountId: id, profileNo: profile.profileNo)
                    accounts[index].profilePins.removeValue(forKey: profile.profileNo)
                }
            }
        }
        repository.saveAccounts(accounts)
    }

    func deleteAccount(from accounts: inout [AccountInfo], id: UUID) {
        if let account = accounts.first(where: { $0.id == id }) {
            for no in Set(account.profiles.map(\.profileNo)).union(account.profilePins.keys) {
                repository.deleteProfilePin(forAccountId: id, profileNo: no)
            }
        }
        accounts.removeAll { $0.id == id }
        repository.deletePassword(forAccountId: id)
        repository.saveAccounts(accounts)
    }

    /// 로그인 중 수집한 프로필 목록으로 교체한다. profileNo 기준으로 PIN을 이어 붙이고,
    /// 목록에서 사라진 프로필의 PIN은 Keychain에서 지운다.
    func mergeProfiles(in accounts: inout [AccountInfo], id: UUID, collected: [ProfileInfo]) {
        guard !collected.isEmpty, let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        // 사라졌거나 잠금이 풀린 프로필의 PIN은 지운다 (다시 잠기면 옛 PIN을 넣게 되므로)
        let locked = collected.filter(\.isLocked)
        let lockedNos = Set(locked.map(\.profileNo))
        let knownNos = Set(accounts[index].profiles.map(\.profileNo)).union(accounts[index].profilePins.keys)
        for no in knownNos where !lockedNos.contains(no) {
            repository.deleteProfilePin(forAccountId: id, profileNo: no)
        }
        let kept = accounts[index].profilePins.filter { lockedNos.contains($0.key) }
        // 새로 보이는 프로필도 Keychain에 PIN이 있으면 (가져오기 등) 살린다
        accounts[index].profilePins = kept.merging(loadPins(accountId: id, profiles: locked)) { old, _ in old }
        guard accounts[index].profiles != collected else { return }
        accounts[index].profiles = collected
        repository.saveAccounts(accounts)
    }

    private func loadPins(accountId: UUID, profiles: [ProfileInfo]) -> [Int: String] {
        var pins: [Int: String] = [:]
        for profile in profiles {
            if let pin = repository.loadProfilePin(forAccountId: accountId, profileNo: profile.profileNo) {
                pins[profile.profileNo] = pin
            }
        }
        return pins
    }

    func markUsed(in accounts: inout [AccountInfo], id: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].lastUsed = Date()
        repository.saveAccounts(accounts)
    }

    func loadPassword(forAccountId id: UUID) -> String? {
        repository.loadPassword(forAccountId: id)
    }

    func importPresetAccounts(into accounts: inout [AccountInfo]) -> PresetLoadResult {
        let result = PresetAccount.loadFromFile()

        switch result {
        case .failure(.fileNotFound):
            return .fileNotFound
        case .failure(.parseError(let message)):
            return .parseError(message)
        case .success(let presets):
            var imported = 0
            var skipped = 0

            for preset in presets {
                let isDuplicate = accounts.contains {
                    $0.username == preset.username && $0.accountType == preset.accountType
                }
                if isDuplicate {
                    skipped += 1
                } else {
                    let pins = preset.validProfilePins
                    let account = AccountInfo(
                        title: preset.title,
                        username: preset.username,
                        password: preset.password,
                        accountType: preset.accountType,
                        planType: preset.planType,
                        memo: preset.memo,
                        profiles: preset.profiles ?? [],
                        profilePins: pins
                    )
                    repository.savePassword(preset.password, forAccountId: account.id)
                    for (profileNo, pin) in pins {
                        repository.saveProfilePin(pin, forAccountId: account.id, profileNo: profileNo)
                    }
                    accounts.append(account)
                    imported += 1
                }
            }

            if imported > 0 {
                repository.saveAccounts(accounts)
            }

            return .success(imported: imported, skipped: skipped)
        }
    }

    func exportAccounts(_ accounts: [AccountInfo], includePasswords: Bool) -> PresetExportResult {
        let presets = accounts.map { PresetAccount(from: $0, includePassword: includePasswords) }
        do {
            let url = try PresetAccount.export(presets)
            return .success(url: url, count: presets.count, includedPasswords: includePasswords)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
