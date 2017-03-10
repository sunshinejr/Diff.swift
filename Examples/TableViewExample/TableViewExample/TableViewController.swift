
import UIKit
import Diff

class TableViewController: UITableViewController {

    var objects = [
        [
            "🌞",
            "🐩",
            "👌🏽",
            "🦄",
            "👋🏻",
            "🙇🏽‍♀️",
            "🔥",
        ],
        [
            "🐩",
            "🌞",
            "👌🏽",
            "🙇🏽‍♀️",
            "🔥",
            "👋🏻",
        ]
    ]
    
    
    var currentObjects = 0 {
        didSet {
            tableView.animateRowChanges(
                oldData: objects[oldValue],
                newData: objects[currentObjects],
                deletionAnimation: .Right,
                insertionAnimation: .Right)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let addButton = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self, action: #selector(refresh(_:)))
        self.navigationItem.rightBarButtonItem = addButton
    }

    func refresh(sender: AnyObject) {
        currentObjects = currentObjects == 0 ? 1 : 0;
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects[currentObjects].count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.textLabel?.text = objects[currentObjects][indexPath.row]
        return cell
    }
}
