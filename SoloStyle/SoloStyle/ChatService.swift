//
//  ChatService.swift
//  SoloStyle
//
//  Chat networking layer: REST sync + WebSocket realtime + local outbox.
//
//  Threading model:
//    - The service is @MainActor so SwiftData reads/writes happen on the
//      same actor that owns the ModelContext (avoids "Model is not from
//      this context" crashes).
//    - Network calls are bounced into nonisolated helpers / a private
//      URLSession actor so we never block the main actor on I/O.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Connection State

enum ChatConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(message: String)
}

// MARK: - Chat Service

@MainActor
@Observable
final class ChatService {
    static let shared = ChatService()

    // MARK: - Public state

    private(set) var connectionState: ChatConnectionState = .disconnected
    private(set) var typingFromOther: [UUID: Date] = [:]   // conversation_id → last typing event

    // MARK: - Configuration

    /// REST + WS base.  Mirrors NetworkManager.baseURL (kept in sync manually
    /// — both default to Render production).
    private let restBase = URL(string: "https://solostyle-api.onrender.com/api/v1")!
    private var wsURL: URL? {
        guard let token = currentJWT else { return nil }
        var comps = URLComponents(string: "wss://solostyle-api.onrender.com/api/v1/chat/ws")!
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        return comps.url
    }

    // MARK: - Private state

    private var currentJWT: String?
    private var currentExternalId: String?  // JWT.sub — needed to resolve "self" in incoming msgs
    private var modelContext: ModelContext?

    private var wsTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveLoop: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var consecutiveFailures: Int = 0

    private let urlSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    private init() {}

    // MARK: - Lifecycle

    /// One-shot helper: pulls JWT and external_id from AuthManager, attaches
    /// the given SwiftData context, syncs conversations, and opens the
    /// WebSocket.  Safe to call repeatedly — no-op if already configured
    /// for the same user.
    func bootstrap(context: ModelContext) async {
        let auth = AuthManager.shared
        guard let jwt = auth.currentJWT(),
              let externalId = auth.currentUserExternalId else { return }

        // Skip if already wired up for this user and connected.
        if currentJWT == jwt, currentExternalId == externalId, wsTask != nil {
            return
        }

        configure(jwt: jwt, externalId: externalId, context: context)
        await syncConversations()
        connect()
    }

    /// Call once after authentication (or any time JWT changes).
    func configure(jwt: String, externalId: String, context: ModelContext) {
        // Reset prior connection state if any
        disconnect()
        self.currentJWT = jwt
        self.currentExternalId = externalId
        self.modelContext = context
    }

    /// Begin WebSocket session.  Idempotent — calling twice is a no-op.
    func connect() {
        guard let url = wsURL else { return }
        guard wsTask == nil else { return }
        guard connectionState != .connecting else { return }

        connectionState = .connecting
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        self.session = session

        let task = session.webSocketTask(with: url)
        self.wsTask = task
        task.resume()

        startReceiveLoop()
        startHeartbeat()
        connectionState = .connected
        consecutiveFailures = 0

        // Drain anything that piled up while we were offline.
        Task { await flushPending() }
    }

    func disconnect() {
        receiveLoop?.cancel()
        heartbeat?.cancel()
        reconnectTask?.cancel()
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        session?.invalidateAndCancel()
        session = nil
        connectionState = .disconnected
    }

    // MARK: - REST sync

    /// Upsert all server-side conversations into the local store.
    func syncConversations() async {
        guard let context = modelContext else { return }
        do {
            let url = restBase.appendingPathComponent("chat/conversations")
            let (data, _) = try await authedRequest(url, method: "GET")

            let decoder = JSONDecoder()
            let serverConvs = try decoder.decode([ServerConversation].self, from: data)

            for sc in serverConvs {
                guard let convUUID = UUID(uuidString: sc.id) else { continue }
                let existing = try fetchConversation(id: convUUID, context: context)
                let conv = existing ?? {
                    let new = MessengerConversation(
                        id: convUUID,
                        masterExternalId: sc.masterExternalId,
                        clientExternalId: sc.clientExternalId,
                        createdAt: ChatDateFormatter.parse(sc.createdAt) ?? Date()
                    )
                    context.insert(new)
                    return new
                }()
                conv.lastMessagePreview = sc.lastMessagePreview
                conv.lastMessageAt = ChatDateFormatter.parse(sc.lastMessageAt)
                conv.unreadMaster = sc.unreadMaster
                conv.unreadClient = sc.unreadClient
            }
            try context.save()
        } catch {
            print("[CHAT] syncConversations failed: \(error)")
        }
    }

    /// Pull missed messages for a conversation.  Uses the highest local seq
    /// as the starting point so we never refetch what we already have.
    func syncMessages(for conversationId: UUID) async {
        guard let context = modelContext else { return }
        guard let conv = try? fetchConversation(id: conversationId, context: context) else { return }

        do {
            var comps = URLComponents(
                url: restBase.appendingPathComponent("chat/conversations/\(conversationId.uuidString)/messages"),
                resolvingAgainstBaseURL: false
            )!
            comps.queryItems = [
                URLQueryItem(name: "since_seq", value: String(conv.lastSeenSeq)),
                URLQueryItem(name: "limit", value: "200"),
            ]

            let (data, _) = try await authedRequest(comps.url!, method: "GET")
            let serverMsgs = try JSONDecoder().decode([ServerMessage].self, from: data)
            for sm in serverMsgs {
                upsertMessage(sm, into: conv, context: context)
            }
            try context.save()
        } catch {
            print("[CHAT] syncMessages failed: \(error)")
        }
    }

    /// Find or create a conversation with `otherExternalId`.  `asRole` is the
    /// caller's role in the new conversation (master or client).
    func startConversation(otherExternalId: String, asRole: String) async -> MessengerConversation? {
        guard let context = modelContext else { return nil }

        struct Body: Codable { let other_external_id: String; let as_role: String }
        let url = restBase.appendingPathComponent("chat/conversations")

        do {
            let body = try JSONEncoder().encode(Body(other_external_id: otherExternalId, as_role: asRole))
            let (data, _) = try await authedRequest(url, method: "POST", body: body)
            let sc = try JSONDecoder().decode(ServerConversation.self, from: data)
            guard let convUUID = UUID(uuidString: sc.id) else { return nil }

            if let existing = try fetchConversation(id: convUUID, context: context) {
                return existing
            }

            let conv = MessengerConversation(
                id: convUUID,
                masterExternalId: sc.masterExternalId,
                clientExternalId: sc.clientExternalId,
                createdAt: ChatDateFormatter.parse(sc.createdAt) ?? Date()
            )
            context.insert(conv)
            try context.save()
            return conv
        } catch {
            print("[CHAT] startConversation failed: \(error)")
            return nil
        }
    }

    // MARK: - Sending

    /// Enqueue a text message.  The UI sees it immediately as a local row in
    /// `pending` state; the network layer flushes it as soon as a socket is
    /// available, with idempotent retries.
    func sendText(_ text: String, to conv: MessengerConversation) {
        guard let context = modelContext, let me = currentExternalId else { return }
        let role = conv.masterExternalId == me ? "master" : "client"
        let msg = MessengerMessage(
            senderRole: role,
            senderExternalId: me,
            contentType: .text,
            body: text
        )
        msg.conversation = conv
        context.insert(msg)
        try? context.save()

        Task { await flushPending() }
    }

    /// Notify the server that the user is typing.  Fire-and-forget.
    func sendTyping(conversationId: UUID) {
        let payload: [String: Any] = [
            "type": "typing",
            "conversation_id": conversationId.uuidString,
        ]
        Task { await sendJSON(payload) }
    }

    /// Mark all messages in a conversation up to `upToSeq` as read on the server.
    func sendRead(conversationId: UUID, upToSeq: Int64) {
        guard upToSeq > 0 else { return }
        let payload: [String: Any] = [
            "type": "read",
            "conversation_id": conversationId.uuidString,
            "up_to_seq": upToSeq,
        ]
        Task { await sendJSON(payload) }
    }

    // MARK: - Outbox flushing

    private func flushPending() async {
        guard let context = modelContext else { return }
        guard wsTask != nil else { connect(); return }

        // Find pending messages.  Sort by createdAt to preserve original order.
        let pendingPredicate = #Predicate<MessengerMessage> { $0.statusRaw == "pending" }
        var descriptor = FetchDescriptor<MessengerMessage>(
            predicate: pendingPredicate,
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 100
        guard let pending = try? context.fetch(descriptor) else { return }

        for msg in pending {
            await sendOne(msg)
        }
    }

    private func sendOne(_ msg: MessengerMessage) async {
        guard let conv = msg.conversation else { return }
        let payload: [String: Any] = [
            "type": "send",
            "conversation_id": conv.id.uuidString,
            "client_message_id": msg.clientMessageId.uuidString,
            "content_type": msg.contentTypeRaw,
            "body": msg.body ?? "",
        ]
        msg.sendAttempts += 1
        let ok = await sendJSON(payload)
        if !ok && msg.sendAttempts >= 5 {
            msg.status = .failed
            msg.failedReason = "max retries"
            try? modelContext?.save()
        }
    }

    // MARK: - WebSocket I/O

    @discardableResult
    private func sendJSON(_ payload: [String: Any]) async -> Bool {
        guard let task = wsTask else { return false }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let str = String(data: data, encoding: .utf8) else { return false }
            try await task.send(.string(str))
            return true
        } catch {
            print("[CHAT-WS] send error: \(error)")
            handleSocketFailure()
            return false
        }
    }

    private func startReceiveLoop() {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let task = await self?.wsTask else { break }
                do {
                    let msg = try await task.receive()
                    await self?.handleIncoming(msg)
                } catch {
                    if Task.isCancelled { break }
                    print("[CHAT-WS] receive error: \(error)")
                    await self?.handleSocketFailure()
                    break
                }
            }
        }
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { break }
                _ = await self?.sendJSON(["type": "ping"])
            }
        }
    }

    private func handleSocketFailure() {
        receiveLoop?.cancel()
        heartbeat?.cancel()
        wsTask?.cancel(with: .abnormalClosure, reason: nil)
        wsTask = nil
        session?.invalidateAndCancel()
        session = nil
        consecutiveFailures += 1
        connectionState = .reconnecting(attempt: consecutiveFailures)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            // exponential backoff capped at 30s: 1, 2, 4, 8, 16, 30, 30...
            let attempt = await self?.consecutiveFailures ?? 1
            let secs = min(30, Int(pow(2.0, Double(min(attempt, 5)))))
            try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.connect()
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) async {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }

        guard let data = text.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = raw["type"] as? String else { return }

        switch type {
        case "pong":
            break
        case "ack":
            handleAck(raw)
        case "message":
            handleNewMessage(raw)
        case "read":
            handleRead(raw)
        case "typing":
            handleTyping(raw)
        case "error":
            print("[CHAT-WS] server error: \(raw)")
        default:
            break
        }
    }

    private func handleAck(_ raw: [String: Any]) {
        guard let context = modelContext,
              let cmidStr = raw["client_message_id"] as? String,
              let cmid = UUID(uuidString: cmidStr),
              let serverMsg = raw["message"] as? [String: Any] else { return }

        // Find the local pending row by clientMessageId
        let predicate = #Predicate<MessengerMessage> { $0.clientMessageId == cmid }
        var descriptor = FetchDescriptor<MessengerMessage>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let local = try? context.fetch(descriptor).first else { return }

        if let serverIdStr = serverMsg["id"] as? String, let serverUUID = UUID(uuidString: serverIdStr) {
            local.serverId = serverUUID
        }
        if let seq = serverMsg["seq"] as? Int64 {
            local.seq = seq
        } else if let seqInt = serverMsg["seq"] as? Int {
            local.seq = Int64(seqInt)
        }
        local.status = .sent
        if let createdStr = serverMsg["created_at"] as? String,
           let created = ChatDateFormatter.parse(createdStr) {
            local.createdAt = created
        }
        // Bump conversation lastSeen / preview
        if let conv = local.conversation {
            conv.lastSeenSeq = max(conv.lastSeenSeq, local.seq)
            conv.lastMessageAt = local.createdAt
            conv.lastMessagePreview = local.contentType == .text ? (local.body ?? "") : "📷"
        }
        try? context.save()
    }

    private func handleNewMessage(_ raw: [String: Any]) {
        guard let context = modelContext,
              let convIdStr = raw["conversation_id"] as? String,
              let convId = UUID(uuidString: convIdStr),
              let serverMsg = raw["message"] as? [String: Any] else { return }

        guard let conv = try? fetchConversation(id: convId, context: context) else {
            // Conversation we don't know about — pull and try again
            Task {
                await syncConversations()
                await syncMessages(for: convId)
            }
            return
        }

        guard let sm = decodeServerMessage(serverMsg) else { return }
        upsertMessage(sm, into: conv, context: context)
        try? context.save()
    }

    private func handleRead(_ raw: [String: Any]) {
        guard let context = modelContext,
              let convIdStr = raw["conversation_id"] as? String,
              let convId = UUID(uuidString: convIdStr),
              let me = currentExternalId,
              let conv = try? fetchConversation(id: convId, context: context) else { return }

        let upTo: Int64 = (raw["up_to_seq"] as? Int64) ?? Int64((raw["up_to_seq"] as? Int) ?? 0)
        guard upTo > 0 else { return }

        // Mark MY messages (i.e. ones the other side has read) as read locally.
        let now = Date()
        for msg in conv.messages where msg.senderExternalId == me && msg.seq <= upTo && msg.readAt == nil {
            msg.readAt = now
            msg.status = .read
        }
        try? context.save()
    }

    private func handleTyping(_ raw: [String: Any]) {
        guard let convIdStr = raw["conversation_id"] as? String,
              let convId = UUID(uuidString: convIdStr) else { return }
        typingFromOther[convId] = Date()
        // Auto-clear after 5s
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self else { return }
            if let last = self.typingFromOther[convId], Date().timeIntervalSince(last) >= 4.9 {
                self.typingFromOther.removeValue(forKey: convId)
            }
        }
    }

    // MARK: - SwiftData helpers

    private func fetchConversation(id: UUID, context: ModelContext) throws -> MessengerConversation? {
        let predicate = #Predicate<MessengerConversation> { $0.id == id }
        var descriptor = FetchDescriptor<MessengerConversation>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func decodeServerMessage(_ raw: [String: Any]) -> ServerMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder().decode(ServerMessage.self, from: data)
    }

    private func upsertMessage(_ sm: ServerMessage, into conv: MessengerConversation, context: ModelContext) {
        guard let serverUUID = UUID(uuidString: sm.id) else { return }

        // Try to find by serverId first, then by clientMessageId (echoed-back send).
        let serverPredicate = #Predicate<MessengerMessage> { $0.serverId == serverUUID }
        var descriptor = FetchDescriptor<MessengerMessage>(predicate: serverPredicate)
        descriptor.fetchLimit = 1
        var local = (try? context.fetch(descriptor).first)

        if local == nil, let cmidStr = sm.clientMessageId, let cmid = UUID(uuidString: cmidStr) {
            let cmidPredicate = #Predicate<MessengerMessage> { $0.clientMessageId == cmid }
            var d2 = FetchDescriptor<MessengerMessage>(predicate: cmidPredicate)
            d2.fetchLimit = 1
            local = try? context.fetch(d2).first
        }

        if local == nil {
            let cmid = sm.clientMessageId.flatMap(UUID.init(uuidString:)) ?? UUID()
            let new = MessengerMessage(
                clientMessageId: cmid,
                senderRole: sm.senderRole,
                senderExternalId: sm.senderExternalId,
                contentType: ChatMessageContentType(rawValue: sm.contentType) ?? .text,
                body: sm.body,
                createdAt: ChatDateFormatter.parse(sm.createdAt) ?? Date()
            )
            new.conversation = conv
            context.insert(new)
            local = new
        }

        guard let row = local else { return }
        row.serverId = serverUUID
        row.seq = sm.seq
        row.senderRole = sm.senderRole
        row.senderExternalId = sm.senderExternalId
        row.contentTypeRaw = sm.contentType
        row.body = sm.body
        row.attachmentUrl = sm.attachmentUrl
        row.deliveredAt = ChatDateFormatter.parse(sm.deliveredAt)
        row.readAt = ChatDateFormatter.parse(sm.readAt)
        if row.status == .pending { row.status = .sent }
        if row.readAt != nil { row.status = .read }

        // Conversation bookkeeping
        conv.lastSeenSeq = max(conv.lastSeenSeq, sm.seq)
        conv.lastMessageAt = ChatDateFormatter.parse(sm.createdAt) ?? conv.lastMessageAt
        conv.lastMessagePreview = sm.contentType == "text" ? sm.body : "📷"
    }

    // MARK: - Authed REST helper

    private func authedRequest(_ url: URL, method: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let token = currentJWT else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad response"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "ChatService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
        }
        return (data, http)
    }
}
