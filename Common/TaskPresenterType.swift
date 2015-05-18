/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The definition for the `TaskPresenterType` type. This protocol defines the contract between task presenters and how their tasks are presented / archived.
*/

/**
    The `TaskPresenterType` protocol defines the building blocks required for an object to be used as a task
    presenter. Task presenters are meant to be used where a `Task` object is displayed; in essence, a task
    presenter "fronts" a `Task` object. With iOS / OS X apps, iOS / OS X widgets, and WatchKit extensions, we
    can classify these interaction models into task presenters. All of the logic can then be abstracted away
    so that the interaction is testable, reusable, and scalable. By defining the core requirements of a task
    presenter through the `TaskPresenterType`, consumers of `TaskPresenterType` instances can share a common
    interaction interface to a task.

    Types that conform to `TaskPresenterType` have other methods to manipulate a task. For example, a
    presenter can allow for inserting task items into the task and moving a task item from one index.  All of
    these updates require that the `TaskPresenterType` notify its delegate (a `TaskPresenterDelegate`) of
    these changes through the common delegate methods. Each of these methods should be surrounded by
    `taskPresenterWillChangeTaskLayout(_:)` and `taskPresenterDidChangeTaskLayout(_:)` invocations.  For more
    information about the expectations of how a `TaskPresenterDelegate` interacts with a `TaskPresenterType`,
    see the `TaskPresenterDelegate` protocol comments.

    The underlying implementation of the `TaskPresenterType` may use a `Task` object to store certain
    properties as a convenience, but there's no need to do that directly. You query an instance of a
    `TaskPresenterType` for its `archiveableTask` representation; that is, a representation of the currently
    presented task that can be archiveable. This may happen, for example, when a document needs to save the
    currently presented task in an archiveable form. Note that task presenters should be used on the main
    queue only.
*/
public protocol TaskPresenterType: class {
    // MARK: Properties

    /**
        The delegate that receives callbacks from the `TaskPresenterType` when the presentation of the task
        changes.
    */
    weak var delegate: TaskPresenterDelegate? { get set }
    
    /**
        Resets the presented task to a new task. This can be called, for example, when a new task is
        unarchived and needs to be presented. Calls to this method should wrap the entire sequence of changes
        in a single `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and
        `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)` invocation. In more complicated implementations
        of this method, you can find the intersection or difference between the new task's presented task items
        and the old task's presented task items, and then call into the remove/update/move delegate methods to
        inform the delegate of the re-organization. Delegates receive updates if the text of a `TaskItem`
        instance has changed. Delegates also receive a callback if the new color is different from the old
        task's color.
        
        :param: task The new task that the `TaskPresenterType` should present.
    */
    func setTask(task: Task)
    
    /**
        The color of the presented task. If the new color is different from the old color, notify the delegate
        through the `taskPresenter(_:didUpdateTaskColorWithColor:)` method.
    */
    var color: Task.Color { get set }

    /**
        An archiveable presentation of the task that that presenter is presenting. This commonly returns the
        underlying task being manipulated. However, this can be computed based on the current state of the
        presenter (color, task items, etc.). If a presenter has changes that are not yet applied to the task,
        the task returned here should have those changes applied.
    */
    var archiveableTask: Task { get }
    
    /**
        The presented task items that should be displayed in order. Adopters of the `TaskPresenterType` protocol
        can decide not to show all of the task items within a task.
    */
    var presentedTaskItems: [TaskItem] { get }
    
    /// A convenience property that should return the equivalent of `presentedTaskItems.count`.
    var count: Int { get }
    
    /// A convenience property that should return the equivalent of `presentedTaskItems.isEmpty`.
    var isEmpty: Bool { get }
}
