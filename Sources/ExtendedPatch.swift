
enum BoxedDiffAndPatchElement<T> {
    case move(
        diffElement: ExtendedDiff.Element,
        deletion: SortedPatchElement<T>,
        insertion: SortedPatchElement<T>
    )
    case single(
        diffElement: ExtendedDiff.Element,
        patchElement: SortedPatchElement<T>
    )

    var diffElement: ExtendedDiff.Element {
        switch self {
        case .move(let de, _, _):
            return de
        case .single(let de, _):
            return de
        }
    }
}

/// Single step in a patch sequence.
///
/// - insertion:      A single patch step containing an insertion index and an element to be inserted
/// - deletion:       A single patch step containing a deletion index
/// - move:           A single patch step containing the origin and target of a move
public enum ExtendedPatch<Element> {
    case insertion(index: Int, element: Element)
    case deletion(index: Int)
    case move(from: Int, to: Int)
}

/**
 Generates a patch sequence. It is a list of steps to be applied to obtain the `to` collection from the `from` one.
 The sorting function lets you sort the output e.g. you might want the output patch to have insertions first.

 - parameter from: The source collection
 - parameter to: The target collection
 - parameter sort: A sorting function
 - complexity: O((N+M)*D)
 - returns: Arbitrarly sorted sequence of steps to obtain `to` collection from the `from` one.
 */
public func extendedPatch<T: CollectionType where T.Generator.Element: Equatable>(
    from: T,
    to: T,
    sort: ExtendedDiff.OrderedBefore? = nil
) -> [ExtendedPatch<T.Generator.Element>] {
    return from.extendedDiff(to).patch(from: from, to: to, sort: sort)
}

extension ExtendedDiff {
    public typealias OrderedBefore = (fst: ExtendedDiff.Element, snd: ExtendedDiff.Element) -> Bool

    /**
     Generates a patch sequence based on the callee. It is a list of steps to be applied to obtain the `to` collection from the `from` one.
     The sorting function lets you sort the output e.g. you might want the output patch to have insertions first.

     - parameter from: The source collection (usually the source collecetion of the callee)
     - parameter to: The target collection (usually the target collecetion of the callee)
     - parameter sort: A sorting function
     - complexity: O(D^2)
     - returns: Arbitrarly sorted sequence of steps to obtain `to` collection from the `from` one.
     */
    public func patch<T: CollectionType where T.Generator.Element: Equatable>(
        from from: T,
        to: T,
        sort: OrderedBefore? = nil
    ) -> [ExtendedPatch<T.Generator.Element>] {

        let result: [SortedPatchElement<T.Generator.Element>]
        if let sort = sort {
            result = shiftedPatchElements(from: generateSortedPatchElements(from: from, to: to, sort: sort))
        } else {
            result = shiftedPatchElements(from: generateSortedPatchElements(from: from, to: to))
        }

        return result.indices.flatMap { i -> ExtendedPatch<T.Generator.Element>? in
            let patchElement = result[i]
            if moveIndices.contains(patchElement.sourceIndex) {
                let to = result[i + 1].value
                switch patchElement.value {
                case .deletion(let index):
                    if case let .insertion(toIndex, _) = to {
                        return .move(from: index, to: toIndex)
                    } else {
                        fatalError()
                    }
                case .insertion(let index, _):
                    if case .deletion(let fromIndex) = to {
                        return .move(from: fromIndex, to: index)
                    } else {
                        fatalError()
                    }
                }
            } else if !(i > 0 && moveIndices.contains(result[i - 1].sourceIndex)) {
                switch patchElement.value {
                case .deletion(let index):
                    return .deletion(index: index)
                case let .insertion(index, element):
                    return .insertion(index: index, element: element)
                }
            }
            return nil
        }
    }

    func generateSortedPatchElements<T: CollectionType where T.Generator.Element: Equatable>(
        from from: T,
        to: T,
        sort: OrderedBefore
    ) -> [SortedPatchElement<T.Generator.Element>] {
        let unboxed = boxDiffAndPatchElements(
            from: from,
            to: to
        ).sort { from, to -> Bool in
            return sort(fst: from.diffElement, snd: to.diffElement)
        }.flatMap(unbox)

        return unboxed.indices.map { index -> SortedPatchElement<T.Generator.Element> in
            let old = unboxed[index]
            return SortedPatchElement(
                value: old.value,
                sourceIndex: old.sourceIndex,
                sortedIndex: index)
        }.sort { (fst, snd) -> Bool in
            return fst.sourceIndex < snd.sourceIndex
        }
    }

    func generateSortedPatchElements<T: CollectionType where T.Generator.Element: Equatable>(
        from from: T,
        to: T
    ) -> [SortedPatchElement<T.Generator.Element>] {
        let patch = source.patch(from: from, to: to)
        return patch.indices.map {
            SortedPatchElement(
                value: patch[$0],
                sourceIndex: $0,
                sortedIndex: reorderedIndex[$0]
            )
        }
    }

    func boxDiffAndPatchElements<T: CollectionType where T.Generator.Element: Equatable>(
        from from: T,
        to: T
    ) -> [BoxedDiffAndPatchElement<T.Generator.Element>] {
        let sourcePatch = generateSortedPatchElements(from: from, to: to)
        var indexDiff = 0
        return elements.indices.map { i in
            let diffElement = elements[i]
            switch diffElement {
            case .move:
                indexDiff += 1
                return .move(
                    diffElement: diffElement,
                    deletion: sourcePatch[sourceIndex[i + indexDiff - 1]],
                    insertion: sourcePatch[sourceIndex[i + indexDiff]]
                )
            default:
                return .single(
                    diffElement: diffElement,
                    patchElement: sourcePatch[sourceIndex[i + indexDiff]]
                )
            }
        }
    }
}

func unbox<T>(element: BoxedDiffAndPatchElement<T>) -> [SortedPatchElement<T>] {
    switch element {
    case let .move(_, deletion, insertion):
        return [deletion, insertion]
    case let .single(_, singasd):
        return [singasd]
    }
}

extension ExtendedPatch: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .deletion(at):
            return "D(\(at))"
        case let .insertion(at, element):
            return "I(\(at),\(element))"
        case let .move(from, to):
            return "M(\(from),\(to))"
        }
    }
}
