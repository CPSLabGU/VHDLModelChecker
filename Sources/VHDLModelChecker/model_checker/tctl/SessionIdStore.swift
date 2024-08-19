import Foundation

final class SessionIdStore: Equatable, Hashable, Codable {

    private struct EncodedElement: Codable {
        let key: UUID
        let value: UInt

        var asTuple: (UUID, UInt) {
            (key, value)
        }

        init(value: (UUID, UInt)) {
            self.key = value.0
            self.value = value.1
        }
    }

    var sessionIds: [UUID: UInt]

    init(sessionIds: [UUID: UInt]) {
        self.sessionIds = sessionIds
    }

    convenience init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let elements: [EncodedElement] = try container.decode([EncodedElement].self)
        self.init(sessionIds: Dictionary(uniqueKeysWithValues: elements.map(\.asTuple)))
    }

    convenience init(store: SessionIdStore) {
        self.init(sessionIds: store.sessionIds)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        let ids: [EncodedElement] = self.sessionIds
            .sorted { $0.key.uuidString < $1.key.uuidString }.map { EncodedElement(value: $0) }
        try container.encode(ids)
    }

    func addSession(id: UUID) {
        if let count = sessionIds[id] {
            sessionIds[id] = count + 1
        } else {
            sessionIds[id] = 1
        }
    }

    func removeSession(id: UUID) {
        if let count = sessionIds[id] {
            sessionIds[id] = count - 1
        } else {
            fatalError("Attempting to remove a session with id `\(id)` which does not exist in store.")
        }
    }

    static func == (lhs: SessionIdStore, rhs: SessionIdStore) -> Bool {
        lhs.sessionIds == rhs.sessionIds
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionIds)
    }

}
