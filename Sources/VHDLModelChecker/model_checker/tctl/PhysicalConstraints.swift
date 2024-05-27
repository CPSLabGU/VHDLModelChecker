import TCTLParser
import VHDLKripkeStructures

final class PhysicalConstraint: Equatable, Hashable {

    var cost: Cost

    var constraint: ConstrainedStatement

    init(cost: Cost, constraint: ConstrainedStatement) {
        self.cost = cost
        self.constraint = constraint
    }

    static func == (lhs: PhysicalConstraint, rhs: PhysicalConstraint) -> Bool {
        return lhs.cost == rhs.cost && lhs.constraint == rhs.constraint
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(cost)
        hasher.combine(constraint)
    }

    func verify(node: Node) throws {
        try constraint.verify(node: node, cost: cost)
    }

}
