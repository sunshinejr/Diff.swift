
import UIKit

struct StringArray: Equatable, CollectionType {

    let elements: [String]
    let key: String
    
    typealias Index = Int
    
    var startIndex: Int {
        return elements.startIndex
    }
    
    var endIndex: Int {
        return elements.endIndex
    }
    
    subscript(i: Int) -> String {
        return elements[i]
    }
    
    internal func index(after i: Int) -> Int {
        return elements.startIndex.advancedBy(i).successor()
    }
}

func ==(fst: StringArray, snd: StringArray) -> Bool {
    return fst.key == snd.key
}

class NestedTableViewController: UITableViewController {

    let items = [
        [
            StringArray(
                elements: [
                    "🌞",
                    "🐩",
                ],
                key: "First"
            ),
            StringArray(
                elements: [
                    "👋🏻",
                    "🎁",
                ],
                key: "Second"
            ),
        ],
        [
            StringArray(
                elements: [
                    "🎁",
                    "👋🏻",
                ],
                key: "Second"
            ),
            StringArray(
                elements: [
                    "🌞",
                    "🐩"
                ],
                key: "First"
            ),
            StringArray(
                elements: [
                    "😊"
                ],
                key: "Third"
            ),
        ],
    ]
    
    var currentConfiguration = 0 {
        didSet {
            tableView.animateRowAndSectionChanges(oldData: items[oldValue], newData: items[currentConfiguration])
        }
    }
    
    private let reuseIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(refresh(_:)))
        self.navigationItem.rightBarButtonItem = addButton
    }
    
    func refresh(sender: AnyObject) {
        currentConfiguration = currentConfiguration == 0 ? 1 : 0;
    }
    
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UILabel()
        view.text = items[currentConfiguration][section].key
        view.sizeToFit()
        return view
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return items[currentConfiguration].count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items[currentConfiguration][section].elements.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.textLabel?.text = items[currentConfiguration][indexPath.section].elements[indexPath.row]
        return cell
    }
}
