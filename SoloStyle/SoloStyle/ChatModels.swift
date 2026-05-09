//
//  ChatModels.swift
//  SoloStyle
//
//  Local SwiftData cache for the in-app messenger.  Mirrors the server
//  schema closely; `seq` is the canonical ordering key and `clientMessageId`
//  gives us idempotent sends across reconnects.
//

import Foundation
import SwiftData

// MARK: - Conversation

@Model
final class MessengerConversation {
    /// Server UUID — unique key for sync.
    @Attribute(.unique) var id: UUID = UUID()

    var masterExternalId: String = ""
    var clientExternalId: String = ""

    var lastMessagePreview: String?
    var lastMessageAt: Date?

    var unreadMaster: Int = 0
    var unreadClient: Int = 0

    var createdAt: Date = Date()

    /// Highest `seq` we've successfully ingested.  Used for incremental sync.
    var lastSeenSeq: Int64 = 0

    /// Cached display name for the OTHER party (for the list row).
    /// Filled in when we open a chat or get user info; nil-safe fallback.
    var otherDisplayName: String?
    var otherAvatarUrl: String?

    @Relationship(deleteRule: .cascade, inverse: \MessengerMessage.conversation)
    var messages: [MessengerMessage] = []

    init(
        id: UUID,
        masterExternalId: String,
        clientExternalId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.masterExternalId = masterExternalId
        self.clientExternalId = clientExternalId
        self.createdAt = createdAt
    }

    /// External id of the other party from the perspective of `myExternalId`.
    func otherExternalId(of myExternalId: String) -> String {
        masterExternalId == myExternalId ? clientExternalId : masterExternalId
    }

    /// Unread counter for `myExternalId`.
    func unreadCount(of myExternalId: String) -> Int {
        masterExternalId == myExternalId ? unreadMaster : unreadClient
    }
}

// MARK: - Message

enum ChatMessageContentType: String, Codable, Sendable {
    case text, photo, voice, system
}

enum ChatMessageDeliveryStatus: String, Codable, Sendable {
    case pending   // queued locally, not yet sent
    case sent      // server ACK received
    case delivered // other side's client confirmed receipt
    case read      // other side has opened the chat
    case failed    // gave up after retries
}

@Model
final class MessengerMessage {
    /// Locally-generated UUID.  This is also the server's `client_message_id`
    /// for idempotency on send.
    @Attribute(.unique) var clientMessageId: UUID = UUID()

    /// Server-assigned UUID.  Nil while a message is still pending.
    var serverId: UUID?

    var conversation: MessengerConversation?

    /// "master" | "client" | "system"
    var senderRole: String = "client"
    var senderExternalId: String = ""

    var contentTypeRaw: String = "text"
    var body: String?
    var attachmentUrl: String?
    var attachmentMetaData: Data?  // JSON-encoded dict

    /// Server-side monotonic sequence; 0 while pending.
    var seq: Int64 = 0

    var deliveredAt: Date?
    var readAt: Date?
    var createdAt: Date = Date()

    var statusRaw: String = ChatMessageDeliveryStatus.pending.rawValue
    var failedReason: String?
    var sendAttempts: Int = 0

    var contentType: ChatMessageContentType {
        get { ChatMessageContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }

    var status: ChatMessageDeliveryStatus {
        get { ChatMessageDeliveryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        clientMessageId: UUID = UUID(),
        senderRole: String,
        senderExternalId: String,
        contentType: ChatMessageContentType = .text,
        body: String? = nil,
        createdAt: Date = Date()
    ) {
        self.clientMessageId = clientMessageId
        self.senderRole = senderRole
        self.senderExternalId = senderExternalId
        self.contentTypeRaw = contentType.rawValue
        self.body = body
        self.createdAt = createdAt
    }
}

// MARK: - Server DTOs (mapping helpers)

nonisolated struct ServerConversation: Codable, Sendable {
    let id: String
    let masterExternalId: String
    let clientExternalId: String
    let lastMessagePreview: String?
    let lastMessageAt: String?
    let unreadMaster: Int
    let unreadClient: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case masterExternalId = "master_external_id"
        case clientExternalId = "client_external_id"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
        case unreadMaster = "unread_master"
        case unreadClient = "unread_client"
        case createdAt = "created_at"
    }
}

nonisolated struct ServerMessage: Codable, Sendable {
    let id: String
    let conversationId: String
    let senderRole: String
    let senderExternalId: String
    let contentType: String
    let body: String?
    let attachmentUrl: String?
    let attachmentMeta: [String: AnyCodable]?
    let clientMessageId: String?
    let seq: Int64
    let deliveredAt: String?
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderRole = "sender_role"
        case senderExternalId = "sender_external_id"
        case contentType = "content_type"
        case body
        case attachmentUrl = "attachment_url"
        case attachmentMeta = "attachment_meta"
        case clientMessageId = "client_message_id"
        case seq
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

/// Tiny helper so we can decode arbitrary JSON in `attachment_meta` without
/// committing to a schema yet.
nonisolated struct AnyCodable: Codable, Sendable {
    let value: Sendable

    init(_ value: Sendable) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = "" as Sendable }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(String.self) { value = v }
        else { value = "" as Sendable }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        default: try c.encodeNil()
        }
    }
}

// MARK: - ISO-8601 date helpers

enum ChatDateFormatter {
    /// Supabase / FastAPI default: ISO-8601 with optional fractional seconds.
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        return iso.date(from: s) ?? isoNoFraction.date(from: s)
    }
}
