
/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TodayViewController` class displays the Today view containing the contents of the Today task.
*/

import UIKit
import NotificationCenter
import TasksKit

class TodayViewController: UITableViewController, NCWidgetProviding, TasksControllerDelegate, TaskPresenterDelegate  {
    // MARK: Types
    
    struct TableViewConstants {
        static let baseRowCount = 5
        static let todayRowHeight = 44.0
        
        struct CellIdentifiers {
            static let content = "todayViewCell"
            static let message = "messageCell"
        }
    }
    
    // MARK: Properties
    
    var document: TaskDocument? {
        didSet {
            document?.taskPresenter?.delegate = self
        }
    }

    var taskPresenter: IncompleteTaskItemsPresenter! {
        return document?.taskPresenter as? IncompleteTaskItemsPresenter
    }
    
    var showingAll: Bool = false {
        didSet {
            resetContentSize()
        }
    }
    
    var isTodayAvailable: Bool {
        return document != nil && taskPresenter != nil
    }

    var preferredViewHeight: CGFloat {
        // Determine the total number of items available for presentation.
        let itemCount = isTodayAvailable && !taskPresenter.isEmpty ? taskPresenter.count : 1
        
        /* 
            On first launch only display up to `TableViewConstants.baseRowCount + 1` rows. An additional row
            is used to display the "Show All" row.
        */
        let rowCount = showingAll ? itemCount : min(itemCount, TableViewConstants.baseRowCount + 1)

        return CGFloat(Double(rowCount) * TableViewConstants.todayRowHeight)
    }
    
    var tasksController: TasksController!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = UIColor.clearColor()

        tasksController = AppConfiguration.sharedConfiguration.tasksControllerForCurrentConfigurationWithLastPathComponent(AppConfiguration.localizedTodayDocumentNameAndExtension)
        
        tasksController.delegate = self
        tasksController.startSearching()
        
        resetContentSize()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        document?.closeWithCompletionHandler(nil)
    }
    
    // MARK: NCWidgetProviding
    
    func widgetMarginInsetsForProposedMarginInsets(defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        return UIEdgeInsets(top: defaultMarginInsets.top, left: 27.0, bottom: defaultMarginInsets.bottom, right: defaultMarginInsets.right)
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: (NCUpdateResult -> Void)?) {
        completionHandler?(.NewData)
    }
    
    // MARK: TasksControllerDelegate
    
    func tasksController(_: TasksController, didInsertTaskInfo taskInfo: TaskInfo, atIndex index: Int) {
        // Once we've found the Today task, we'll hand off ownership of taskening to udpates to the task presenter.
        tasksController.stopSearching()
        
        tasksController = nil
        
        // Update the Today widget with the Today task info.
        processTaskInfoAsTodayDocument(taskInfo)
    }

    // MARK: UITableViewDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !isTodayAvailable {
            // Make sure to allow for a row to note that the widget is unavailable.
            return 1
        }
        
        if (self.taskPresenter.isEmpty) {
            // Make sure to allow for a row to note that no incomplete items remain.
            return 1
        }
        
        return showingAll ? taskPresenter.count : min(taskPresenter.count, TableViewConstants.baseRowCount + 1)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let taskPresenter = taskPresenter {
            if taskPresenter.isEmpty {
                let cell = tableView.dequeueReusableCellWithIdentifier(TableViewConstants.CellIdentifiers.message, forIndexPath: indexPath) as! UITableViewCell
                
                cell.textLabel!.text = NSLocalizedString("No incomplete items in today's task.", comment: "")
                
                return cell
            }
            else {
                let itemCount = taskPresenter.count
                
                /**
                    Check to determine what to show at the row at index `TableViewConstants.baseRowCount`. If not
                    showing all rows (explicitly) and the item count is less than `TableViewConstants.baseRowCount` + 1
                    diplay a message cell allowing the user to disclose all rows.
                */
                if (!showingAll && indexPath.row == TableViewConstants.baseRowCount && itemCount != TableViewConstants.baseRowCount + 1) {
                    let cell = tableView.dequeueReusableCellWithIdentifier(TableViewConstants.CellIdentifiers.message, forIndexPath: indexPath) as! UITableViewCell
                    
                    cell.textLabel!.text = NSLocalizedString("Show All...", comment: "")
                    
                    return cell
                }
                else {
                    let checkBoxCell = tableView.dequeueReusableCellWithIdentifier(TableViewConstants.CellIdentifiers.content, forIndexPath: indexPath) as! CheckBoxCell
                    
                    configureCheckBoxCell(checkBoxCell, forTaskItem: taskPresenter.presentedTaskItems[indexPath.row])
                    
                    return checkBoxCell
                }
            }
        }
        else {
            let cell = tableView.dequeueReusableCellWithIdentifier(TableViewConstants.CellIdentifiers.message, forIndexPath: indexPath) as! UITableViewCell
            
            cell.textLabel!.text = NSLocalizedString("Tasks's Today widget is currently unavailable.", comment: "")
            
            return cell
        }
    }
    
    func configureCheckBoxCell(checkBoxCell: CheckBoxCell, forTaskItem taskItem: TaskItem) {
        checkBoxCell.checkBox.tintColor = taskPresenter.color.colorValue
        checkBoxCell.checkBox.isChecked = taskItem.isComplete
        checkBoxCell.checkBox.hidden = false

        checkBoxCell.label.text = taskItem.text

        checkBoxCell.label.textColor = taskItem.isComplete ? UIColor.lightGrayColor() : UIColor.whiteColor()
    }
    
    // MARK: UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // Show all of the cells if the user taps the "Show All..." row.
        if isTodayAvailable && !showingAll && indexPath.row == TableViewConstants.baseRowCount {
            showingAll = true
            
            tableView.beginUpdates()
            
            let indexPathForRemoval = NSIndexPath(forRow: TableViewConstants.baseRowCount, inSection: 0)
            tableView.deleteRowsAtIndexPaths([indexPathForRemoval], withRowAnimation: .Fade)
            
            let insertedIndexPathRange = TableViewConstants.baseRowCount..<taskPresenter.count
            var insertedIndexPaths = insertedIndexPathRange.map { NSIndexPath(forRow: $0, inSection: 0) }
            
            tableView.insertRowsAtIndexPaths(insertedIndexPaths, withRowAnimation: .Fade)
            
            tableView.endUpdates()
            
            return
        }
        
        // Construct a URL with the tasker scheme and the file path of the document.
        let urlComponents = NSURLComponents()
        urlComponents.scheme = AppConfiguration.TasksScheme.name
        urlComponents.path = document!.fileURL.path
        
        // Add a query item to encode the color associated with the task.
        let colorQueryValue = "\(taskPresenter.color.rawValue)"
        let colorQueryItem = NSURLQueryItem(name: AppConfiguration.TasksScheme.colorQueryKey, value: colorQueryValue)
        urlComponents.queryItems = [colorQueryItem]

        extensionContext?.openURL(urlComponents.URL!, completionHandler: nil)
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        cell.layer.backgroundColor = UIColor.clearColor().CGColor
    }

    // MARK: IBActions
    
    @IBAction func checkBoxTapped(sender: CheckBox) {
        let indexPath = indexPathForView(sender)
        
        let item = taskPresenter.presentedTaskItems[indexPath.row]
        taskPresenter.toggleTaskItem(item)
    }
    
    // MARK: TaskPresenterDelegate
    
    func taskPresenterDidRefreshCompleteLayout(taskPresenter: TaskPresenterType) {
        /**
            Note when we reload the data, the color of the task will automatically
            change because the task's color is only shown in each task item in the
            iOS Today widget.
        */
        tableView.reloadData()
    }

    func taskPresenterWillChangeTaskLayout(_: TaskPresenterType, isInitialLayout: Bool) {
        tableView.beginUpdates()
    }

    func taskPresenter(_: TaskPresenterType, didInsertTaskItem taskItem: TaskItem, atIndex index: Int) {
        let indexPaths = [NSIndexPath(forRow: index, inSection: 0)]
        
        // Hide the "No items in task" row.
        if index == 0 && taskPresenter.count == 1 {
            tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        }

        tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func taskPresenter(_: TaskPresenterType, didRemoveTaskItem taskItem: TaskItem, atIndex index: Int) {
        let indexPaths = [NSIndexPath(forRow: index, inSection: 0)]
        
        tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        
        // Show the "No items in task" row.
        if index == 0 && taskPresenter.isEmpty {
            tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        }
    }
    
    func taskPresenter(_: TaskPresenterType, didUpdateTaskItem taskItem: TaskItem, atIndex index: Int) {
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        if let checkBoxCell = tableView.cellForRowAtIndexPath(indexPath) as? CheckBoxCell {
            configureCheckBoxCell(checkBoxCell, forTaskItem: taskPresenter.presentedTaskItems[indexPath.row])
        }
    }
    
    func taskPresenter(_: TaskPresenterType, didMoveTaskItem taskItem: TaskItem, fromIndex: Int, toIndex: Int) {
        let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: 0)
        
        let toIndexPath = NSIndexPath(forRow: toIndex, inSection: 0)
        
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }
    
    func taskPresenter(_: TaskPresenterType, didUpdateTaskColorWithColor color: Task.Color) {
        for (idx, taskItem) in enumerate(taskPresenter.presentedTaskItems) {
            let indexPath = NSIndexPath(forRow: idx, inSection: 0)

            if let checkBoxCell = tableView.cellForRowAtIndexPath(indexPath) as? CheckBoxCell {
                checkBoxCell.checkBox.tintColor = color.colorValue
            }
        }
    }
    
    func taskPresenterDidChangeTaskLayout(taskPresenter: TaskPresenterType, isInitialLayout: Bool) {
        resetContentSize()
        
        tableView.endUpdates()

        if !isInitialLayout {
            document!.updateChangeCount(.Done)
        }
    }
    
    // MARK: Convenience
    
    func processTaskInfoAsTodayDocument(taskInfo: TaskInfo) {
        // Ignore any updates if we already have the Today document.
        if document != nil { return }
        
        document = TaskDocument(fileURL: taskInfo.URL, taskPresenter: IncompleteTaskItemsPresenter())
        
        document!.openWithCompletionHandler { success in
            if !success {
                println("Couldn't open document: \(self.document?.fileURL).")
                
                return
            }
            
            self.resetContentSize()
        }
    }
    
    func indexPathForView(view: UIView) -> NSIndexPath {
        let viewOrigin = view.bounds.origin
        
        let viewLocation = tableView.convertPoint(viewOrigin, fromView: view)
        
        return tableView.indexPathForRowAtPoint(viewLocation)!
    }
    
    func resetContentSize() {
        preferredContentSize.height = preferredViewHeight
    }
}
