
// TODO: Fix ugly copy paste :/

public extension RangeReplaceableCollectionType where Generator.Element: Equatable {

    public func apply(patch: [ExtendedPatch<Generator.Element>]) -> Self {
        var mutableSelf = self

        for change in patch {
            switch change {
            case let .insertion(i as Index.Distance, element):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.insert(element, atIndex: target)
            case let .deletion(i as Index.Distance):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.removeAtIndex(target)
            case let .move(from as Index.Distance, to as Index.Distance):
                let fromIndex = mutableSelf.startIndex.advancedBy(from)
                let toIndex = mutableSelf.startIndex.advancedBy(to)
                let element = mutableSelf.removeAtIndex(fromIndex)
                mutableSelf.insert(element, atIndex: toIndex)
            default: ()
            }
        }

        return mutableSelf
    }
}

public extension String {

    public func apply(patch: [ExtendedPatch<String.CharacterView.Generator.Element>]) -> String {
        var mutableSelf = self

        for change in patch {
            switch change {
            case let .insertion(i, element):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.insert(element, atIndex: target)
            case let .deletion(i):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.removeAtIndex(target)
            case let .move(from, to):
                let fromIndex = mutableSelf.startIndex.advancedBy(from)
                let toIndex = mutableSelf.startIndex.advancedBy(to)
                let element = mutableSelf.removeAtIndex(fromIndex)
                mutableSelf.insert(element, atIndex: toIndex)
            }
        }

        return mutableSelf
    }
}
