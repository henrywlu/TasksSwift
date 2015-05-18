//
//  TaskDocumentsViewController.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//
//  Abstract:
//    The `TaskDocumentsViewController` displays a task of available documents for users to open.


import UIKit
import TasksKit

class TaskDocumentsViewController: UITableViewController, TasksControllerDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate {
    // MARK: Types

    struct MainStoryboard {
        struct ViewControllerIdentifiers {
            static let taskViewController = "taskViewController"
            static let taskViewNavigationController = "taskViewNavigationController"
        }
        
        struct TableViewCellIdentifiers {
            static let taskDocumentCell = "taskDocumentCell"
        }
        
        struct SegueIdentifiers {
            static let newTaskDocument = "newTaskDocument"
            static let showTaskDocument = "showTaskDocument"
            static let showTaskDocumentFromUserActivity = "showTaskDocumentFromUserActivity"
        }
    }
    
    // MARK: Properties

    var tasksController: TasksController! {
        didSet {
            tasksController.delegate = self
        }
    }
    
    private var pendingLaunchContext: AppLaunchContext?

    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = 44.0
        
        navigationController?.navigationBar.titleTextAttributes = [
            NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline),
            NSForegroundColorAttributeName: Task.Color.Gray.colorValue
        ]
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleContentSizeCategoryDidChangeNotification:", name: UIContentSizeCategoryDidChangeNotification, object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.titleTextAttributes = [
            NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline),
            NSForegroundColorAttributeName: Task.Color.Gray.colorValue
        ]
        
        let grayTaskColor = Task.Color.Gray.colorValue
        navigationController?.navigationBar.tintColor = grayTaskColor
        navigationController?.toolbar?.tintColor = grayTaskColor
        tableView.tintColor = grayTaskColor
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let launchContext = pendingLaunchContext {
            configureViewControllerWithLaunchContext(launchContext)
        }
        
        pendingLaunchContext = nil
    }
    
    // MARK: Lifetime
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIContentSizeCategoryDidChangeNotification, object: nil)
    }
    
    // MARK: UIResponder
    
    override func restoreUserActivityState(activity: NSUserActivity) {
        // Obtain an app launch context from the provided activity and configure the view controller with it.
        let launchContext = AppLaunchContext(userActivity: activity)
        
        configureViewControllerWithLaunchContext(launchContext)
    }
    
    // MARK: IBActions

    /**
        Note that the document picker requires that code signing, entitlements, and provisioning for
        the project have been configured before you run Tasks. If you run the app without configuring
        entitlements correctly, an exception when this method is invoked (i.e. when the "+" button is
        clicked).
    */
    @IBAction func pickDocument(barButtonItem: UIBarButtonItem) {
        let documentMenu = UIDocumentMenuViewController(documentTypes: [AppConfiguration.taskerUTI], inMode: .Open)
        documentMenu.delegate = self

        let newDocumentTitle = NSLocalizedString("New Task", comment: "")
        documentMenu.addOptionWithTitle(newDocumentTitle, image: nil, order: .First) {
            // Show the NewTaskDocumentController.
            self.performSegueWithIdentifier(MainStoryboard.SegueIdentifiers.newTaskDocument, sender: self)
        }
        
        documentMenu.modalPresentationStyle = .Popover
        documentMenu.popoverPresentationController?.barButtonItem = barButtonItem
        
        presentViewController(documentMenu, animated: true, completion: nil)
    }
    
    // MARK: UIDocumentMenuDelegate
    
    func documentMenu(documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self

        presentViewController(documentPicker, animated: true, completion: nil)
    }
    
    func documentMenuWasCancelled(documentMenu: UIDocumentMenuViewController) {
        /**
            The user cancelled interacting with the document menu. In your own app, you may want to
            handle this with other logic.
        */
    }
    
    // MARK: UIPickerViewDelegate
    
    func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL) {
        // The user selected the document and it should be picked up by the `TasksController`.
    }

    func documentPickerWasCancelled(controller: UIDocumentPickerViewController) {
        /**
            The user cancelled interacting with the document picker. In your own app, you may want to
            handle this with other logic.
        */
    }
    
    // MARK: TasksControllerDelegate
    
    func tasksControllerWillChangeContent(tasksController: TasksController) {
        tableView.beginUpdates()
    }
    
    func tasksController(tasksController: TasksController, didInsertTaskInfo taskInfo: TaskInfo, atIndex index: Int) {
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func tasksController(tasksController: TasksController, didRemoveTaskInfo taskInfo: TaskInfo, atIndex index: Int) {
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func tasksController(tasksController: TasksController, didUpdateTaskInfo taskInfo: TaskInfo, atIndex index: Int) {
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        let cell = tableView.cellForRowAtIndexPath(indexPath) as! TaskCell
        cell.label.text = taskInfo.name
        
        taskInfo.fetchInfoWithCompletionHandler {
            /* 
                The fetchInfoWithCompletionHandler(_:) method calls its completion handler on a background
                queue, dispatch back to the main queue to make UI updates.
            */
            dispatch_async(dispatch_get_main_queue()) {
                // Make sure that the task info is still visible once the color has been fetched.
                let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows() as! [NSIndexPath]

                if contains(indexPathsForVisibleRows, indexPath) {
                    cell.taskColorView.backgroundColor = taskInfo.color!.colorValue
                }
            }
        }
    }
    
    func tasksControllerDidChangeContent(tasksController: TasksController) {
        tableView.endUpdates()
    }
    
    func tasksController(tasksController: TasksController, didFailCreatingTaskInfo taskInfo: TaskInfo, withError error: NSError) {
        let title = NSLocalizedString("Failed to Create Task", comment: "")
        let message = error.localizedDescription
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let errorOutController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let action = UIAlertAction(title: okActionTitle, style: .Cancel, handler: nil)
        errorOutController.addAction(action)
        
        presentViewController(errorOutController, animated: true, completion: nil)
    }
    
    func tasksController(tasksController: TasksController, didFailRemovingTaskInfo taskInfo: TaskInfo, withError error: NSError) {
        let title = NSLocalizedString("Failed to Delete Task", comment: "")
        let message = error.localizedFailureReason
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let errorOutController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let action = UIAlertAction(title: okActionTitle, style: .Cancel, handler: nil)
        errorOutController.addAction(action)
        
        presentViewController(errorOutController, animated: true, completion: nil)
    }
    
    // MARK: UITableViewDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // If the controller is nil, return no rows. Otherwise return the number of total rows.
        return tasksController?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCellWithIdentifier(MainStoryboard.TableViewCellIdentifiers.taskDocumentCell, forIndexPath: indexPath) as! TaskCell
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        switch cell {
            case let taskCell as TaskCell:
                let taskInfo = tasksController[indexPath.row]
                
                taskCell.label.text = taskInfo.name
                taskCell.label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
                taskCell.taskColorView.backgroundColor = UIColor.clearColor()
                
                // Once the task info has been loaded, update the associated cell's properties.
                taskInfo.fetchInfoWithCompletionHandler {
                    /*
                        The fetchInfoWithCompletionHandler(_:) method calls its completion handler on a background
                        queue, dispatch back to the main queue to make UI updates.
                    */
                    dispatch_async(dispatch_get_main_queue()) {
                        // Make sure that the task info is still visible once the color has been fetched.
                        let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows() as! [NSIndexPath]
                        
                        if contains(indexPathsForVisibleRows, indexPath) {
                            taskCell.taskColorView.backgroundColor = taskInfo.color!.colorValue
                        }
                    }
                }
            default:
                fatalError("Attempting to configure an unknown or unsupported cell type in TaskDocumentViewController.")
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    // MARK: UIStoryboardSegue Handling

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == MainStoryboard.SegueIdentifiers.newTaskDocument {
            let newTaskDocumentController = segue.destinationViewController as! NewTaskDocumentController

            newTaskDocumentController.tasksController = tasksController
        }
        else if segue.identifier == MainStoryboard.SegueIdentifiers.showTaskDocument || segue.identifier == MainStoryboard.SegueIdentifiers.showTaskDocumentFromUserActivity {
            let taskNavigationController = segue.destinationViewController as! UINavigationController
            let taskViewController = taskNavigationController.topViewController as! TaskViewController
            taskViewController.tasksController = tasksController
            
            taskViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
            taskViewController.navigationItem.leftItemsSupplementBackButton = true
            
            if segue.identifier == MainStoryboard.SegueIdentifiers.showTaskDocument {
                let indexPath = tableView.indexPathForSelectedRow()!
                taskViewController.configureWithTaskInfo(tasksController[indexPath.row])
            }
            else if segue.identifier == MainStoryboard.SegueIdentifiers.showTaskDocumentFromUserActivity {
                let userActivityTaskInfo = sender as! TaskInfo
                taskViewController.configureWithTaskInfo(userActivityTaskInfo)
            }
        }
    }

    // MARK: Notifications
    
    func handleContentSizeCategoryDidChangeNotification(_: NSNotification) {
        tableView.setNeedsLayout()
    }
    
    // MARK: Convenience
    
    func configureViewControllerWithLaunchContext(launchContext: AppLaunchContext) {
        /**
            If there is a task currently displayed; pop to the root view controller (this controller) and
            continue configuration from there. Otherwise, configure the view controller directly.
        */
        if navigationController?.topViewController is UINavigationController {
            navigationController?.popToRootViewControllerAnimated(false)
            pendingLaunchContext = launchContext
            return
        }
        
        let taskInfo = TaskInfo(URL: launchContext.taskURL)
        taskInfo.color = launchContext.taskColor
        
        performSegueWithIdentifier(MainStoryboard.SegueIdentifiers.showTaskDocumentFromUserActivity, sender: taskInfo)
    }
    
    
}
