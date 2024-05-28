import Foundation

final class SessionIdStore: Equatable, Hashable {

    var sessionIds: [UUID: UInt]

    init(sessionIds: [UUID: UInt]) {
        self.sessionIds = sessionIds
    }

    convenience init(store: SessionIdStore) {
        self.init(sessionIds: store.sessionIds)
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
