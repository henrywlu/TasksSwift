/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TasksController` and `TasksControllerDelegate` infrastructure provide a mechanism for other objects within the application to be notified of inserts, removes, and updates to `TaskInfo` objects. In addition, it also provides a way for parts of the application to present errors that occured when creating or removing tasks.
*/

import Foundation

/**
    The `TasksControllerDelegate` protocol enables a `TasksController` object to notify other objects of changes
    to available `TaskInfo` objects. This includes "will change content" events, "did change content"
    events, inserts, removes, updates, and errors. Note that the `TasksController` can call these methods
    on an aribitrary queue. If the implementation in these methods require UI manipulations, you should
    respond to the changes on the main queue.
*/
@objc public protocol TasksControllerDelegate {
    /**
        Notifies the receiver of this method that the tasks controller will change it's contents in
        some form. This method is *always* called before any insert, remove, or update is received.
        In this method, you should prepare your UI for making any changes related to the changes
        that you will need to reflect once they are received. For example, if you have a table view
        in your UI that needs to respond to changes to a newly inserted `TaskInfo` object, you would
        want to call your table view's `beginUpdates()` method. Once all of the updates are performed,
        your `tasksControllerDidChangeContent(_:)` method will be called. This is where you would to call
        your table view's `endUpdates()` method.
    
        :param: tasksController The `TasksController` instance that will change its content.
    */
    optional func tasksControllerWillChangeContent(tasksController: TasksController)

    /**
        Notifies the receiver of this method that the tasks controller is tracking a new `TaskInfo`
        object. Receivers of this method should update their UI accordingly.
        
        :param: tasksController The `TasksController` instance that inserted the new `TaskInfo`.
        :param: taskInfo The new `TaskInfo` object that has been inserted at `index`.
        :param: index The index that `taskInfo` was inserted at.
    */
    optional func tasksController(tasksController: TasksController, didInsertTaskInfo taskInfo: TaskInfo, atIndex index: Int)

    /**
        Notifies the receiver of this method that the tasks controller received a message that `taskInfo`
        has updated its content. Receivers of this method should update their UI accordingly.
        
        :param: tasksController The `TasksController` instance that was notified that `taskInfo` has been updated.
        :param: taskInfo The `TaskInfo` object that has been updated.
        :param: index The index of `taskInfo`, the updated `TaskInfo`.
    */
    optional func tasksController(tasksController: TasksController, didRemoveTaskInfo taskInfo: TaskInfo, atIndex index: Int)

    /**
        Notifies the receiver of this method that the tasks controller is no longer tracking `taskInfo`.
        Receivers of this method should update their UI accordingly.
        
        :param: tasksController The `TasksController` instance that removed `taskInfo`.
        :param: taskInfo The removed `TaskInfo` object.
        :param: index The index that `taskInfo` was removed at.
    */
    optional func tasksController(tasksController: TasksController, didUpdateTaskInfo taskInfo: TaskInfo, atIndex index: Int)

    /**
        Notifies the receiver of this method that the tasks controller did change it's contents in
        some form. This method is *always* called after any insert, remove, or update is received.
        In this method, you should finish off changes to your UI that were related to any insert, remove,
        or update. For an example of how you might handle a "did change" contents call, see
        the discussion for `tasksControllerWillChangeContent(_:)`.

        :param: tasksController The `TasksController` instance that did change its content.
    */
    optional func tasksControllerDidChangeContent(tasksController: TasksController)

    /**
        Notifies the receiver of this method that an error occured when creating a new `TaskInfo` object.
        In implementing this method, you should present the error to the user. Do not rely on the
        `TaskInfo` instance to be valid since an error occured in creating the object.

        :param: tasksController The `TasksController` that is notifying that a failure occured.
        :param: taskInfo The `TaskInfo` that represents the task that couldn't be created.
        :param: error The error that occured.
    */
    optional func tasksController(tasksController: TasksController, didFailCreatingTaskInfo taskInfo: TaskInfo, withError error: NSError)

    /**
        Notifies the receiver of this method that an error occured when removing an existing `TaskInfo`
        object. In implementing this method, you should present the error to the user.

        :param: tasksController The `TasksController` that is notifying that a failure occured.
        :param: taskInfo The `TaskInfo` that represents the task that couldn't be removed.
        :param: error The error that occured.
    */
    optional func tasksController(tasksController: TasksController, didFailRemovingTaskInfo taskInfo: TaskInfo, withError error: NSError)
}

/**
    The `TasksController` class is responsible for tracking `TaskInfo` objects that are found through
    tasks controller's `TaskCoordinator` object. `TaskCoordinator` objects are responsible for notifying
    the tasks controller of inserts, removes, updates, and errors when interacting with a task's URL.
    Since the work of searching, removing, inserting, and updating `TaskInfo` objects is done by the task
    controller's coordinator, the tasks controller serves as a way to avoid the need to interact with a single
    `TaskCoordinator` directly throughout the application. It also allows the rest of the application
    to deal with `TaskInfo` objects rather than dealing with their `NSURL` instances directly. In essence,
    the work of a tasks controller is to "front" its current coordinator. All changes that the coordinator
    relays to the `TasksController` object will be relayed to the tasks controller's delegate. This ability to
    front another object is particularly useful when the underlying coordinator changes. As an example,
    this could happen when the user changes their storage option from using local documents to using
    cloud documents. If the coordinator property of the tasks controller changes, other objects throughout
    the application are unaffected since the tasks controller will notify them of the appropriate
    changes (removes, inserts, etc.).
*/
final public class TasksController: NSObject, TaskCoordinatorDelegate {
    // MARK: Properties

    /// The `TasksController`'s delegate who is responsible for responding to `TasksController` updates.
    public weak var delegate: TasksControllerDelegate?
    
    /// :returns: The number of tracked `TaskInfo` objects.
    public var count: Int {
        var taskInfosCount: Int!

        dispatch_sync(taskInfoQueue) {
            taskInfosCount = self.taskInfos.count
        }

        return taskInfosCount
    }

    /// The current `TaskCoordinator` that the tasks controller manages.
    public var taskCoordinator: TaskCoordinator {
        didSet(oldTaskCoordinator) {
            oldTaskCoordinator.stopQuery()
            
            // Map the taskInfo objects protected by taskInfoQueue.
            var allURLs: [NSURL]!
            dispatch_sync(taskInfoQueue) {
                allURLs = self.taskInfos.map { $0.URL }
            }
            self.processContentChanges(insertedURLs: [], removedURLs: allURLs, updatedURLs: [])
            
            self.taskCoordinator.delegate = self
            oldTaskCoordinator.delegate = nil
            
            self.taskCoordinator.startQuery()
        }
    }

    /**
        The `TaskInfo` objects that are cached by the `TasksController` to allow for users of the
        `TasksController` class to easily subscript the controller.
    */
    private var taskInfos = [TaskInfo]()
    
    /**
        :returns: A private, local queue to the `TasksController` that is used to perform updates on
                 `taskInfos`.
    */
    private let taskInfoQueue = dispatch_queue_create("com.locust123.tasker.taskscontroller", DISPATCH_QUEUE_SERIAL)
    
    /**
        The sort predicate that's set in initialization. The sort predicate ensures a strict sort ordering
        of the `taskInfos` array. If `sortPredicate` is nil, the sort order is ignored.
    */
    private let sortPredicate: ((lhs: TaskInfo, rhs: TaskInfo) -> Bool)?
    
    /// The queue on which the `TasksController` object invokes delegate messages.
    private var delegateQueue: NSOperationQueue

    // MARK: Initializers
    
    /**
        Initializes a `TasksController` instance with an initial `TaskCoordinator` object and a sort
        predicate (if any). If no sort predicate is provided, the controller ignores sort order.

        :param: taskCoordinator The `TasksController`'s initial `TaskCoordinator`.
        :param: delegateQueue The queue on which the `TasksController` object invokes delegate messages.
        :param: sortPredicate The predicate that determines the strict sort ordering of the `taskInfos` array.
    */
    public init(taskCoordinator: TaskCoordinator, delegateQueue: NSOperationQueue, sortPredicate: ((lhs: TaskInfo, rhs: TaskInfo) -> Bool)? = nil) {
        self.taskCoordinator = taskCoordinator
        self.delegateQueue = delegateQueue
        self.sortPredicate = sortPredicate

        super.init()

        self.taskCoordinator.delegate = self
    }
    
    // MARK: Subscripts
    
    /**
        :returns: The `TaskInfo` instance at a specific index. This method traps if the index is out
                  of bounds.
    */
    public subscript(idx: Int) -> TaskInfo {
        // Fetch the appropriate task info protected by `taskInfoQueue`.
        var taskInfo: TaskInfo!

        dispatch_sync(taskInfoQueue) {
            taskInfo = self.taskInfos[idx]
        }

        return taskInfo
    }
    
    // MARK: Convenience
    
    /**
        Begin taskening for changes to the tracked `TaskInfo` objects. This is managed by the `taskCoordinator`
        object. Be sure to balance each call to `startSearching()` with a call to `stopSearching()`.
     */
    public func startSearching() {
        taskCoordinator.startQuery()
    }
    
    /**
        Stop taskening for changes to the tracked `TaskInfo` objects. This is managed by the `taskCoordinator`
        object. Each call to `startSearching()` should be balanced with a call to this method.
     */
    public func stopSearching() {
        taskCoordinator.stopQuery()
    }
    
    // MARK: Inserting / Removing / Managing / Updating `TaskInfo` Objects
    
    /**
        Removes `taskInfo` from the tracked `TaskInfo` instances. This method forwards the remove
        operation directly to the task coordinator. The operation can be performed asynchronously
        so long as the underlying `TaskCoordinator` instance sends the `TasksController` the correct
        delegate messages: either a `taskCoordinatorDidUpdateContents(insertedURLs:removedURLs:updatedURLs:)`
        call with the removed `TaskInfo` object, or with an error callback.
    
        :param: taskInfo The `TaskInfo` to remove from the task of tracked `TaskInfo` instances.
    */
    public func removeTaskInfo(taskInfo: TaskInfo) {
        taskCoordinator.removeTaskAtURL(taskInfo.URL)
    }
    
    /**
        Attempts to create `TaskInfo` representing `task` with the given name. If the method is succesful,
        the tasks controller adds it to the task of tracked `TaskInfo` instances. This method forwards
        the create operation directly to the task coordinator. The operation can be performed asynchronously
        so long as the underlying `TaskCoordinator` instance sends the `TasksController` the correct
        delegate messages: either a `taskCoordinatorDidUpdateContents(insertedURLs:removedURLs:updatedURLs:)`
        call with the newly inserted `TaskInfo`, or with an error callback.

        Note: it's important that before calling this method, a call to `canCreateTaskWithName(_:)`
        is performed to make sure that the name is a valid task name. Doing so will decrease the errors
        that you see when you actually create a task.

        :param: task The `Task` object that should be used to save the initial task.
        :param: name The name of the new task.
    */
    public func createTaskInfoForTask(task: Task, withName name: String) {
        taskCoordinator.createURLForTask(task, withName: name)
    }
    
    /**
        Determines whether or not a task can be created with a given name. This method delegates to
        `taskCoordinator` to actually check to see if the task can be created with the given name. This
        method should be called before `createTaskInfoForTask(_:withName:)` is called to ensure to minimize
        the number of errors that can occur when creating a task.

        :param: name The name to check to see if it's valid or not.
        
        :returns: `true` if the task can be created with the given name, `false` otherwise.
    */
    public func canCreateTaskInfoWithName(name: String) -> Bool {
        return taskCoordinator.canCreateTaskWithName(name)
    }
    
    /**
        Lets the `TasksController` know that `taskInfo` has been udpdated. Once the change is reflected
        in `taskInfos` array, a didUpdateTaskInfo message is sent.
        
        :param: taskInfo The `TaskInfo` instance that has new content.
    */
    public func setTaskInfoHasNewContents(taskInfo: TaskInfo) {
        dispatch_async(taskInfoQueue) {
            // Remove the old task info and replace it with the new one.
            let indexOfTaskInfo = find(self.taskInfos, taskInfo)!

            self.taskInfos[indexOfTaskInfo] = taskInfo

            if let delegate = self.delegate {
                self.delegateQueue.addOperationWithBlock {
                    delegate.tasksControllerWillChangeContent?(self)
                    delegate.tasksController?(self, didUpdateTaskInfo: taskInfo, atIndex: indexOfTaskInfo)
                    delegate.tasksControllerDidChangeContent?(self)
                }
            }
        }
    }

    // MARK: TaskCoordinatorDelegate
    
    /**
        Receives changes from `taskCoordinator` about inserted, removed, and/or updated `TaskInfo`
        objects. When any of these changes occurs, these changes are processed and forwarded along
        to the `TasksController` object's delegate. This implementation determines where each of these
        URLs were located so that the controller can forward the new / removed / updated indexes
        as well. For more information about this method, see the method description for this method
        in the `TaskCoordinator` class.

        :param: insertedURLs The `NSURL` instances that should be tracekd.
        :param: removedURLs The `NSURL` instances that should be untracked.
        :param: updatedURLs The `NSURL` instances that have had their underlying model updated.
    */
    public func taskCoordinatorDidUpdateContents(#insertedURLs: [NSURL], removedURLs: [NSURL], updatedURLs: [NSURL]) {
        processContentChanges(insertedURLs: insertedURLs, removedURLs: removedURLs, updatedURLs: updatedURLs)
    }
    
    /**
        Forwards the "create" error from the `TaskCoordinator` to the `TasksControllerDelegate`. For more
        information about when this method can be called, see the description for this method in the
        `TaskCoordinatorDelegate` protocol description.
        
        :param: URL The `NSURL` instances that was failed to be created.
        :param: error The error the describes why the create failed.
    */
    public func taskCoordinatorDidFailCreatingTaskAtURL(URL: NSURL, withError error: NSError) {
        let taskInfo = TaskInfo(URL: URL)
        
        delegateQueue.addOperationWithBlock {
            self.delegate?.tasksController?(self, didFailCreatingTaskInfo: taskInfo, withError: error)
            
            return
        }
    }
    
    /**
        Forwards the "remove" error from the `TaskCoordinator` to the `TasksControllerDelegate`. For
        more information about when this method can be called, see the description for this method in
        the `TaskCoordinatorDelegate` protocol description.
        
        :param: URL The `NSURL` instance that failed to be removed
        :param: error The error that describes why the remove failed.
    */
    public func taskCoordinatorDidFailRemovingTaskAtURL(URL: NSURL, withError error: NSError) {
        let taskInfo = TaskInfo(URL: URL)
        
        delegateQueue.addOperationWithBlock {
            self.delegate?.tasksController?(self, didFailRemovingTaskInfo: taskInfo, withError: error)
            
            return
        }
    }
    
    // MARK: Change Processing
    
    /**
        Processes changes to the `TasksController` object's `TaskInfo` collection. This implementation
        performs the updates and determines where each of these URLs were located so that the controller can 
        forward the new / removed / updated indexes as well.
    
        :param: insertedURLs The `NSURL` instances that are newly tracked.
        :param: removedURLs The `NSURL` instances that have just been untracked.
        :param: updatedURLs The `NSURL` instances that have had their underlying model updated.
    */
    private func processContentChanges(#insertedURLs: [NSURL], removedURLs: [NSURL], updatedURLs: [NSURL]) {
        let insertedTaskInfos = insertedURLs.map { TaskInfo(URL: $0) }
        let removedTaskInfos = removedURLs.map { TaskInfo(URL: $0) }
        let updatedTaskInfos = updatedURLs.map { TaskInfo(URL: $0) }
        
        delegateQueue.addOperationWithBlock {
            // Filter out all tasks that are already included in the tracked tasks.
            var trackedRemovedTaskInfos: [TaskInfo]!
            var untrackedInsertedTaskInfos: [TaskInfo]!
            
            dispatch_sync(self.taskInfoQueue) {
                trackedRemovedTaskInfos = removedTaskInfos.filter { contains(self.taskInfos, $0) }
                untrackedInsertedTaskInfos = insertedTaskInfos.filter { !contains(self.taskInfos, $0) }
            }
            
            if untrackedInsertedTaskInfos.isEmpty && trackedRemovedTaskInfos.isEmpty && updatedTaskInfos.isEmpty {
                return
            }
            
            self.delegate?.tasksControllerWillChangeContent?(self)
            
            // Remove
            for trackedRemovedTaskInfo in trackedRemovedTaskInfos {
                var trackedRemovedTaskInfoIndex: Int!
                
                dispatch_sync(self.taskInfoQueue) {
                    trackedRemovedTaskInfoIndex = find(self.taskInfos, trackedRemovedTaskInfo)!
                    
                    self.taskInfos.removeAtIndex(trackedRemovedTaskInfoIndex)
                }
                
                self.delegate?.tasksController?(self, didRemoveTaskInfo: trackedRemovedTaskInfo, atIndex: trackedRemovedTaskInfoIndex)
            }

            // Sort the untracked inserted task infos
            if let sortPredicate = self.sortPredicate {
                untrackedInsertedTaskInfos.sort(sortPredicate)
            }
            
            // Insert
            for untrackedInsertedTaskInfo in untrackedInsertedTaskInfos {
                var untrackedInsertedTaskInfoIndex: Int!
                
                dispatch_sync(self.taskInfoQueue) {
                    self.taskInfos += [untrackedInsertedTaskInfo]
                    
                    if let sortPredicate = self.sortPredicate {
                        self.taskInfos.sort(sortPredicate)
                    }
                    
                    untrackedInsertedTaskInfoIndex = find(self.taskInfos, untrackedInsertedTaskInfo)!
                }
                
                self.delegate?.tasksController?(self, didInsertTaskInfo: untrackedInsertedTaskInfo, atIndex: untrackedInsertedTaskInfoIndex)
            }
            
            // Update
            for updatedTaskInfo in updatedTaskInfos {
                var updatedTaskInfoIndex: Int?
                
                dispatch_sync(self.taskInfoQueue) {
                    updatedTaskInfoIndex = find(self.taskInfos, updatedTaskInfo)
                    
                    // Track the new task info instead of the old one.
                    if let updatedTaskInfoIndex = updatedTaskInfoIndex {
                        self.taskInfos[updatedTaskInfoIndex] = updatedTaskInfo
                    }
                }
                
                if let updatedTaskInfoIndex = updatedTaskInfoIndex {
                    self.delegate?.tasksController?(self, didUpdateTaskInfo: updatedTaskInfo, atIndex: updatedTaskInfoIndex)
                }
            }
            
            self.delegate?.tasksControllerDidChangeContent?(self)
        }
    }
}
