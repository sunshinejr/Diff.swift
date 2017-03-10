#if os(iOS)

import UIKit

struct BatchUpdate {
    let deletions: [NSIndexPath]
    let insertions: [NSIndexPath]
    let moves: [(from: NSIndexPath, to: NSIndexPath)]

    init(
        diff: ExtendedDiff,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 }
        ) {
        deletions = diff.flatMap { element -> NSIndexPath? in
            switch element {
            case .delete(let at):
                return indexPathTransform(NSIndexPath(forRow: at, inSection: 0))
            default: return nil
            }
        }
        insertions = diff.flatMap { element -> NSIndexPath? in
            switch element {
            case .insert(let at):
                return indexPathTransform(NSIndexPath(forRow: at, inSection: 0))
            default: return nil
            }
        }
        moves = diff.flatMap { element -> (NSIndexPath, NSIndexPath)? in
            switch element {
            case let .move(from, to):
                return (indexPathTransform(NSIndexPath(forRow: from, inSection: 0)), indexPathTransform(NSIndexPath(forRow: to, inSection: 0)))
            default: return nil
            }
        }
    }
}
    
struct NestedBatchUpdate {
    let itemDeletions: [NSIndexPath]
    let itemInsertions: [NSIndexPath]
    let itemMoves: [(from: NSIndexPath, to: NSIndexPath)]
    let sectionDeletions: NSIndexSet
    let sectionInsertions: NSIndexSet
    let sectionMoves: [(from: Int, to: Int)]
    
    init(
        diff: NestedExtendedDiff,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 }
        ) {
        
        var itemDeletions: [NSIndexPath] = []
        var itemInsertions: [NSIndexPath] = []
        var itemMoves: [(from: NSIndexPath, to: NSIndexPath)] = []
        let sectionDeletions: NSMutableIndexSet = NSMutableIndexSet()
        let sectionInsertions: NSMutableIndexSet = NSMutableIndexSet()
        var sectionMoves: [(from: Int, to: Int)] = []
        
        diff.forEach { element in
            switch element {
            case let .deleteElement(at, section):
                itemDeletions.append(indexPathTransform(NSIndexPath(forItem: at, inSection: section)))
            case let .insertElement(at, section):
                itemInsertions.append(indexPathTransform(NSIndexPath(forItem: at, inSection: section)))
            case let .moveElement(from, to):
                itemMoves.append((indexPathTransform(NSIndexPath(forItem: from.item, inSection: from.section)), indexPathTransform(NSIndexPath(forItem: to.item, inSection: to.section))))
            case let .deleteSection(at):
                sectionDeletions.addIndex(sectionTransform(at))
            case let .insertSection(at):
                sectionInsertions.addIndex(sectionTransform(at))
            case let .moveSection(move):
                sectionMoves.append((from: sectionTransform(move.from), to: sectionTransform(move.to)))
            }
        }
        
        self.itemInsertions = itemInsertions
        self.itemDeletions = itemDeletions
        self.itemMoves = itemMoves
        self.sectionMoves = sectionMoves
        self.sectionInsertions = sectionInsertions
        self.sectionDeletions = sectionDeletions
    }
}

public extension UITableView {

    /// Animates rows which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    public func animateRowChanges<T: CollectionType where T.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        deletionAnimation: UITableViewRowAnimation = .Automatic,
        insertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 }
    ) {
        apply(
            oldData.extendedDiff(newData),
            deletionAnimation: deletionAnimation,
            insertionAnimation: insertionAnimation,
            indexPathTransform: indexPathTransform
        )
    }
    
    /// Animates rows which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter isEqual:            A function comparing two elements of `T`
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    public func animateRowChanges<T: CollectionType>(
        oldData oldData: T,
        newData: T,
        // https://twitter.com/dgregor79/status/570068545561735169
        isEqual: (EqualityChecker<T>),
        deletionAnimation: UITableViewRowAnimation = .Automatic,
        insertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 }
        ) {
        apply(
            oldData.extendedDiff(newData, isEqual: isEqual),
            deletionAnimation: deletionAnimation,
            insertionAnimation: insertionAnimation,
            indexPathTransform: indexPathTransform
        )
    }
    
    public func apply(
        diff: ExtendedDiff,
        deletionAnimation: UITableViewRowAnimation = .Automatic,
        insertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 }
        ) {
        let update = BatchUpdate(diff: diff, indexPathTransform: indexPathTransform)

        beginUpdates()
        deleteRowsAtIndexPaths(update.deletions, withRowAnimation: deletionAnimation)
        insertRowsAtIndexPaths(update.insertions, withRowAnimation: insertionAnimation)
        update.moves.forEach { moveRowAtIndexPath($0.from, toIndexPath: $0.to) }
        endUpdates()
    }
    
    /// Animates rows and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateRowAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element: Equatable, T.Generator.Element.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        rowDeletionAnimation: UITableViewRowAnimation = .Automatic,
        rowInsertionAnimation: UITableViewRowAnimation = .Automatic,
        sectionDeletionAnimation: UITableViewRowAnimation = .Automatic,
        sectionInsertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 }
        ) {
            apply(
                oldData.nestedExtendedDiff(to: newData),
                rowDeletionAnimation: rowDeletionAnimation,
                rowInsertionAnimation: rowInsertionAnimation,
                sectionDeletionAnimation: sectionDeletionAnimation,
                sectionInsertionAnimation: sectionInsertionAnimation,
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform
            )
    }
    
    
    /// Animates rows and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter isEqualElement:     A function comparing two items (elements of `T.Iterator.Element`)    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateRowAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        // https://twitter.com/dgregor79/status/570068545561735169
        isEqualElement: (NestedElementEqualityChecker<T>),
        rowDeletionAnimation: UITableViewRowAnimation = .Automatic,
        rowInsertionAnimation: UITableViewRowAnimation = .Automatic,
        sectionDeletionAnimation: UITableViewRowAnimation = .Automatic,
        sectionInsertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 }
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualElement: isEqualElement
                ),
                rowDeletionAnimation: rowDeletionAnimation,
                rowInsertionAnimation: rowInsertionAnimation,
                sectionDeletionAnimation: sectionDeletionAnimation,
                sectionInsertionAnimation: sectionInsertionAnimation,
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform
            )
    }
    
    /// Animates rows and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter isEqualSection:     A function comparing two sections (elements of `T`)
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateRowAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        // https://twitter.com/dgregor79/status/570068545561735169
        isEqualSection: (EqualityChecker<T>),
        rowDeletionAnimation: UITableViewRowAnimation = .Automatic,
        rowInsertionAnimation: UITableViewRowAnimation = .Automatic,
        sectionDeletionAnimation: UITableViewRowAnimation = .Automatic,
        sectionInsertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 }
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualSection: isEqualSection
                ),
                rowDeletionAnimation: rowDeletionAnimation,
                rowInsertionAnimation: rowInsertionAnimation,
                sectionDeletionAnimation: sectionDeletionAnimation,
                sectionInsertionAnimation: sectionInsertionAnimation,
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform
            )
    }
    
    /// Animates rows and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UITableView`
    /// - parameter newData:            Data which reflects the current state of `UITableView`
    /// - parameter isEqualSection:     A function comparing two sections (elements of `T`)
    /// - parameter isEqualElement:     A function comparing two items (elements of `T.Iterator.Element`)
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateRowAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType>(
        oldData oldData: T,
        newData: T,
        isEqualSection: EqualityChecker<T>,
        // https://twitter.com/dgregor79/status/570068545561735169
        isEqualElement: (NestedElementEqualityChecker<T>),
        rowDeletionAnimation: UITableViewRowAnimation = .Automatic,
        rowInsertionAnimation: UITableViewRowAnimation = .Automatic,
        sectionDeletionAnimation: UITableViewRowAnimation = .Automatic,
        sectionInsertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 }
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualSection: isEqualSection,
                    isEqualElement: isEqualElement
                ),
                rowDeletionAnimation: rowDeletionAnimation,
                rowInsertionAnimation: rowInsertionAnimation,
                sectionDeletionAnimation: sectionDeletionAnimation,
                sectionInsertionAnimation: sectionInsertionAnimation,
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform
            )
    }
    
    public func apply(
        diff: NestedExtendedDiff,
        rowDeletionAnimation: UITableViewRowAnimation = .Automatic,
        rowInsertionAnimation: UITableViewRowAnimation = .Automatic,
        sectionDeletionAnimation: UITableViewRowAnimation = .Automatic,
        sectionInsertionAnimation: UITableViewRowAnimation = .Automatic,
        indexPathTransform: (NSIndexPath) -> NSIndexPath,
        sectionTransform: (Int) -> Int
        ) {
        
        let update = NestedBatchUpdate(diff: diff, indexPathTransform: indexPathTransform, sectionTransform: sectionTransform)
        beginUpdates()
        deleteRowsAtIndexPaths(update.itemDeletions, withRowAnimation: rowDeletionAnimation)
        insertRowsAtIndexPaths(update.itemInsertions, withRowAnimation: rowInsertionAnimation)
        update.itemMoves.forEach { moveRowAtIndexPath($0.from, toIndexPath: $0.to) }
        deleteSections(update.sectionDeletions, withRowAnimation: sectionDeletionAnimation)
        insertSections(update.sectionInsertions, withRowAnimation: sectionInsertionAnimation)
        update.sectionMoves.forEach { moveSection($0.from, toSection: $0.to) }
        endUpdates()
    }
}

public extension UICollectionView {

    /// Animates items which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    public func animateItemChanges<T: CollectionType where T.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        completion: ((Bool) -> Void)? = nil
    ) {
        let diff = oldData.extendedDiff(newData)
        apply(diff, completion: completion, indexPathTransform: indexPathTransform)
    }
    
    /// Animates items which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter isEqual:            A function comparing two elements of `T`
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    public func animateItemChanges<T: CollectionType>(
        oldData oldData: T,
        newData: T,
        isEqual: EqualityChecker<T>,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        completion: ((Bool) -> Swift.Void)? = nil
        ) {
        let diff = oldData.extendedDiff(newData, isEqual: isEqual)
        apply(diff, completion: completion, indexPathTransform: indexPathTransform)
    }
    
    public func apply(
        diff: ExtendedDiff,
        completion: ((Bool) -> Swift.Void)? = nil,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 }
        ) {
        performBatchUpdates({
            let update = BatchUpdate(diff: diff, indexPathTransform: indexPathTransform)
            self.deleteItemsAtIndexPaths(update.deletions)
            self.insertItemsAtIndexPaths(update.insertions)
            update.moves.forEach { self.moveItemAtIndexPath($0.from, toIndexPath: $0.to) }
        }, completion: completion)
    }
    
    /// Animates items and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateItemAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element: Equatable, T.Generator.Element.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 },
        completion: ((Bool) -> Swift.Void)? = nil
        ) {
            apply(
                oldData.nestedExtendedDiff(to: newData),
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform,
                completion: completion
            )
    }
    
    /// Animates items and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter isEqualElement:     A function comparing two items (elements of `T.Iterator.Element`)
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateItemAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        isEqualElement: NestedElementEqualityChecker<T>,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 },
        completion: ((Bool) -> Swift.Void)? = nil
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualElement: isEqualElement
                ),
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform,
                completion: completion
            )
    }
    
    /// Animates items and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter isEqualSection:     A function comparing two sections (elements of `T`)
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateItemAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType, T.Generator.Element.Generator.Element: Equatable>(
        oldData oldData: T,
        newData: T,
        isEqualSection: EqualityChecker<T>,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 },
        completion: ((Bool) -> Swift.Void)? = nil
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualSection: isEqualSection
                ),
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform,
                completion: completion
        )
    }
    
    /// Animates items and sections which changed between oldData and newData.
    ///
    /// - parameter oldData:            Data which reflects the previous state of `UICollectionView`
    /// - parameter newData:            Data which reflects the current state of `UICollectionView`
    /// - parameter isEqualSection:     A function comparing two sections (elements of `T`)
    /// - parameter isEqualElement:     A function comparing two items (elements of `T.Iterator.Element`)
    /// - parameter deletionAnimation:  Animation type for deletions
    /// - parameter insertionAnimation: Animation type for insertions
    /// - parameter indexPathTransform: Closure which transforms zero-based `IndexPath` to desired  `IndexPath`
    /// - parameter sectionTransform:   Closure which transforms zero-based section(`Int`) into desired section(`Int`)
    public func animateItemAndSectionChanges<T: CollectionType where T.Generator.Element: CollectionType>(
        oldData oldData: T,
        newData: T,
        isEqualSection: EqualityChecker<T>,
        isEqualElement: NestedElementEqualityChecker<T>,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 },
        completion: ((Bool) -> Swift.Void)? = nil
        ) {
            apply(
                oldData.nestedExtendedDiff(
                    to: newData,
                    isEqualSection: isEqualSection,
                    isEqualElement: isEqualElement
                ),
                indexPathTransform: indexPathTransform,
                sectionTransform: sectionTransform,
                completion: completion
        )
    }
    
    public func apply(
        diff: NestedExtendedDiff,
        indexPathTransform: (NSIndexPath) -> NSIndexPath = { $0 },
        sectionTransform: (Int) -> Int = { $0 },
        completion: ((Bool) -> Void)? = nil
        ) {
        performBatchUpdates({ 
            let update = NestedBatchUpdate(diff: diff, indexPathTransform: indexPathTransform, sectionTransform: sectionTransform)
            self.insertSections(update.sectionInsertions)
            self.deleteSections(update.sectionDeletions)
            update.sectionMoves.forEach { self.moveSection($0.from, toSection: $0.to) }
            self.deleteItemsAtIndexPaths(update.itemDeletions)
            self.insertItemsAtIndexPaths(update.itemInsertions)
            update.itemMoves.forEach { self.moveItemAtIndexPath($0.from, toIndexPath: $0.to) }
        }, completion: completion)
    }
}

#endif
