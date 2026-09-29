import Foundation
import NetNewsWireMCPLib

let database = Result { try NNWDatabase() }
switch database {
case .success(let db):
    let accounts = db.listAccounts()
    log("Found \(accounts.count) account(s): \(accounts.map(\.name).joined(separator: ", "))")
case .failure(let error):
    // Keep serving so tool calls can report the fix (usually Full Disk Access).
    log("Error opening NetNewsWire databases: \(error)")
}

try await startServer(database: database)
