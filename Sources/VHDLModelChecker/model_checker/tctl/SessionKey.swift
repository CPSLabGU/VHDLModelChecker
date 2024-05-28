import Foundation
import TCTLParser

struct SessionKey: Equatable, Hashable {
    var nodeId: UUID
    var expression: Expression
    var constraints: [PhysicalConstraint]
}
