
import Foundation

public extension RangeReplaceableCollectionType where Generator.Element: Equatable {

    public func apply(patch: [Patch<Generator.Element>]) -> Self {
        var mutableSelf = self

        for change in patch {
            switch change {
            case let .insertion(i as Index.Distance, element):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.insert(element, atIndex: target)
            case let .deletion(i as Index.Distance):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.removeAtIndex(target)
            default: ()
            }
        }

        return mutableSelf
    }
}

public extension String {

    public func apply(patch: [Patch<String.CharacterView.Generator.Element>]) -> String {
        var mutableSelf = self

        for change in patch {
            switch change {
            case let .insertion(i, element):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.insert(element, atIndex: target)
            case let .deletion(i):
                let target = mutableSelf.startIndex.advancedBy(i)
                mutableSelf.removeAtIndex(target)
            }
        }

        return mutableSelf
    }
}
