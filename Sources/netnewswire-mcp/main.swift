import Foundation
import NetNewsWireMCPLib

let database: NNWDatabase
do {
    database = try NNWDatabase()
} catch {
    log("Error: \(error)")
    exit(1)
}

let accounts = database.listAccounts()
log("Found \(accounts.count) account(s): \(accounts.map(\.name).joined(separator: ", "))")

try await startServer(database: database)
