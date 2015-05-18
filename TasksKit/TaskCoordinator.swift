/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TaskCoordinator` and `TaskCoordinatorDelegate` protocols provide the infrastructure to send updates to a `TasksController` object, abstracting away the need to worry about the underlying storage mechanism.
*/

import Foundation

/**
    An instance that conforms to the `TaskCoordinator` protocol is responsible for implementing
    entry points in order to communicate with a `TaskCoordinatorDelegate`. In the case of Tasks, this
    is the `TasksController` instance. The main responsibility of a `TaskCoordinator` is to track
    different `NSURL` instances that are important. For example, in Tasks there are two types of
    storage mechanisms: local and iCloud based storage. The iCloud coordinator is responsible for making
    sure that the `TasksController` knows about the current set of iCloud documents that are available.
    
    There are also other responsibilities that a `TaskCoordinator` must have that are specific to the
    underlying storage mechanism of the coordinator. A `TaskCoordinator` determines whether or not a
    new task can be created with a specific name, it removes URLs tied to a specific task, and it is
    also responsible for taskening for updates to any changes that occur at a specific URL (e.g. a
    task document is updated on another device, etc.).

    Instances of `TaskCoordinator` can search for URLs in an asynchronous way. When a new `NSURL`
    instance is found, removed, or updated, the `TaskCoordinator` instance must make its delegate aware
    of the updates. If a failure occured in removing or creating an `NSURL` for a given task, it must
    make its delegate aware by calling one of the appropriate error methods defined in the
    `TaskCoordinatorDelegate` protocol.
*/
@objc public protocol TaskCoordinator {
    // MARK: Properties
    
    /**
        The delegate responsible for handling inserts, removes, updates, and errors when the
        `TaskCoordinator` instance determines such events occured.
    */
    weak var delegate: TaskCoordinatorDelegate? { get set }
    
    // MARK: Methods
    
    /**
        Starts observing changes to the important `NSURL` instances. For example, if a `TaskCoordinator`
        conforming class has the responsibility to manage iCloud documents, the `startQuery()` method
        would start observing an `NSMetadataQuery`. This method is called on the `TaskCoordinator` once
        the coordinator is set on the `TasksController`.
    */
    func startQuery()
    
    /**
        Stops observing changes to the important `NSURL` instances. For example, if a `TaskCoordinator`
        conforming class has the responsibility to manage iCloud documents, the stopQuery() method
        would stop observing changes to the `NSMetadataQuery`. This method is called on the `TaskCoordinator`
        once a new `TaskCoordinator` has been set on the `TasksController`.
    */
    func stopQuery()
    
    /**
        Removes `URL` from the task of tracked `NSURL` instances. For example, an iCloud-specific
        `TaskCoordinator` would implement this method by deleting the underlying document that `URL`
        represents. When `URL` is removed, the coordinator object is responsible for informing the
        delegate by calling `taskCoordinatorDidUpdateContents(insertedURLs:removedURLs:updatedURLs:)`
        with the removed `NSURL`. If a failure occurs when removing `URL`, the coordinator object is
        responsible for informing the delegate by calling the `taskCoordinatorDidFailRemovingTaskAtURL(_:withError:)`
        method. The `TasksController` is the only object that should be calling this method directly.
        The "remove" is intended to be called on the `TasksController` instance with a `TaskInfo` object
        whose URL would be forwarded down to the coordinator through this method.
    
        :param: URL The `NSURL` instance to remove from the task of important instances.
    */
    func removeTaskAtURL(URL: NSURL)

    /**
        Creates an `NSURL` object representing `task` with the provided name. Callers of this method
        (which should only be the `TasksController` object) should first check to see if a task can be
        created with the provided name via the `canCreateTaskWithName(_:)` method. If the creation was
        successful, then this method should call the delegate's update method that passes the newly
        tracked `NSURL` as an inserted URL. If the creation was not successful, this method should 
        inform the delegate of the failure by calling its `taskCoordinatorDidFailCreatingTaskAtURL(_:withError:)`
        method. The "create" is intended to be called on the `TasksController` instance with a `TaskInfo`
        object whose URL would be forwarded down to the coordinator through this method.
    
        :param: task The task to create a backing `NSURL` for.
        :param: name The new name for the task.
    */
    func createURLForTask(task: Task, withName name: String)
    
    /**
        Checks to see if a task can be created with a given name. As an example, if a `TaskCoordinator`
        instance was responsible for storing its tasks locally as a document, the coordinator would
        check to see if there are any other documents on the file system that have the same name. If
        they do, the method would return `false`. Otherwise, it would return `true`. This method should only
        be called by the `TasksController` instance. Normally you would call the users will call the
        `canCreateTaskWithName(_:)` method on `TasksController`, which will forward down to the current
        `TaskCoordinator` instance.
    
        :param: name The name to use when checking to see if a task can be created.
    
        :returns: `true` if the task can be created with the given name, `false` otherwise.
    */
    func canCreateTaskWithName(name: String) -> Bool
}


/**
    The `TaskCoordinatorDelegate` protocol exists to allow `TaskCoordinator` instances to forward
    events. These events include a `TaskCoordinator` removing, inserting, and updating their important,
    tracked `NSURL` instances. The `TaskCoordinatorDelegate` also allows a `TaskCoordinator` to notify
    its delegate of any errors that occured when removing or creating a task for a given URL.
*/
@objc public protocol TaskCoordinatorDelegate {
    /**
        Notifies the `TaskCoordinatorDelegate` instance of any changes to the tracked URLs of the
        `TaskCoordinator`. For more information about when this method should be called, see the
        description for the other `TaskCoordinator` methods mentioned above that manipulate the tracked
        `NSURL` instances.
    
        :param: insertedURLs The `NSURL` instances that are newly tracked.
        :param: removedURLs The `NSURL` instances that have just been untracked.
        :param: updatedURLs The `NSURL` instances that have had their underlying model updated.
    */
     func taskCoordinatorDidUpdateContents(#insertedURLs: [NSURL], removedURLs: [NSURL], updatedURLs: [NSURL])
    
    /**
        Notifies a `TaskCoordinatorDelegate` instance of an error that occured when a coordinator
        tried to remove a specific URL from the tracked `NSURL` instances. For more information about
        when this method should be called, see the description for the `removeTaskAtURL(_:)` method
        on `TaskCoordinator`.
    
        :param: URL The `NSURL` instance that failed to be removed.
        :param: error The error that describes why the remove failed.
    */
    func taskCoordinatorDidFailRemovingTaskAtURL(URL: NSURL, withError error: NSError)

    /**
        Notifies a `TaskCoordinatorDelegate` instance of an error that occured when a coordinator
        tried to create a task at a given URL. For more information about when this method should be
        called, see the description for the `createURLForTask(_:withName:)` method on `TaskCoordinator`.
    
        :param: URL The `NSURL` instance that couldn't be created for a task.
        :param: error The error the describes why the create failed.
    */
    func taskCoordinatorDidFailCreatingTaskAtURL(URL: NSURL, withError error: NSError)
}
