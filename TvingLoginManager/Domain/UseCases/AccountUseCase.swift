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
                    password: String, accountType: AccountType, planType: PlanType, memo: String) {
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? AccountInfo.generateRandomTitle() : title
        let account = AccountInfo(
            title: finalTitle, username: username, password: password,
            accountType: accountType, planType: planType, memo: memo
        )
        repository.savePassword(password, forAccountId: account.id)
        accounts.append(account)
        repository.saveAccounts(accounts)
    }

    func updateAccount(in accounts: inout [AccountInfo], id: UUID, title: String, username: String,
                       password: String, accountType: AccountType, planType: PlanType, memo: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].title = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? AccountInfo.generateRandomTitle() : title
        accounts[index].username = username
        accounts[index].password = password
        accounts[index].accountType = accountType
        accounts[index].planType = planType
        accounts[index].memo = memo
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
}
