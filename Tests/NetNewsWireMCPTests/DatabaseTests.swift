import Foundation
import Testing
import GRDB
import MCP
@testable import NetNewsWireMCPLib

// MARK: - Fixture Database
//
// These tests build a throwaway SQLite database whose schema mirrors
// NetNewsWire's ArticlesDatabase (articles, statuses, authors, authorsLookup,
// and the `search` FTS4 virtual table). They exercise the real query layer in
// `NNWDatabase` end-to-end without needing a live NetNewsWire install, so they
// run in CI. The schema here should be kept in sync with the live schema that
// the `testLiveSchemaMatches...` test validates when a real DB is present.

private let fixtureOPML = """
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Subscriptions</title></head>
<body>
    <outline text="Tech" title="Tech">
        <outline type="rss" title="Swift Blog" xmlUrl="https://swift.org/feed.xml" htmlUrl="https://swift.org"/>
        <outline type="rss" title="Apple Newsroom" xmlUrl="https://apple.com/feed.xml" htmlUrl="https://apple.com"/>
    </outline>
</body>
</opml>
"""

/// Timestamps used across the fixture (seconds since 1970).
private enum T {
    static let a1 = 1_700_000_000.0
    static let a2 = 1_700_000_500.0
    static let a3 = 1_700_000_900.0
}

private struct Fixture {
    let basePath: String

    init() throws {
        let fm = FileManager.default
        basePath = fm.temporaryDirectory
            .appendingPathComponent("nnw-fixture-\(UUID().uuidString)").path
        try fm.createDirectory(atPath: "\(basePath)/2_iCloud", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(basePath)/OnMyMac", withIntermediateDirectories: true)
        try Fixture.buildDatabase(at: "\(basePath)/2_iCloud/DB.sqlite3", populate: true)
        try Fixture.buildDatabase(at: "\(basePath)/OnMyMac/DB.sqlite3", populate: false)
        try fixtureOPML.write(toFile: "\(basePath)/2_iCloud/Subscriptions.opml", atomically: true, encoding: .utf8)
    }

    func database() throws -> NNWDatabase {
        try NNWDatabase(accountsBasePath: basePath)
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: basePath)
    }

    private static func buildDatabase(at path: String, populate: Bool) throws {
        let queue = try DatabaseQueue(path: path)
        try queue.write { db in
            // Schema mirrors NetNewsWire 7.1.1's DB.sqlite3 (verified against a
            // live install): authors are inline JSON on articles.authors, there
            // is no separate authors/authorsLookup table, and statuses has no
            // userDeleted column.
            try db.execute(sql: """
                CREATE TABLE articles (
                    articleID TEXT NOT NULL PRIMARY KEY,
                    feedID TEXT NOT NULL,
                    uniqueID TEXT NOT NULL,
                    title TEXT,
                    contentHTML TEXT,
                    contentText TEXT,
                    url TEXT,
                    externalURL TEXT,
                    summary TEXT,
                    imageURL TEXT,
                    bannerImageURL TEXT,
                    datePublished DATE,
                    dateModified DATE,
                    searchRowID INTEGER,
                    markdown TEXT,
                    authors TEXT
                );
                CREATE TABLE statuses (
                    articleID TEXT NOT NULL PRIMARY KEY,
                    read BOOL NOT NULL DEFAULT 0,
                    starred BOOL NOT NULL DEFAULT 0,
                    dateArrived DATE NOT NULL DEFAULT 0
                );
                CREATE VIRTUAL TABLE search USING fts4(title, body);
                """)

            guard populate else { return }

            try insertArticle(
                db, id: "a1", feedID: "https://swift.org/feed.xml",
                title: "Swift 6.3 Released",
                contentHTML: "<p>Concurrency improvements land in Swift</p>",
                contentText: "Plain-text concurrency notes",
                url: "https://swift.org/blog/swift-6-3",
                datePublished: T.a1, dateArrived: T.a1,
                read: true, starred: true,
                searchTitle: "Swift 6.3 Released", searchBody: "Concurrency improvements land in Swift",
                authors: #"[{"authorID":"auth-1","name":"Jane Developer","url":"https:\/\/jane.dev"}]"#
            )
            try insertArticle(
                db, id: "a2", feedID: "https://swift.org/feed.xml",
                title: "Rust vs Swift",
                contentText: "A friendly comparison",
                url: "https://swift.org/blog/rust-vs-swift",
                datePublished: T.a2, dateArrived: T.a2,
                read: false, starred: false,
                searchTitle: "Rust vs Swift", searchBody: "A friendly comparison"
            )
            // No datePublished: ordering must fall back to dateArrived.
            try insertArticle(
                db, id: "a3", feedID: "https://apple.com/feed.xml",
                title: "Apple Event",
                contentHTML: "<p>New hardware announced</p>",
                url: "https://apple.com/events",
                datePublished: nil, dateArrived: T.a3,
                read: true, starred: true,
                searchTitle: "Apple Event", searchBody: "New hardware announced"
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func insertArticle(
        _ db: Database,
        id: String,
        feedID: String,
        title: String,
        contentHTML: String? = nil,
        contentText: String? = nil,
        url: String?,
        datePublished: Double?,
        dateArrived: Double,
        read: Bool,
        starred: Bool,
        searchTitle: String,
        searchBody: String,
        authors: String? = nil
    ) throws {
        try db.execute(
            sql: "INSERT INTO search (title, body) VALUES (?, ?)",
            arguments: [searchTitle, searchBody]
        )
        let searchRowID = db.lastInsertedRowID

        try db.execute(sql: """
            INSERT INTO articles
                (articleID, feedID, uniqueID, title, contentHTML, contentText, url,
                 externalURL, summary, imageURL, bannerImageURL, datePublished, dateModified,
                 searchRowID, markdown, authors)
            VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, NULL, ?, NULL, ?)
            """,
            arguments: [id, feedID, id, title, contentHTML, contentText, url, datePublished, searchRowID, authors]
        )
        try db.execute(
            sql: "INSERT INTO statuses (articleID, read, starred, dateArrived) VALUES (?, ?, ?, ?)",
            arguments: [id, read, starred, dateArrived]
        )
    }
}

/// Run `body` with a fresh fixture, cleaning up afterwards.
private func withFixture(_ body: (Fixture, NNWDatabase) throws -> Void) throws {
    let fixture = try Fixture()
    defer { fixture.cleanup() }
    try body(fixture, fixture.database())
}

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
