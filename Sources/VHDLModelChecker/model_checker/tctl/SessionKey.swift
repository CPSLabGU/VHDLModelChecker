import Foundation
import TCTLParser

struct SessionKey: Equatable, Hashable, Codable {
    var nodeId: UUID
    var expression: Expression
    var constraints: [PhysicalConstraint]
}
