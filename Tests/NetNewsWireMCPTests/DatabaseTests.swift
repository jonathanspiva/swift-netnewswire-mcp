import Foundation
import Testing
import GRDB
import MCP
@testable import NetNewsWireMCPLib

// MARK: - Account Discovery / Resolution

@Test func testDiscoversAllAccounts() throws {
    try withFixture { _, db in
        let names = db.listAccounts().map(\.name).sorted()
        #expect(names == ["2_iCloud", "OnMyMac"])
    }
}

@Test func testResolveAccountDefaultsToFirstSorted() throws {
    try withFixture { _, db in
        let name = try db.resolveAccount(nil).name
        #expect(name == "2_iCloud")
    }
}

@Test func testResolveAccountIsCaseInsensitive() throws {
    try withFixture { _, db in
        let lower = try db.resolveAccount("onmymac").name
        let upper = try db.resolveAccount("2_ICLOUD").name
        #expect(lower == "OnMyMac")
        #expect(upper == "2_iCloud")
    }
}

@Test func testResolveAccountUnknownThrows() throws {
    try withFixture { _, db in
        #expect(throws: NNWError.self) {
            _ = try db.resolveAccount("does-not-exist")
        }
    }
}

@Test func testOPMLDetectedOnlyForICloud() throws {
    try withFixture { _, db in
        let iCloud = try db.resolveAccount("2_iCloud")
        let onMyMac = try db.resolveAccount("OnMyMac")
        #expect(iCloud.opmlPath != nil)
        #expect(onMyMac.opmlPath == nil)
    }
}

// MARK: - Counts

@Test func testArticleCounts() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let counts = try db.articleCounts(account: account)
        #expect(counts.total == 3)
        #expect(counts.starred == 2)
        #expect(counts.unread == 1)
    }
}

@Test func testArticleCountsEmptyAccount() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("OnMyMac")
        let counts = try db.articleCounts(account: account)
        #expect(counts.total == 0)
        #expect(counts.starred == 0)
        #expect(counts.unread == 0)
    }
}

// MARK: - Starred

@Test func testStarredArticlesOrderingAndFallback() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let starred = try db.starredArticles(account: account)
        // a1 and a3 are starred; a3 has no datePublished so it falls back to
        // dateArrived (1_700_000_900) which is newer than a1 (1_700_000_000).
        #expect(starred.map(\.articleID) == ["a3", "a1"])
    }
}

@Test func testStarredArticlesFeedFilter() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let starred = try db.starredArticles(account: account, feedID: "https://swift.org/feed.xml")
        #expect(starred.map(\.articleID) == ["a1"])
    }
}

@Test func testStarredArticlesLimit() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let starred = try db.starredArticles(account: account, limit: 1)
        #expect(starred.count == 1)
        #expect(starred.first?.articleID == "a3")
    }
}

// MARK: - Recent

@Test func testRecentArticlesOrderedByArrival() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let recent = try db.recentArticles(account: account)
        #expect(recent.map(\.articleID) == ["a3", "a2", "a1"])
    }
}

@Test func testRecentArticlesStarredOnly() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let recent = try db.recentArticles(account: account, starredOnly: true)
        #expect(recent.map(\.articleID) == ["a3", "a1"])
    }
}

@Test func testRecentArticlesFeedFilter() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let recent = try db.recentArticles(account: account, feedID: "https://swift.org/feed.xml")
        #expect(recent.map(\.articleID) == ["a2", "a1"])
    }
}

// MARK: - Get Article

@Test func testGetArticleWithAuthors() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let (article, authors) = try db.getArticle(account: account, articleID: "a1")
        #expect(article.title == "Swift 6.3 Released")
        #expect(article.starred == true)
        #expect(article.read == true)
        #expect(article.contentHTML == "<p>Concurrency improvements land in Swift</p>")
        #expect(authors.map { $0.name } == ["Jane Developer"])
    }
}

@Test func testGetArticleNotFoundThrows() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        #expect(throws: NNWError.self) {
            _ = try db.getArticle(account: account, articleID: "nope")
        }
    }
}

// MARK: - Search (FTS4)

@Test func testSearchMatchesTitleAndBody() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let results = try db.searchArticles(account: account, query: "Swift")
        // "Swift" appears in a1 (title/body) and a2 (title "Rust vs Swift").
        #expect(Set(results.map(\.articleID)) == ["a1", "a2"])
    }
}

@Test func testSearchMatchesBodyOnlyTerm() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let results = try db.searchArticles(account: account, query: "concurrency")
        #expect(results.map(\.articleID) == ["a1"])
    }
}

@Test func testSearchNoMatch() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let results = try db.searchArticles(account: account, query: "kubernetes")
        #expect(results.isEmpty)
    }
}

// MARK: - Feeds (OPML)

@Test func testListFeedsFromOPML() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let feeds = try db.listFeeds(account: account)
        #expect(feeds.count == 2)
        #expect(feeds.allSatisfy { $0.folder == "Tech" })
        #expect(feeds.map(\.xmlUrl).contains("https://swift.org/feed.xml"))
    }
}

@Test func testListFeedsNoOPMLThrows() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("OnMyMac")
        #expect(throws: NNWError.self) {
            _ = try db.listFeeds(account: account)
        }
    }
}

// MARK: - Handler Success Paths + Limit Clamping

@Test func testHandleGetArticleCountRoutes() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article_count",
            arguments: ["account": .string("2_iCloud")],
            database: db
        )
        #expect(result.isError != true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Total articles | 3"))
            #expect(text.contains("Starred | 2"))
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testHandleCallUnknownTool() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(name: "nonexistent_tool", arguments: nil, database: db)
        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Unknown tool"))
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testHandleSearchArticlesRoutes() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "search_articles",
            arguments: ["query": .string("concurrency")],
            database: db
        )
        #expect(result.isError != true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Swift 6.3 Released"))
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testNegativeLimitIsClampedNotUnbounded() throws {
    try withFixture { _, db in
        // SQLite treats LIMIT -1 as "no limit". The handler must clamp it so a
        // negative limit cannot dump the whole table.
        let result = ToolHandlers.handleCall(
            name: "list_recent_articles",
            arguments: ["limit": .int(-1)],
            database: db
        )
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Total: 1 articles"))
        } else {
            Issue.record("expected text content")
        }
    }
}

// MARK: - Author JSON Parsing (NNW 7.1+ inline authors column)

@Test func testParseAuthorsRealShape() {
    // Mirrors the JSON shape NetNewsWire 7.1 writes to `articles.authors`
    // (escaped slashes, an emailAddress, no avatarURL). Values are fictional.
    let json = #"[{"authorID":"a1b2c3d4","name":"Ada Lovelace","url":"https:\/\/example.com","emailAddress":"ada@example.com"}]"#
    let authors = NNWDatabase.parseAuthors(json)
    #expect(authors.count == 1)
    #expect(authors.first?.name == "Ada Lovelace")
    #expect(authors.first?.url == "https://example.com")
    #expect(authors.first?.emailAddress == "ada@example.com")
    #expect(authors.first?.avatarURL == nil)
}

@Test func testParseAuthorsMultiple() {
    let json = #"[{"authorID":"1","name":"Alice"},{"authorID":"2","name":"Bob"}]"#
    let authors = NNWDatabase.parseAuthors(json)
    #expect(authors.map { $0.name } == ["Alice", "Bob"])
}

@Test func testParseAuthorsEmptyAndNil() {
    #expect(NNWDatabase.parseAuthors(nil).isEmpty)
    #expect(NNWDatabase.parseAuthors("").isEmpty)
    #expect(NNWDatabase.parseAuthors("[]").isEmpty)
}

@Test func testParseAuthorsMalformedIsSafe() {
    #expect(NNWDatabase.parseAuthors("not json").isEmpty)
    #expect(NNWDatabase.parseAuthors("{\"name\":\"x\"}").isEmpty)  // object, not array
}

@Test func testParseAuthorsEntryWithoutName() {
    // authorID present, name absent → decodes with name == nil.
    let authors = NNWDatabase.parseAuthors(#"[{"authorID":"abc"}]"#)
    #expect(authors.count == 1)
    #expect(authors.first?.name == nil)
}

@Test func testParseAuthorsFailsClosedOnMissingRequiredField() {
    // authorID is non-optional; an entry lacking it fails the whole decode → [].
    let authors = NNWDatabase.parseAuthors(#"[{"name":"No ID Here"}]"#)
    #expect(authors.isEmpty)
}

// MARK: - Additional Query / Handler Coverage

@Test func testStarredArticlesFeedFilterNoMatch() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let starred = try db.starredArticles(account: account, feedID: "https://nope.example.com/feed")
        #expect(starred.isEmpty)
    }
}

@Test func testRecentArticlesRespectsLimitAndOrder() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        let recent = try db.recentArticles(account: account, limit: 2)
        #expect(recent.map(\.articleID) == ["a3", "a2"])  // newest two by arrival
    }
}

@Test func testSearchOrdersByDatePublished() throws {
    try withFixture { _, db in
        let account = try db.resolveAccount("2_iCloud")
        // "Swift" matches a1 and a2; ordered by COALESCE(datePublished, dateArrived) DESC.
        let results = try db.searchArticles(account: account, query: "Swift")
        #expect(results.map(\.articleID) == ["a2", "a1"])
    }
}

@Test func testHandleListFeedsRoutes() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "list_feeds",
            arguments: ["account": .string("2_iCloud")],
            database: db
        )
        #expect(result.isError != true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Swift Blog"))
            #expect(text.contains("Total: 2 feeds"))
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testHandleGetArticleMissingIDReturnsError() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article",
            arguments: ["account": .string("2_iCloud")],
            database: db
        )
        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("article_id"))
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testHandleUnknownAccountReturnsError() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article_count",
            arguments: ["account": .string("no-such-account")],
            database: db
        )
        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("no-such-account"))
            #expect(text.contains("2_iCloud"))  // lists available accounts
        } else {
            Issue.record("expected text content")
        }
    }
}

@Test func testGetArticleFormatTextViaHandler() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article",
            arguments: [
                "account": .string("2_iCloud"),
                "article_id": .string("a1"),
                "format": .string("text"),
            ],
            database: db
        )
        guard case .object(let obj)? = result.structuredContent else {
            Issue.record("expected structured content")
            return
        }
        #expect(obj["content_format"] == .string("text"))
        #expect(obj["content"] == .string("Plain-text concurrency notes"))
    }
}

// MARK: - Structured Output

private func structuredObject(_ result: CallTool.Result) -> [String: Value]? {
    guard case .object(let obj)? = result.structuredContent else { return nil }
    return obj
}

@Test func testStructuredCountsOutput() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article_count",
            arguments: ["account": .string("2_iCloud")],
            database: db
        )
        let obj = structuredObject(result)
        #expect(obj?["total"] == .int(3))
        #expect(obj?["starred"] == .int(2))
        #expect(obj?["unread"] == .int(1))
        #expect(obj?["account"] == .string("2_iCloud"))
    }
}

@Test func testStructuredAccountsOutput() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(name: "list_accounts", arguments: nil, database: db)
        let obj = structuredObject(result)
        #expect(obj?["total"] == .int(2))
        guard case .array(let accounts)? = obj?["accounts"] else {
            Issue.record("expected accounts array")
            return
        }
        #expect(accounts.count == 2)
    }
}

@Test func testStructuredArticleListOutput() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "search_articles",
            arguments: ["query": .string("concurrency")],
            database: db
        )
        let obj = structuredObject(result)
        #expect(obj?["total"] == .int(1))
        guard case .array(let articles)? = obj?["articles"],
              case .object(let first)? = articles.first else {
            Issue.record("expected articles array")
            return
        }
        #expect(first["article_id"] == .string("a1"))
        #expect(first["starred"] == .bool(true))
    }
}

@Test func testStructuredArticleDetailOutput() throws {
    try withFixture { _, db in
        let result = ToolHandlers.handleCall(
            name: "get_article",
            arguments: ["account": .string("2_iCloud"), "article_id": .string("a1")],
            database: db
        )
        let obj = structuredObject(result)
        #expect(obj?["article_id"] == .string("a1"))
        #expect(obj?["content_format"] == .string("html"))
        #expect(obj?["content_truncated"] == .bool(false))
        guard case .array(let authors)? = obj?["authors"] else {
            Issue.record("expected authors array")
            return
        }
        #expect(authors == [.string("Jane Developer")])
    }
}

// MARK: - get_article content selection & truncation

@Test func testSelectContentPrefersHTMLByDefault() {
    let article = makeArticle(contentHTML: "<p>html</p>", contentText: "plain")
    let (text, format, truncated) = StructuredOutput.selectContent(article, preferText: false, maxLength: 1000)
    #expect(format == "html")
    #expect(text == "<p>html</p>")
    #expect(truncated == false)
}

@Test func testSelectContentPrefersTextWhenAsked() {
    let article = makeArticle(contentHTML: "<p>html</p>", contentText: "plain")
    let (text, format, _) = StructuredOutput.selectContent(article, preferText: true, maxLength: 1000)
    #expect(format == "text")
    #expect(text == "plain")
}

@Test func testSelectContentTruncates() {
    let long = String(repeating: "x", count: 300)
    let article = makeArticle(contentHTML: long)
    let (text, _, truncated) = StructuredOutput.selectContent(article, preferText: false, maxLength: 100)
    #expect(truncated == true)
    #expect(text?.hasPrefix(String(repeating: "x", count: 100)) == true)
    #expect(text?.contains("truncated") == true)
    // Original 300 chars are not all present.
    #expect((text?.count ?? 0) < 300 + 100)
}

@Test func testResolveContentLengthClamps() {
    #expect(ToolHandlers.resolveContentLength([:]) == ToolHandlers.defaultContentLength)
    #expect(ToolHandlers.resolveContentLength(["max_content_length": .int(10)]) == 100)
    #expect(ToolHandlers.resolveContentLength(["max_content_length": .int(9_999_999)]) == ToolHandlers.maxContentLength)
    #expect(ToolHandlers.resolveContentLength(["max_content_length": .int(1000)]) == 1000)
}

// MARK: - Error sanitization

@Test func testMalformedSearchReturnsFriendlyError() throws {
    try withFixture { _, db in
        // "swift OR" is a malformed FTS4 MATCH expression (trailing operator).
        let result = ToolHandlers.handleCall(
            name: "search_articles",
            arguments: ["query": .string("swift OR")],
            database: db
        )
        #expect(result.isError == true)
        if case .text(let message, _, _) = result.content.first {
            #expect(message.contains("Search failed"))
            // Internal details (DB path, raw SQLite error) must not leak.
            #expect(!message.contains("DB.sqlite3"))
            #expect(!message.lowercased().contains("/users"))
        } else {
            Issue.record("expected text content")
        }
    }
}

// MARK: - Live NetNewsWire Validation
//
// These run only when a real, *readable* NetNewsWire database is present. They
// are skipped in CI (no install) and when macOS TCC blocks reading the
// container (grant the host terminal Full Disk Access to enable them). They
// confirm the query layer works against the live NNW schema, catching any
// drift between the fixture schema above and the installed NNW version.

/// True only if the real accounts directory can actually be enumerated (not
/// merely that it exists — `fileExists` returns true even under a TCC block).
private func liveDatabaseReadable() -> Bool {
    let path = NNWDatabase.defaultAccountsBasePath()
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
        return false
    }
    return contents.contains { FileManager.default.fileExists(atPath: "\(path)/\($0)/DB.sqlite3") }
}

@Test(.enabled(if: liveDatabaseReadable()))
func testLiveDatabaseQueriesSucceed() throws {
    let db = try NNWDatabase()
    let accounts = db.listAccounts()
    #expect(!accounts.isEmpty)

    for account in accounts {
        // articleCounts + every query path must succeed against the live schema.
        let counts = try db.articleCounts(account: account)
        #expect(counts.total >= 0)
        #expect(counts.starred >= 0)
        #expect(counts.unread >= 0)

        _ = try db.starredArticles(account: account, limit: 1)
        _ = try db.searchArticles(account: account, query: "the", limit: 1)

        if account.opmlPath != nil {
            _ = try db.listFeeds(account: account)
        }

        let recent = try db.recentArticles(account: account, limit: 1)
        if let first = recent.first {
            // Full article fetch (joins statuses + authors) against real data.
            let (article, _) = try db.getArticle(account: account, articleID: first.articleID)
            #expect(article.articleID == first.articleID)
        }
    }
}

// MARK: - resolveLimit unit tests

@Test func testResolveLimitDefaults() {
    #expect(ToolHandlers.resolveLimit([:], default: 50) == 50)
}

@Test func testResolveLimitClampsLow() {
    #expect(ToolHandlers.resolveLimit(["limit": .int(-5)], default: 50) == 1)
    #expect(ToolHandlers.resolveLimit(["limit": .int(0)], default: 50) == 1)
}

@Test func testResolveLimitClampsHigh() {
    #expect(ToolHandlers.resolveLimit(["limit": .int(100_000)], default: 50) == ToolHandlers.maxLimit)
}

@Test func testResolveLimitPassesThrough() {
    #expect(ToolHandlers.resolveLimit(["limit": .int(25)], default: 50) == 25)
}

@Test func testResolveLimitAcceptsIntegralDouble() {
    #expect(ToolHandlers.resolveLimit(["limit": .double(25)], default: 50) == 25)
}

@Test func testResolveLimitRejectsNonIntegralDouble() {
    // A fractional value is not a valid count; fall back to the default.
    #expect(ToolHandlers.resolveLimit(["limit": .double(25.7)], default: 50) == 50)
}

// MARK: - Startup Failure

@Test func testStartupFailureResultExplainsFullDiskAccess() throws {
    let error = NNWError.accountsNotFound("/nonexistent/Accounts")
    let result = ToolHandlers.startupFailureResult(error)
    #expect(result.isError == true)
    if case .text(let text, _, _) = result.content.first {
        #expect(text.contains("accounts directory not found"))
        #expect(text.contains("Full Disk Access"))
    } else {
        Issue.record("expected text content")
    }
}

@Test func testStartupFailureResultHidesNonNNWErrorDetails() throws {
    let error = CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: "/private/secret/path"])
    let result = ToolHandlers.startupFailureResult(error)
    #expect(result.isError == true)
    if case .text(let text, _, _) = result.content.first {
        #expect(!text.contains("/private/secret/path"))
        #expect(text.contains("Full Disk Access"))
    } else {
        Issue.record("expected text content")
    }
}

// MARK: - Desktop Extension Manifest

@Test func testMCPBManifestVersionMatchesServer() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("mcpb/manifest.json"))
    let manifest = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(manifest["version"] as? String == serverVersion)
}

// MARK: - Claude Code Plugin

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Suite struct `Claude Code plugin` {
    private func pluginManifest() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(".claude-plugin/plugin.json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func `plugin version matches the server`() throws {
        #expect(try pluginManifest()["version"] as? String == serverVersion)
    }

    @Test func `launcher pins the server version and a full SHA-256`() throws {
        let script = try String(contentsOf: repoRoot.appendingPathComponent("plugin/launch.sh"), encoding: .utf8)
        #expect(script.contains("\nVERSION=\"\(serverVersion)\"\n"))
        let sha = script.split(separator: "\n").first { $0.hasPrefix("SHA256=\"") }
        let hex = try #require(sha).dropFirst("SHA256=\"".count).dropLast()
        #expect(hex.count == 64 && hex.allSatisfy(\.isHexDigit), "SHA256 must be a 64-char hex digest")
    }

    @Test func `MCP command points at the executable launcher`() throws {
        let servers = try #require(try pluginManifest()["mcpServers"] as? [String: [String: Any]])
        let command = try #require(servers["netnewswire"]?["command"] as? String)
        #expect(command == "${CLAUDE_PLUGIN_ROOT}/plugin/launch.sh")
        let path = repoRoot.appendingPathComponent("plugin/launch.sh").path
        #expect(FileManager.default.isExecutableFile(atPath: path))
    }
}

// MARK: - Discovery Failures

@Suite struct `Account discovery failures` {
    @Test func `missing accounts directory throws accountsNotFound`() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("nnw-missing-\(UUID().uuidString)").path
        #expect {
            try NNWDatabase(accountsBasePath: path)
        } throws: { error in
            guard case .accountsNotFound(let reported) = error as? NNWError else { return false }
            return reported == path
        }
    }

    @Test(arguments: [false, true])
    func `directory without any DB.sqlite3 throws noAccountsFound`(withEmptySubfolder: Bool) throws {
        let fm = FileManager.default
        let path = fm.temporaryDirectory.appendingPathComponent("nnw-empty-\(UUID().uuidString)").path
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: path) }
        if withEmptySubfolder {
            try fm.createDirectory(atPath: "\(path)/OnMyMac", withIntermediateDirectories: true)
        }
        #expect {
            try NNWDatabase(accountsBasePath: path)
        } throws: { error in
            guard case .noAccountsFound = error as? NNWError else { return false }
            return true
        }
    }

    @Test func `account without OPML reports noOPML from list_feeds`() throws {
        try withFixture { _, db in
            let result = ToolHandlers.handleCall(
                name: "list_feeds", arguments: ["account": "OnMyMac"], database: db
            )
            #expect(result.isError == true)
            if case .text(let text, _, _) = result.content.first {
                #expect(text.contains("No Subscriptions.opml"))
            } else {
                Issue.record("expected text content")
            }
        }
    }
}

// MARK: - Error Messages

@Suite struct `NNWError messages` {
    static let cases: [(NNWError, String)] = [
        (.accountsNotFound("/p"), "accounts directory not found at: /p"),
        (.noAccountsFound("/p"), "No accounts with databases found in: /p"),
        (.accountNotFound("x", available: ["a", "b"]), "Account 'x' not found. Available: a, b"),
        (.articleNotFound("id1"), "Article not found: id1"),
        (.noOPML("OnMyMac"), "No Subscriptions.opml found for account: OnMyMac"),
        (.missingParameter("query"), "Missing required parameter: query"),
        (.invalidParameter("limit", detail: "must be positive"), "Invalid parameter 'limit': must be positive"),
    ]

    @Test(arguments: cases)
    func `description is user-facing and matches localizedDescription`(error: NNWError, expected: String) {
        #expect(error.description.contains(expected))
        #expect(error.localizedDescription == error.description)
    }
}

// MARK: - Starred Handler

@Suite struct `list_starred_articles handler` {
    @Test func `returns only starred articles, optionally filtered by feed`() throws {
        try withFixture { _, db in
            let all = ToolHandlers.handleCall(
                name: "list_starred_articles", arguments: ["account": "2_iCloud"], database: db
            )
            #expect(all.isError != true)
            guard case .object(let obj)? = all.structuredContent,
                  case .array(let articles)? = obj["articles"] else {
                Issue.record("expected articles array"); return
            }
            #expect(articles.count == 2)

            let filtered = ToolHandlers.handleCall(
                name: "list_starred_articles",
                arguments: ["account": "2_iCloud", "feed_id": "https://apple.com/feed.xml"],
                database: db
            )
            guard case .object(let fobj)? = filtered.structuredContent,
                  case .array(let farticles)? = fobj["articles"] else {
                Issue.record("expected articles array"); return
            }
            #expect(farticles.count == 1)
            #expect(farticles.first?.objectValue?["article_id"] == .string("a3"))
        }
    }
}

// MARK: - Unreadable Database

@Test func `corrupt database returns a friendly error without leaking paths`() throws {
    try withFixture { fixture, db in
        let dbPath = "\(fixture.basePath)/2_iCloud/DB.sqlite3"
        try Data("not a sqlite database".utf8).write(to: URL(fileURLWithPath: dbPath))
        let result = ToolHandlers.handleCall(
            name: "get_article_count", arguments: ["account": "2_iCloud"], database: db
        )
        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("could not be completed"))
            #expect(!text.contains(fixture.basePath))
        } else {
            Issue.record("expected text content")
        }
    }
}

// MARK: - Orphan Statuses

@Suite struct `Orphan status rows` {
    @Test func `are excluded from starred and unread counts`() throws {
        try withFixture { fixture, db in
            try fixture.addOrphanStatus(id: "gone-1", read: false, starred: true)
            try fixture.addOrphanStatus(id: "gone-2", read: false, starred: false)
            let counts = try db.articleCounts(account: try db.resolveAccount("2_iCloud"))
            #expect(counts.total == 3)
            #expect(counts.starred == 2)
            #expect(counts.unread == 1)
        }
    }

    @Test func `counts agree with the starred list`() throws {
        try withFixture { fixture, db in
            try fixture.addOrphanStatus(id: "gone-1", read: true, starred: true)
            let account = try db.resolveAccount("2_iCloud")
            let starred = try db.starredArticles(account: account)
            #expect(try db.articleCounts(account: account).starred == starred.count)
        }
    }
}

// MARK: - Sync Warning

@Suite struct `Sync warning` {
    @Test func `lastWriteDate reads the DB modification time`() throws {
        try withFixture { fixture, db in
            try fixture.setLastWrite(account: "2_iCloud", secondsAgo: 30)
            let written = try #require(db.lastWriteDate(account: try db.resolveAccount("2_iCloud")))
            #expect(abs(Date.now.timeIntervalSince(written) - 30) < 5)
        }
    }

    @Test func `lastWriteDate is nil when the DB file is missing`() throws {
        try withFixture { _, db in
            let missing = NNWAccount(name: "Gone", path: "/nowhere", dbPath: "/nowhere/DB.sqlite3", opmlPath: nil)
            #expect(db.lastWriteDate(account: missing) == nil)
        }
    }

    @Test(arguments: [(10.0, true), (59.0, true), (61.0, false), (3600.0, false), (-30.0, false)])
    func `warns only for writes in the last minute`(secondsAgo: Double, warns: Bool) throws {
        try withFixture { fixture, db in
            try fixture.setLastWrite(account: "2_iCloud", secondsAgo: secondsAgo)
            let warning = ToolHandlers.syncWarning(account: try db.resolveAccount("2_iCloud"), database: db)
            #expect((warning != nil) == warns)
        }
    }

    @Test(arguments: ["list_starred_articles", "list_recent_articles", "get_article_count"])
    func `recent write adds a note and sync_warning`(tool: String) throws {
        try withFixture { fixture, db in
            try fixture.setLastWrite(account: "2_iCloud", secondsAgo: 5)
            let result = ToolHandlers.handleCall(name: tool, arguments: ["account": .string("2_iCloud")], database: db)
            guard case .text(let markdown, _, _)? = result.content.first else {
                Issue.record("expected text content")
                return
            }
            #expect(markdown.hasPrefix("> **Note:** NetNewsWire wrote to this account's database"))
            let warning = structuredObject(result)?["sync_warning"]?.stringValue
            #expect(warning?.contains("may be incomplete") == true)

            let schema = try #require(ToolHandlers.allTools.first { $0.name == tool }?.outputSchema)
            let structured = try #require(result.structuredContent)
            #expect(SchemaCheck.violations(of: structured, against: schema).isEmpty)
        }
    }

    @Test func `search results carry the warning too`() throws {
        try withFixture { fixture, db in
            try fixture.setLastWrite(account: "2_iCloud", secondsAgo: 5)
            let result = ToolHandlers.handleCall(
                name: "search_articles",
                arguments: ["account": .string("2_iCloud"), "query": .string("swift")],
                database: db
            )
            #expect(structuredObject(result)?["sync_warning"] != nil)
        }
    }

    @Test func `no warning for an idle database or for get_article`() throws {
        try withFixture { fixture, db in
            let idle = ToolHandlers.handleCall(
                name: "list_starred_articles", arguments: ["account": .string("2_iCloud")], database: db
            )
            #expect(structuredObject(idle)?["sync_warning"] == nil)

            try fixture.setLastWrite(account: "2_iCloud", secondsAgo: 5)
            let article = ToolHandlers.handleCall(
                name: "get_article",
                arguments: ["account": .string("2_iCloud"), "article_id": .string("a1")],
                database: db
            )
            #expect(structuredObject(article)?["sync_warning"] == nil)
        }
    }
}
