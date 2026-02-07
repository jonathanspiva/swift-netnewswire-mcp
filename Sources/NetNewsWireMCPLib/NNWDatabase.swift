import Foundation
import GRDB

// MARK: - Database Records

public struct Article: Codable, FetchableRecord, Sendable {
    public let articleID: String
    public let feedID: String
    public let uniqueID: String
    public let title: String?
    public let contentHTML: String?
    public let contentText: String?
    public let url: String?
    public let externalURL: String?
    public let summary: String?
    public let imageURL: String?
    public let bannerImageURL: String?
    public let datePublished: Double?
    public let dateModified: Double?
    public let searchRowID: Int?
}

public struct ArticleStatus: Codable, FetchableRecord, Sendable {
    public let articleID: String
    public let read: Bool
    public let starred: Bool
    public let dateArrived: Double
}

public struct Author: Codable, FetchableRecord, Sendable {
    public let authorID: String
    public let name: String?
    public let url: String?
    public let avatarURL: String?
    public let emailAddress: String?
}

public struct ArticleWithStatus: Codable, FetchableRecord, Sendable {
    public let articleID: String
    public let feedID: String
    public let uniqueID: String
    public let title: String?
    public let contentHTML: String?
    public let contentText: String?
    public let url: String?
    public let externalURL: String?
    public let summary: String?
    public let imageURL: String?
    public let bannerImageURL: String?
    public let datePublished: Double?
    public let dateModified: Double?
    public let searchRowID: Int?
    public let read: Bool
    public let starred: Bool
    public let dateArrived: Double
}

// MARK: - Account Info

public struct NNWAccount: Sendable {
    public let name: String
    public let path: String
    public let dbPath: String
    public let opmlPath: String?
}

// MARK: - Feed Info (from OPML)

public struct FeedInfo: Sendable {
    public let title: String
    public let xmlUrl: String
    public let htmlUrl: String?
    public let folder: String?
}

// MARK: - Database Access

public final class NNWDatabase: Sendable {
    private let accountsBasePath: String
    private let accounts: [NNWAccount]

    public init() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let basePath = "\(home)/Library/Containers/com.ranchero.NetNewsWire-Evergreen/Data/Library/Application Support/NetNewsWire/Accounts"
        self.accountsBasePath = basePath

        guard FileManager.default.fileExists(atPath: basePath) else {
            throw NNWError.accountsNotFound(basePath)
        }

        var discovered: [NNWAccount] = []
        let contents = try FileManager.default.contentsOfDirectory(atPath: basePath)
        for item in contents.sorted() {
            let itemPath = "\(basePath)/\(item)"
            let dbPath = "\(itemPath)/DB.sqlite3"
            if FileManager.default.fileExists(atPath: dbPath) {
                let opmlPath = "\(itemPath)/Subscriptions.opml"
                let hasOpml = FileManager.default.fileExists(atPath: opmlPath)
                discovered.append(NNWAccount(
                    name: item,
                    path: itemPath,
                    dbPath: dbPath,
                    opmlPath: hasOpml ? opmlPath : nil
                ))
            }
        }

        guard !discovered.isEmpty else {
            throw NNWError.noAccountsFound(basePath)
        }

        self.accounts = discovered
    }

    // MARK: - Account Discovery

    public func listAccounts() -> [NNWAccount] {
        accounts
    }

    public func resolveAccount(_ name: String?) throws -> NNWAccount {
        if let name {
            guard let account = accounts.first(where: { $0.name.lowercased() == name.lowercased() }) else {
                throw NNWError.accountNotFound(name, available: accounts.map(\.name))
            }
            return account
        }
        guard let account = accounts.first else {
            throw NNWError.noAccountsFound(accountsBasePath)
        }
        return account
    }

    // MARK: - Database Connection

    private func openDatabase(for account: NNWAccount) throws -> DatabasePool {
        var config = Configuration()
        config.readonly = true
        return try DatabasePool(path: account.dbPath, configuration: config)
    }

    // MARK: - Article Queries

    public func starredArticles(account: NNWAccount, feedID: String? = nil, limit: Int = 100) throws -> [ArticleWithStatus] {
        let db = try openDatabase(for: account)
        return try db.read { db in
            var sql = """
                SELECT a.*, s.read, s.starred, s.dateArrived
                FROM articles a
                JOIN statuses s ON a.articleID = s.articleID
                WHERE s.starred = 1
                """
            var arguments: [DatabaseValueConvertible] = []
            if let feedID {
                sql += " AND a.feedID = ?"
                arguments.append(feedID)
            }
            sql += " ORDER BY COALESCE(a.datePublished, s.dateArrived) DESC LIMIT ?"
            arguments.append(limit)

            return try ArticleWithStatus.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }

    public func recentArticles(account: NNWAccount, feedID: String? = nil, limit: Int = 50, starredOnly: Bool = false) throws -> [ArticleWithStatus] {
        let db = try openDatabase(for: account)
        return try db.read { db in
            var sql = """
                SELECT a.*, s.read, s.starred, s.dateArrived
                FROM articles a
                JOIN statuses s ON a.articleID = s.articleID
                WHERE 1=1
                """
            var arguments: [DatabaseValueConvertible] = []
            if starredOnly {
                sql += " AND s.starred = 1"
            }
            if let feedID {
                sql += " AND a.feedID = ?"
                arguments.append(feedID)
            }
            sql += " ORDER BY s.dateArrived DESC LIMIT ?"
            arguments.append(limit)

            return try ArticleWithStatus.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }

    public func getArticle(account: NNWAccount, articleID: String) throws -> (ArticleWithStatus, [Author]) {
        let db = try openDatabase(for: account)
        return try db.read { db in
            let sql = """
                SELECT a.*, s.read, s.starred, s.dateArrived
                FROM articles a
                JOIN statuses s ON a.articleID = s.articleID
                WHERE a.articleID = ?
                """
            guard let article = try ArticleWithStatus.fetchOne(db, sql: sql, arguments: [articleID]) else {
                throw NNWError.articleNotFound(articleID)
            }

            let authorSql = """
                SELECT au.*
                FROM authors au
                JOIN authorsLookup al ON au.authorID = al.authorID
                WHERE al.articleID = ?
                """
            let authors = try Author.fetchAll(db, sql: authorSql, arguments: [articleID])

            return (article, authors)
        }
    }

    public func searchArticles(account: NNWAccount, query: String, limit: Int = 50) throws -> [ArticleWithStatus] {
        let db = try openDatabase(for: account)
        return try db.read { db in
            let sql = """
                SELECT a.*, s.read, s.starred, s.dateArrived
                FROM articles a
                JOIN search ON a.searchRowID = search.rowid
                JOIN statuses s ON a.articleID = s.articleID
                WHERE search MATCH ?
                ORDER BY COALESCE(a.datePublished, s.dateArrived) DESC
                LIMIT ?
                """
            return try ArticleWithStatus.fetchAll(db, sql: sql, arguments: [query, limit])
        }
    }

    public func articleCounts(account: NNWAccount) throws -> (total: Int, starred: Int, unread: Int) {
        let db = try openDatabase(for: account)
        return try db.read { db in
            let total = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM articles") ?? 0
            let starred = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM statuses WHERE starred = 1") ?? 0
            let unread = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM statuses WHERE read = 0") ?? 0
            return (total, starred, unread)
        }
    }

    // MARK: - OPML Parsing

    public func listFeeds(account: NNWAccount) throws -> [FeedInfo] {
        guard let opmlPath = account.opmlPath else {
            throw NNWError.noOPML(account.name)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: opmlPath))
        let parser = OPMLParser(data: data)
        return parser.parse()
    }
}

// MARK: - Errors

public enum NNWError: Error, LocalizedError, CustomStringConvertible {
    case accountsNotFound(String)
    case noAccountsFound(String)
    case accountNotFound(String, available: [String])
    case articleNotFound(String)
    case noOPML(String)
    case missingParameter(String)
    case invalidParameter(String, detail: String)

    public var description: String {
        switch self {
        case .accountsNotFound(let path):
            return "NetNewsWire accounts directory not found at: \(path)"
        case .noAccountsFound(let path):
            return "No accounts with databases found in: \(path)"
        case .accountNotFound(let name, let available):
            return "Account '\(name)' not found. Available: \(available.joined(separator: ", "))"
        case .articleNotFound(let id):
            return "Article not found: \(id)"
        case .noOPML(let account):
            return "No Subscriptions.opml found for account: \(account)"
        case .missingParameter(let name):
            return "Missing required parameter: \(name)"
        case .invalidParameter(let name, let detail):
            return "Invalid parameter '\(name)': \(detail)"
        }
    }

    public var errorDescription: String? { description }
}

// MARK: - OPML Parser

final class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var feeds: [FeedInfo] = []
    private var currentFolder: String?

    init(data: Data) {
        self.data = data
    }

    func parse() -> [FeedInfo] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return feeds
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard elementName == "outline" else { return }

        if let xmlUrl = attributeDict["xmlUrl"] {
            let feed = FeedInfo(
                title: attributeDict["title"] ?? attributeDict["text"] ?? xmlUrl,
                xmlUrl: xmlUrl,
                htmlUrl: attributeDict["htmlUrl"],
                folder: currentFolder
            )
            feeds.append(feed)
        } else if let title = attributeDict["title"] ?? attributeDict["text"] {
            currentFolder = title
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Folder outlines close, but we keep the folder context
        // until the next folder opens (simplified, works for NNW's flat structure)
    }
}
