//
//  EmailCodeManager.swift
//  2FHey
//
//  Fork: emailed verification codes, via the local Gmail helper on 127.0.0.1:3078
//  (infra/chrome-extensions email-code-fill). Polls /codes and emits codes not seen before.
//

import Foundation
import Combine

struct EmailCode: Equatable {
    let id: String
    let account: String
    let code: String
    let from: String
    let subject: String
    let match: Bool
    let ageSeconds: Int
}

class EmailCodeManager: ObservableObject, MessageSource {
    @Published var messages: [MessageWithParsedOTP] = []
    var messagesPublisher: AnyPublisher<[MessageWithParsedOTP], Never> { $messages.eraseToAnyPublisher() }

    static let base = "http://127.0.0.1:3078"
    static let maxAge = 120
    private let pollInterval: TimeInterval = 5, backoffInterval: TimeInterval = 30

    private var seen: Set<String> = []
    private var info: [String: (account: String, match: Bool, onlyFresh: Bool)] = [:]
    private var running = false
    private var timer: DispatchWorkItem?

    // MARK: - Pure parsing (tested)

    /// Decodes the /codes response, dropping codes already seen or older than `maxAge`.
    /// `onlyFresh` is true when the helper returned a single code in total.
    static func newCodes(from data: Data, seen: Set<String>) -> (codes: [EmailCode], onlyFresh: Bool)? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["codes"] as? [[String: Any]] else { return nil }
        let all = raw.compactMap { d -> EmailCode? in
            guard let id = d["id"] as? String, let code = d["code"] as? String else { return nil }
            return EmailCode(id: id, account: d["account"] as? String ?? "", code: code, from: d["from"] as? String ?? "",
                             subject: d["subject"] as? String ?? "", match: d["match"] as? Bool ?? false,
                             ageSeconds: d["age_s"] as? Int ?? .max)
        }
        return (all.filter { !seen.contains($0.id) && $0.ageSeconds <= maxAge }, all.count == 1)
    }

    static func makeMessage(_ c: EmailCode) -> MessageWithParsedOTP {
        (Message(rowId: 0, guid: c.id, text: "\(c.from): \(c.subject)", handle: c.from, group: nil, fromMe: false),
         ParsedOTP(service: c.from, code: c.code))
    }

    // MARK: - Source-specific lookups for AppDelegate

    func owns(guid: String) -> Bool { info[guid] != nil }

    func origin(guid: String) -> CodeOrigin? {
        info[guid].map { .email(match: $0.match, onlyFresh: $0.onlyFresh) }
    }

    // MARK: - MessageSource

    func startListening() {
        guard !running else { return }
        running = true
        poll()
    }

    func stopListening() {
        running = false
        timer?.cancel()
    }

    func reset() { messages = [] }

    func injectTestMessage(_ text: String) {}

    func markMessageAsRead(guid: String) {
        guard let account = info[guid]?.account,
              let url = URL(string: Self.base + "/used"),
              let body = try? JSONSerialization.data(withJSONObject: ["id": guid, "account": account]) else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Polling

    private func poll() {
        guard running else { return }
        let ctx = FrontmostContext.current()
        var comps = URLComponents(string: Self.base + "/codes")!
        comps.queryItems = [URLQueryItem(name: "host", value: ctx.host), URLQueryItem(name: "title", value: ctx.title)]
        let req = URLRequest(url: comps.url!, timeoutInterval: 4)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self, self.running else { return }
                let parsed = data.flatMap { Self.newCodes(from: $0, seen: self.seen) }
                if let parsed { self.handle(parsed.codes, onlyFresh: parsed.onlyFresh) }
                self.schedule(after: parsed == nil ? self.backoffInterval : self.pollInterval)
            }
        }.resume()
    }

    private func handle(_ codes: [EmailCode], onlyFresh: Bool) {
        guard !codes.isEmpty else { return }
        var updated = messages
        for c in codes.reversed() { // best match last, so it is the "newest" the pipeline picks
            seen.insert(c.id)
            info[c.id] = (c.account, c.match, onlyFresh)
            updated.append(Self.makeMessage(c))
        }
        messages = Array(updated.suffix(3)) // one publish, so one notification
    }

    private func schedule(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in self?.poll() }
        timer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
