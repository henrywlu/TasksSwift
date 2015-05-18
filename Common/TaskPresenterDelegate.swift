/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The definition for the `TaskPresenterDelegate` type. This protocol defines the contract between the `TaskPresenterType` interactions and receivers of those events (the type that conforms to the `TaskPresenterDelegate` protocol).
*/

/**
    The `TaskPresenterDelegate` type is used to receive events from a `TaskPresenterType` about updates to the
    presenter's layout. This happens, for example, if a `TaskItem` object is inserted into the task or removed
    from the task. For any change that occurs to the task, a delegate message can be called. As a conformer
    you must implement all of these methods, but you may decide not to take any action if the method doesn't
    apply to your use case. For an implementation of `TaskPresenterDelegate`, see the `AllTaskItemsPresenter`
    or `IncompleteTaskItemsPresenter` types.
*/
public protocol TaskPresenterDelegate: class {
    /**
        A `TaskItemPresenterType` invokes this method on its delegate when a large change to the underlying
        task changed, but the presenter couldn't resolve the granular changes. A full layout change includes
        changing anything on the underlying task: task item toggling, text updates, color changes, etc. This
        is invoked, for example, when the task is initially loaded, because there could be many changes that
        happened relative to an empty task--the delegate should just reload everything immediately.  This
        method is not wrapped in `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and
        `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)` method invocations.
    
        :param: taskPresenter The task presenter whose full layout has changed.
    */
    func taskPresenterDidRefreshCompleteLayout(taskPresenter: TaskPresenterType)
    
    /**
        A `TaskPresenterType` invokes this method on its delegate before a set of layout changes occur. This
        could involve task item insertions, removals, updates, toggles, etc. This can also include changes to
        the color of the `TaskPresenterType`.  If `isInitialLayout` is `true`, it means that the new task is
        being presented for the first time--for example, if `setTask(_:)` is called on the `TaskPresenterType`,
        the delegate will receive a `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` call where
        `isInitialLayout` is `true`.
    
        :param: taskPresenter The task presenter whose presentation will change.
        :param: isInitialLayout Whether or not the presenter is presenting the most recent task for the first time.
    */
    func taskPresenterWillChangeTaskLayout(taskPresenter: TaskPresenterType, isInitialLayout: Bool)
    
    /**
        A `TaskPresenterType` invokes this method on its delegate when an item was inserted into the task.
        This method is called only if the invocation is wrapped in a call to
        `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)`.
    
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: taskItem The task item that has been inserted.
        :param: index The index that `taskItem` was inserted into.
    */
    func taskPresenter(taskPresenter: TaskPresenterType, didInsertTaskItem taskItem: TaskItem, atIndex index: Int)
    
    /**
        A `TaskPresenterType` invokes this method on its delegate when an item was removed from the task. This
        method is called only if the invocation is wrapped in a call to
        `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)`.
        
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: taskItem The task item that has been removed.
        :param: index The index that `taskItem` was removed from.
    */
    func taskPresenter(taskPresenter: TaskPresenterType, didRemoveTaskItem taskItem: TaskItem, atIndex index: Int)

    /**
        A `TaskPresenterType` invokes this method on its delegate when an item is updated in place. This could
        happen, for example, if the text of a `TaskItem` instance changes. This method is called only if the
        invocation is wrapped in a call to `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and
        `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)`.
        
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: taskItem The task item that has been updated.
        :param: index The index that `taskItem` was updated at in place.
    */
    func taskPresenter(taskPresenter: TaskPresenterType, didUpdateTaskItem taskItem: TaskItem, atIndex index: Int)

    /**
        A `TaskPresenterType` invokes this method on its delegate when an item moved `fromIndex` to `toIndex`.
        This could happen, for example, if the task presenter toggles a `TaskItem` instance and it needs to be
        moved from one index to another.  This method is called only if the invocation is wrapped in a call to
        `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)`.
        
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: taskItem The task item that has been moved.
        :param: fromIndex The original index that `taskItem` was located at before the move.
        :param: toIndex The index that `taskItem` was moved to.
    */
    func taskPresenter(taskPresenter: TaskPresenterType, didMoveTaskItem taskItem: TaskItem, fromIndex: Int, toIndex: Int)

    /**
        A `TaskPresenterType` invokes this method on its delegate when the color of the `TaskPresenterType`
        changes. This method is called only if the invocation is wrapped in a call to
        `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` and `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)`.
    
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: color The new color of the presented task.
    */
    func taskPresenter(taskPresenter: TaskPresenterType, didUpdateTaskColorWithColor color: Task.Color)

    /**
        A `TaskPresenterType` invokes this method on its delegate after a set of layout changes occur. See
        `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)` for examples of when this is called.
        
        :param: taskPresenter The task presenter whose presentation has changed.
        :param: isInitialLayout Whether or not the presenter is presenting the most recent task for the first time.
    */
    func taskPresenterDidChangeTaskLayout(taskPresenter: TaskPresenterType, isInitialLayout: Bool)
}
