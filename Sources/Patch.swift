

/// Single step in a patch sequence.
public enum Patch<Element> {
    /// A single patch step containing an insertion index and an element to be inserted
    case insertion(index: Int, element: Element)
    /// A single patch step containing a deletion index
    case deletion(index: Int)

    func index() -> Int {
        switch self {
        case let .insertion(index, _):
            return index
        case let .deletion(index):
            return index
        }
    }
}

public extension Diff {

    /**
     Generates a patch sequence based on a diff. It is a list of steps to be applied to obtain the `to` collection from the `from` one.

     - parameter from: The source collection (usually the source collecetion of the callee)
     - parameter to: The target collection (usually the target collecetion of the callee)
     - complexity: O(N)
     - returns: A sequence of steps to obtain `to` collection from the `from` one.
     */
    public func patch<T: CollectionType where T.Generator.Element: Equatable>(
        from from: T,
        to: T
    ) -> [Patch<T.Generator.Element>] {
        var shift = 0
        
        return map { element in
            switch element {
            case let .delete(at):
                shift -= 1
                return .deletion(index: at + shift + 1)
            case let .insert(at):
                shift += 1
                return .insertion(index: at, element: to.itemOnStartIndex(advancedBy: at))
            }
        }
    }
}

/**
 Generates a patch sequence. It is a list of steps to be applied to obtain the `to` collection from the `from` one.

 - parameter from: The source collection
 - parameter to: The target collection
 - complexity: O((N+M)*D)
 - returns: A sequence of steps to obtain `to` collection from the `from` one.
 */
public func patch<T: CollectionType where T.Generator.Element: Equatable>(
    from: T,
    to: T
) -> [Patch<T.Generator.Element>] {
    return from.diff(to).patch(from: from, to: to)
}

extension Patch: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .deletion(at):
            return "D(\(at))"
        case let .insertion(at, element):
            return "I(\(at),\(element))"
        }
    }
}
