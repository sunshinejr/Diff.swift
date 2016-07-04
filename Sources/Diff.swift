
public struct Diff {
    public let elements: [DiffElement]
}

public enum DiffElement {
    case Insert(from: Int, at: Int)
    case Delete(at: Int)
}

extension DiffElement {
    init?(trace: Trace) {
        switch trace.type() {
        case .Insertion:
            self = .Insert(from: trace.from.y, at: trace.to.x-(trace.from.x-trace.from.y))
        case .Deletion:
            self = .Delete(at: trace.from.x)
        case .MatchPoint:
            return nil
        }
    }
}

public struct Point {
    public let x: Int
    public let y: Int
}

extension Point: Equatable {}

public func ==(l: Point, r: Point) -> Bool {
    return (l.x == r.x) && (l.y == r.y)
}

public struct Trace {
    public let from: Point
    public let to: Point
    public let D: Int
}

extension Trace: Hashable {
    public var hashValue: Int {
        return (((51 + from.x.hashValue) * 51 + from.y.hashValue) * 51 + to.x.hashValue) * 51 + to.y.hashValue
    }
}
extension Trace: Equatable {}

public func ==(l: Trace, r: Trace) -> Bool {
    return (l.from == r.from) && (l.to == r.to)
}

enum TraceType {
    case Insertion
    case Deletion
    case MatchPoint
}

extension Trace {
    func type() -> TraceType {
        if from.x+1 == to.x && from.y+1 == to.y {
            return .MatchPoint
        } else if from.y < to.y {
            return .Insertion
        } else {
            return .Deletion
        }
    }
    
    func k() -> Int {
        return from.x - from.y
    }
}

public extension RangeReplaceableCollectionType where Self.Generator.Element : Equatable, Self.Index : SignedIntegerType {

    public func apply(patch: [PatchElement<Generator.Element, Index>]) -> Self {
        var mutableSelf = self

        for change in patch {
            switch change {
            case let .Insertion(index, element):
                mutableSelf.insert(element, atIndex: index)
            case let .Deletion(index):
                mutableSelf.removeAtIndex(index)
            }
        }

        return mutableSelf
    }
}

extension ForwardIndexType {
    func advancedByInt(x: Int) -> Self {
        return advancedBy(Distance(x.toIntMax()))
    }
}

public extension String {
    public func diff(b: String) -> Diff {
        if self == b {
            return Diff(elements: [])
        }
        return characters.diff(b.characters)
    }
}

extension Array {
    func value(at index: Index) -> Generator.Element? {
        if (index < 0 || index >= self.count) {
            return nil
        }
        return self[index]
    }
}

public extension CollectionType where Generator.Element : Equatable {
    
    private func tracesForDeletions() -> [Trace] {
        var traces = [Trace]()
        for index in 0..<self.count.toIntMax() {
            let intIndex = index.toIntMax()
            traces.append(Trace(from: Point(x: Int(intIndex), y: 0), to: Point(x: Int(intIndex)+1, y: 0), D: 0))
        }
        return traces
    }
    
    private func tracesForInsertions(b: Self) -> [Trace] {
        var traces = [Trace]()
        for index in 0..<b.count.toIntMax() {
            let intIndex = index.toIntMax()
            traces.append(Trace(from: Point(x: 0, y: Int(intIndex)), to: Point(x: 0, y: Int(intIndex)+1), D: 0))
        }
        return traces
    }
    
    public func diffTraces(b: Self) -> [Trace] {
        
        // Simple optimizations
        if (self.count == 0 && b.count == 0) {
            return []
        } else if (self.count == 0) {
            return tracesForInsertions(b)
        } else if (b.count == 0) {
            return tracesForDeletions()
        }
        
        let N = Int(self.count.toIntMax())
        let M = Int(b.count.toIntMax())
        var traces = Array<Trace>()
        
        let max = N+M // this is arbitrary, maximum difference between a and b. N+M assures that this algorithm always finds a diff
        
        var V = Array(count: 2 * Int(max) + 1, repeatedValue: -1) // from [0...2*max], it is -max...max in the whitepaper
        
        V[max+1] = 0
        
        for D in 0...max {
            for k in (-D).stride(through: D, by: 2) {
                
                let index = k+max
                
                // if x value for bigger (x-y) V[index-1] is smaller than x value for smaller (x-y) V[index+1]
                // then return smaller (x-y)
                // well, why??
                // It means that y = x - k will be bigger
                // otherwise y = x - k will be smaller
                // What is the conclusion? Hell knows.
                
                
                /*
                 case 1: k == -D: take the furthest going k+1 trace and go greedly down. We take x of the furthest going k+1 path and go greedly down.
                 case 2: k == D: take the furthest going k-d trace and go right. Again, k+1 is unknown so we have to take k-1. What's more k-1 is right most one trace. We add 1 so that we go 1 to the right direction and stay on the same y
                 case 3: -D<k<D: take the rightmost one (biggest x) and if it the previous trace went right go down, otherwise (if it the trace went down) go right
                 */
                
//                let trace = nextTrace(D, k: k, previousX: V.value(at: index-1), nextX: V.value(at: index+1))
//                var x = trace.to.x
//                var y = trace.to.y
                
                let trace = { _ -> Trace in
                    
                    let traceType = nextTraceType(D, k: k, previousX: V.value(at: index-1), nextX: V.value(at: index+1))

                    if  traceType == .Insertion {
                        let x = V[index+1]
                        return Trace(from: Point(x: x, y: x-k-1), to: Point(x: x, y: x-k), D: D)
                    } else {
                        let x = V[index-1]+1
                        return Trace(from: Point(x: x-1, y: x-k), to: Point(x: x, y: x-k), D: D)
                    }
                }()
                
                var x = trace.to.x
                var y = trace.to.y
                
                if (x <= N && y <= M) {
                    traces.append(trace)
                    
                    // keep going as long as they match on diagonal k
                    while x >= 0 && y >= 0 && x < N && y < M {
                        let yIndex = b.startIndex.advancedByInt(y)
                        let xIndex = startIndex.advancedByInt(x)
                        if self[xIndex] == b[yIndex] {
                            x += 1
                            y += 1
                            traces.append(Trace(from: Point(x: x-1, y: y-1), to: Point(x: x, y: y), D: D))
                        } else {
                            break
                        }
                    }
                    
                    V[index] = x
                    
                    if x >= N && y >= M {
                        return traces
                    }
                }
            }
        }
        return []
    }
    
    private func nextTraceType(D: Int, k: Int, previousX: Int?, nextX: Int?) -> TraceType {
        if k == -D {
            return .Insertion
        } else if k != D {
            if let previousX = previousX, nextX = nextX where previousX < nextX {
                return .Insertion
            }
            return .Deletion
        } else {
            return .Deletion
        }
}
    
    public func diff(b: Self) -> Diff {
        return findPath(diffTraces(b), n: Int(self.count.toIntMax()), m: Int(b.count.toIntMax()))
    }
    
    private func findPath(traces: [Trace], n: Int, m: Int) -> Diff {
        
        guard traces.count > 0 else {
            return Diff(elements: [])
        }
        
        var array = [Trace]()
        var item = traces.last!
        array.append(item)
        
        for trace in traces.reverse() {
            if trace.to.x == item.from.x && trace.to.y == item.from.y {
                array.insert(trace, atIndex: 0)
                item = trace
                
                if trace.from == Point(x: 0, y: 0) {
                    break;
                }
            }
        }
        
        return Diff(elements: array
            .flatMap { DiffElement(trace: $0) }
        )
    }
    
}



