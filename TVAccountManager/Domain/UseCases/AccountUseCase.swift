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
                       isPinned: Bool) {
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
        repository.saveAccounts(accounts)
    }

    func deleteAccount(from accounts: inout [AccountInfo], id: UUID) {
        accounts.removeAll { $0.id == id }
        repository.deletePassword(forAccountId: id)
        repository.saveAccounts(accounts)
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
                    let account = AccountInfo(
                        title: preset.title,
                        username: preset.username,
                        password: preset.password,
                        accountType: preset.accountType,
                        planType: preset.planType,
                        memo: preset.memo
                    )
                    repository.savePassword(preset.password, forAccountId: account.id)
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
}
