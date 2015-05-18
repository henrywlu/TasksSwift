/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The implementation for the `AllTaskItemsPresenter` type. This class is responsible for managing how a task is presented in the iOS and OS X apps.
*/

import Foundation

/**
    The `AllTaskItemsPresenter` task presenter class is responsible for managing how a task is displayed in
    both the iOS and OS X apps. The `AllTaskItemsPresenter` class conforms to `TaskPresenterType` so consumers
    of this class can work with the presenter with a common interface.

    When a task is presented with an `AllTaskItemsPresenter`, all of the task items with a task are presented
    (as the name suggests!). When the task items are displayed to a user, the incomplete task items are
    ordered before the complete task items. This order is determined when `setTask(_:)` is called on the
    `AllTaskItemsPresenter` instance. The presenter then reorders the task items accordingly, calling the
    delegate methods with any relevant changes.

    An `AllTaskItemsPresenter` can be interacted with in a few ways. It can insert, remove, toggle, move, and
    update task items. It can also change the color of the presented task. All of these changes get funnelled
    through callbacks to the delegate (a `TaskPresenterDelegate`). For more information about how the delegate
    pattern for the `TaskPresenterType` is architected, see the `TaskPresenterType` definition. What's unique
    about the `AllTaskItemsPresenter` with respect to the delegate methods is that the `AllTaskItemsPresenter`
    has an undo manager. Whenever the presentation of the task is manipulated (as described above), the
    presenter pushes an undo operation that reverses the manipulation onto the undo stack. For example, if a
    task item is inserted, the `AllTaskItemsPresenter` instance registers an undo operation to remove the task
    item.  When a user performs an undo in either the iOS or OS X app, the task item that was inserted is
    removed.  The remove operation gets funnelled into the same delegate that inserted the task item. By
    abstracting these operations away into a presenter and delegate architecture, we're not only able to
    easily test the code that manipulates the task, but we're also able to test the undo registration code.

    One thing to note is that when a task item is toggled in the `AllTaskItemsPresenter`, it is moved from an
    index in its current completion state to an index opposite of the task items completion state. For
    example, if a task item that is complete is toggled, it will move to an incomplete index (e.g. index 0).
    For the `AllTaskItemsPresenter`, a toggle represents both the task item moving as well as the task item
    being updated.
*/
final public class AllTaskItemsPresenter: NSObject, TaskPresenterType {
    // MARK: Properties
    
    /// The internal storage for the task that we're presenting. By default, it's an empty task.
    private var task = Task()
    
    /// Flag to see whether or not the first `setTask(_:)` call should trigger a batch reload.
    private var isInitialTask = true

    /// The undo manager to register undo events with when the `AllTaskItemsPresenter` instance is manipulated.
    public var undoManager: NSUndoManager?
    
    /**
        The index of the first complete item within the task's items. `nil` if there is no complete task item
        in the presented task items.
    */
    private var indexOfFirstCompleteTaskItem: Int? {
        var firstCompleteTaskItemIndex: Int?

        for (idx, taskItem) in enumerate(presentedTaskItems) {
            if taskItem.isComplete {
                firstCompleteTaskItemIndex = idx

                break
            }
        }

        return firstCompleteTaskItemIndex
    }
    
    // MARK: TaskPresenterType

    public weak var delegate: TaskPresenterDelegate?

    public var color: Task.Color {
        get {
            return task.color
        }

        set {
            updateTaskItemsWithRawColor(newValue.rawValue)
        }
    }
    
    public var archiveableTask: Task {
        // The task is already in archiveable form since we're updating it directly.
        return task
    }
    
    public var presentedTaskItems: [TaskItem] {
        // We're showing all of the task items in the task.
        return task.items
    }
    
    /**
        Sets the task that should be presented. Calling `setTask(_:)` on an `AllTaskItemsPresenter` does not
        trigger any undo registrations. Calling `setTask(_:)` also removes all of the undo actions from the
        undo manager.
    */
    public func setTask(newTask: Task) {
        /**
            If this is the initial task that's being presented, just tell the delegate to reload all of the data.
        */
        if isInitialTask {
            isInitialTask = false
            
            task = newTask
            task.items = reorderedTaskItemsFromTaskItems(task.items)

            delegate?.taskPresenterDidRefreshCompleteLayout(self)
            
            return
        }

        /**
            Perform more granular changes (if we can). To do this, we group the changes into the different
            types of possible changes. If we know that a group of similar changes occured, we batch them
            together (e.g. four updates to task items). If multiple changes occur that we can't correctly
            resolve (an implementation detail), we refresh the complete layout. An example of this is if more
            than one task item is inserted or toggled. Since this algorithm doesn't track the indexes that
            task items are inserted at, we just refresh the complete layout to make sure that the task items
            are presented correctly. This applies for multiple groups of changes (e.g. one insert and one
            toggle), and also for any unique group of toggles/inserts where there's more than a single update.
        */
        let oldTask = task

        let newRemovedTaskItems = findRemovedTaskItems(initialTaskItems: oldTask.items, changedTaskItems: newTask.items)
        let newInsertedTaskItems = findInsertedTaskItems(initialTaskItems: oldTask.items, changedTaskItems: newTask.items)
        let newToggledTaskItems = findToggledTaskItems(initialTaskItems: oldTask.items, changedTaskItems: newTask.items)
        let newTaskItemsWithUpdatedText = findTaskItemsWithUpdatedText(initialTaskItems: oldTask.items, changedTaskItems: newTask.items)
        
        /**
            Determine if there was a unique group of batch changes we can make. Otherwise, we refresh all the
            data in the task.
        */
        let taskItemsBatchChangeKind = taskItemsBatchChangeKindForChanges(removedTaskItems: newRemovedTaskItems, insertedTaskItems: newInsertedTaskItems, toggledTaskItems: newToggledTaskItems, taskItemsWithUpdatedText: newTaskItemsWithUpdatedText)

        /**
            If there was no changes to the task items, check to see if the color changed and notify the
            delegate if it did. If there was not a unique group of changes, updated the entire task.
        */
        if taskItemsBatchChangeKind == nil {
            if oldTask.color != newTask.color {
                undoManager?.removeAllActionsWithTarget(self)

                updateTaskColorForTaskPresenterIfDifferent(self, &task.color, newTask.color, isForInitialLayout: true)
            }
            
            return
        }
        
        /**
            Check to see if there was more than one kind of unique group of changes, or if there were multiple
            toggled/inserted task items that we don't handle.
        */
        if taskItemsBatchChangeKind! == .Multiple || newToggledTaskItems.count > 1 || newInsertedTaskItems.count > 1 {
            undoManager?.removeAllActionsWithTarget(self)
            
            task = newTask
            task.items = reorderedTaskItemsFromTaskItems(task.items)

            delegate?.taskPresenterDidRefreshCompleteLayout(self)
            
            return
        }
        
        /** 
            At this point we know that we have changes that are uniquely identifiable: for example, one
            inserted task item, one toggled task item, multiple removed task items, or multiple task items
            whose text has been updated.
        */
        undoManager?.removeAllActionsWithTarget(self)
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: true)
        
        // Make the changes based on the unique change kind.
        switch taskItemsBatchChangeKind! {
            case .Removed:
                removeTaskItemsFromTaskItemsWithTaskPresenter(self, initialTaskItems: &task.items, taskItemsToRemove: newRemovedTaskItems)
            
            case .Inserted:
                unsafeInsertTaskItem(newInsertedTaskItems.first!)
            
            case .Toggled:
                // We want to toggle the *old* task item, not the one that's in `newTask`.
                let indexOfToggledTaskItemInOldTaskItems = find(oldTask.items, newToggledTaskItems.first!)!

                let taskItemToToggle = oldTask.items[indexOfToggledTaskItemInOldTaskItems]
    
                unsafeToggleTaskItem(taskItemToToggle)

            case .UpdatedText:
                updateTaskItemsWithTaskItemsForTaskPresenter(self, presentedTaskItems: &task.items, newUpdatedTaskItems: newTaskItemsWithUpdatedText)

            default:
                break
        }
        
        updateTaskColorForTaskPresenterIfDifferent(self, &task.color, newTask.color)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: true)
    }
    
    public var count: Int {
        return presentedTaskItems.count
    }
    
    public var isEmpty: Bool {
        return presentedTaskItems.isEmpty
    }

    // MARK: Methods
    
    /**
        Inserts `taskItem` into the task. If the task item is incomplete, `taskItem` is inserted at index 0.
        Otherwise, it is inserted at the end of the task. Inserting a task item calls the delegate's
        `taskPresenter(_:didInsertTaskItem:atIndex:)` method. Calling this method registers an undo event to
        remove the task item.
    
        :param: taskItem The `TaskItem` instance to insert.
    */
    public func insertTaskItem(taskItem: TaskItem) {
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        unsafeInsertTaskItem(taskItem)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).removeTaskItem(taskItem)
        
        let undoActionName = NSLocalizedString("Remove", comment: "")
        undoManager?.setActionName(undoActionName)
    }

    /**
        Inserts `taskItems` into the task. The net effect of this is calling `insertTaskItem(_:)` for each
        `TaskItem` instance in `taskItems`. Inserting task items calls the delegate's
        `taskPresenter(_:didInsertTaskItem:atIndex:)` method for each inserted task item after an individual
        task item has been inserted. Calling this method registers an undo event to remove each task item.
    
        :param: taskItems The `TaskItem` instances to insert.
    */
    public func insertTaskItems(taskItems: [TaskItem]) {
        if taskItems.isEmpty { return }
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        for taskItem in taskItems {
            unsafeInsertTaskItem(taskItem)
        }
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).removeTaskItems(taskItems)

        let undoActionName = NSLocalizedString("Remove", comment: "")
        undoManager?.setActionName(undoActionName)
    }
    
    /**
        Removes `taskItem` from the task. Removing the task item calls the delegate's
        `taskPresenter(_:didRemoveTaskItem:atIndex:)` method for the removed task item
        after it has been removed. Calling this method registers an undo event to insert
        the task item at its previous index.
        
        :param: taskItem The `TaskItem` instance to remove.
    */
    @objc public func removeTaskItem(taskItem: TaskItem) {
        let taskItemIndex = find(presentedTaskItems, taskItem)
        
        if taskItemIndex == nil {
            preconditionFailure("A task item was requested to be removed that isn't in the task.")
        }
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        task.items.removeAtIndex(taskItemIndex!)
        
        delegate?.taskPresenter(self, didRemoveTaskItem: taskItem, atIndex: taskItemIndex!)

        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)

        // Undo
        undoManager?.prepareWithInvocationTarget(self).insertTaskItemsForUndo([taskItem], atIndexes: [taskItemIndex!])
        
        let undoActionName = NSLocalizedString("Remove", comment: "")
        undoManager?.setActionName(undoActionName)
    }

    /**
        Removes `taskItems` from the task. Removing task items calls the delegate's
        `taskPresenter(_:didRemoveTaskItem:atIndex:)` method for each of the removed task items after an
        individual task item has been removed. Calling this method registers an undo event to insert the task
        items that were removed at their previous indexes.
        
        :param: taskItems The `TaskItem` instances to remove.
    */
    @objc public func removeTaskItems(taskItems: [TaskItem]) {
        if taskItems.isEmpty { return }
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        /**
            We're going to store the indexes of the task items that will be removed in an array.
            We do that so that when we insert the same task items back in for undo, we don't need
            to worry about insertion order (since it will just be the opposite of insertion order).
        */
        var removedIndexes = [Int]()
        
        for taskItem in taskItems {
            if let taskItemIndex = find(presentedTaskItems, taskItem) {
                task.items.removeAtIndex(taskItemIndex)
                
                delegate?.taskPresenter(self, didRemoveTaskItem: taskItem, atIndex: taskItemIndex)
                
                removedIndexes += [taskItemIndex]
            }
            else {
                preconditionFailure("A task item was requested to be removed that isn't in the task.")
            }
        }
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).insertTaskItemsForUndo(taskItems.reverse(), atIndexes: removedIndexes.reverse())
        
        let undoActionName = NSLocalizedString("Remove", comment: "")
        undoManager?.setActionName(undoActionName)
    }
    
    /**
        Updates the `text` property of `taskItem` with `newText`. Updating the text property of the task item
        calls the delegate's `taskPresenter(_:didUpdateTaskItem:atIndex:)` method for the task item that was
        updated. Calling this method registers an undo event to revert the text change back to the text before
        the method was invoked.
    
        :param: taskItem The `TaskItem` instance whose text needs to be updated.
        :param: newText The new text for `taskItem`.
    */
    @objc public func updateTaskItem(taskItem: TaskItem, withText newText: String) {
        precondition(contains(presentedTaskItems, taskItem), "A task item can only be updated if it already exists in the task.")
        
        // If the text is the same, it's a no op.
        if taskItem.text == newText { return }
        
        var index = find(presentedTaskItems, taskItem)!
        
        let oldText = taskItem.text
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        taskItem.text = newText
        
        delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: index)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).updateTaskItem(taskItem, withText: oldText)
        
        let undoActionName = NSLocalizedString("Text Change", comment: "")
        undoManager?.setActionName(undoActionName)
    }

    /**
        Tests whether `taskItem` is in the task and can be moved from its current index in the task to `toIndex`.
    
        :param: taskItem The item to test for insertion.
        :param: toIndex The index to use to determine if `taskItem` can be inserted into the task.
    
        :returns: Whether or not `taskItem` can be moved to `toIndex`.
    */
    public func canMoveTaskItem(taskItem: TaskItem, toIndex: Int) -> Bool {
        if !contains(presentedTaskItems, taskItem) { return false }

        let firstCompleteTaskItemIndex = indexOfFirstCompleteTaskItem
        
        if firstCompleteTaskItemIndex != nil {
            if taskItem.isComplete {
                return firstCompleteTaskItemIndex!...count ~= toIndex
            }
            else {
                return 0..<firstCompleteTaskItemIndex! ~= toIndex
            }
        }
        
        return !taskItem.isComplete && 0...count ~= toIndex
    }
    
    /**
        Moves `taskItem` to `toIndex`. Moving the `taskItem` to a new index calls the delegate's
        `taskPresenter(_:didMoveTaskItem:fromIndex:toIndex)` method with the moved task item. Calling this
        method registers an undo event that moves the task item from its new index back to its old index.

        :param: taskItem The task item to move.
        :param: toIndex The index to move `taskItem` to.
    */
    @objc public func moveTaskItem(taskItem: TaskItem, toIndex: Int) {
        precondition(canMoveTaskItem(taskItem, toIndex: toIndex), "An item can only be moved if it passes a \"can move\" test.")
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)

        let fromIndex = unsafeMoveTaskItem(taskItem, toIndex: toIndex)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).moveTaskItem(taskItem, toIndex: fromIndex)
        
        let undoActionName = NSLocalizedString("Move", comment: "")
        undoManager?.setActionName(undoActionName)
    }
    
    /**
        Toggles `taskItem` within the task. This method moves a complete task item to an incomplete index at
        the beginning of the task, or it moves an incomplete task item to a complete index at the last index
        of the task. The task item is also updated in place since the completion state is flipped. Toggling a
        task item calls the delegate's `taskPresenter(_:didMoveTaskItem:fromIndex:toIndex:)` method followed
        by the delegate's `taskPresenter(_:didUpdateTaskItem:atIndex:)` method. Calling this method registers
        an undo event that toggles the task item back to its original location and completion state.
    
        :param: taskItem The task item to toggle.
    */
    public func toggleTaskItem(taskItem: TaskItem) {
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        let fromIndex = unsafeToggleTaskItem(taskItem)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).toggleTaskItemForUndo(taskItem, toPreviousIndex: fromIndex)
        
        let undoActionName = NSLocalizedString("Toggle", comment: "")
        undoManager?.setActionName(undoActionName)
    }

    /**
        Set the completion state of all of the presented task items to `completionState`. This method does not
        move the task items around in any way. Changing the completion state on all of the task items calls
        the delegate's `taskPresenter(_:didUpdateTaskItem:atIndex:)` method for each task item that has been
        updated. Calling this method registers an undo event that sets the completion states for all of the
        task items back to the original state before the method was invoked.
    
        :param: completionState The value that all presented task item instances should have as their `isComplete` property.
    */
    public func updatePresentedTaskItemsToCompletionState(completionState: Bool) {
        var presentedTaskItemsNotMatchingCompletionState = presentedTaskItems.filter { $0.isComplete != completionState }
      
        // If there are no task items that match the completion state, it's a no op.
        if presentedTaskItemsNotMatchingCompletionState.isEmpty { return }

        let undoActionName = completionState ? NSLocalizedString("Complete All", comment: "") : NSLocalizedString("Incomplete All", comment: "")
        toggleTaskItemsWithoutMoving(presentedTaskItemsNotMatchingCompletionState, undoActionName: undoActionName)
    }
    
    /**
        Returns the task items at each index in `indexes` within the `presentedTaskItems` array.
    
        :param: indexes The indexes that correspond to the task items that should be retrieved from `presentedTaskItems`.
    
        :returns: The task items that are located at each index in `indexes` within `presentedTaskItems`.
    */
    public func taskItemsAtIndexes(indexes: NSIndexSet) -> [TaskItem] {
        var taskItems = [TaskItem]()
        
        taskItems.reserveCapacity(indexes.count)
        
        indexes.enumerateIndexesUsingBlock { idx, _ in
            taskItems += [self.presentedTaskItems[idx]]
        }
        
        return taskItems
    }
    
    // MARK: Undo Helper Methods

    /**
        Toggles a task item to a specific destination index. This method is used to in `toggleTaskItem(_:)`
        where the undo event needs to move the task item back into its original location (rather than being
        moved to an index that it would normally be moved to in a call to `toggleTaskItem(_:)`).
    
        :param: taskItem The task item to toggle.
        :param: previousIndex The index to move `taskItem` to.
    */
    @objc private func toggleTaskItemForUndo(taskItem: TaskItem, toPreviousIndex previousIndex: Int) {
        precondition(contains(presentedTaskItems, taskItem), "The task item should already be in the task if it's going to be toggled.")

        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        // Move the task item.
        let fromIndex = unsafeMoveTaskItem(taskItem, toIndex: previousIndex)
        
        // Update the task item's state.
        taskItem.isComplete = !taskItem.isComplete
        
        delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: previousIndex)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).toggleTaskItemForUndo(taskItem, toPreviousIndex: fromIndex)
        
        let undoActionName = NSLocalizedString("Toggle", comment: "")
        undoManager?.setActionName(undoActionName)
    }
    
    /**
        Inserts `taskItems` at `indexes`. This is useful for undoing a call to `removeTaskItem(_:)` or
        `removeTaskItems(_:)` where the opposite action, such as re-inserting the task item, has to be done
        where each task item moves back to its original location before the removal.
    
        :param: taskItems The task items to insert.
        :param: indexes The indexes at which to insert `taskItems` into.
    */
    @objc private func insertTaskItemsForUndo(taskItems: [TaskItem], atIndexes indexes: [Int]) {
        precondition(taskItems.count == indexes.count, "`taskItems` must have as many elements as `indexes`.")
    
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        for (taskItemIndex, taskItem) in enumerate(taskItems) {
            let insertionIndex = indexes[taskItemIndex]

            task.items.insert(taskItem, atIndex: insertionIndex)
            
            delegate?.taskPresenter(self, didInsertTaskItem: taskItem, atIndex: insertionIndex)
        }
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).removeTaskItems(taskItems)
        
        let undoActionName = NSLocalizedString("Remove", comment: "")
        undoManager?.setActionName(undoActionName)
    }

    /**
        Sets the task's color to the new color. Calling this method registers an undo event to be called to
        reset the color the original color before this method was called. Note that in order for the method to
        be representable in Objective-C (to make sure that `NSUndoManager` can safely call
        `updateTaskItemsWithRawColor(_:)`), we must make the parameter an `Int` and not a `Task.Color`.  This
        is because Swift enums are not representable in Objective-C.
    
        :param: rawColor The raw color value of the `Task.Color` that should be set as the new color.
    */
    @objc private func updateTaskItemsWithRawColor(rawColor: Int) {
        let oldColor = color

        let newColor = Task.Color(rawValue: rawColor)!

        updateTaskColorForTaskPresenterIfDifferent(self, &task.color, newColor, isForInitialLayout: false)
        
        // Undo
        undoManager?.prepareWithInvocationTarget(self).updateTaskItemsWithRawColor(rawColor)
        
        let undoActionName = NSLocalizedString("Change Color", comment: "")
        undoManager?.setActionName(undoActionName)
    }
    
    /**
        Toggles the completion state of each task item in `taskItems` without moving the task items.  This is
        useful for `updatePresentedTaskItemsToCompletionState(_:)` to call with just the task items that are not
        equal to the new completion state. Toggling the task items without moving them registers an undo event
        that toggles the task items again (effectively undoing the toggle in the first place).
    
        :params: taskItems The task items that should be toggled in place.
    */
    @objc private func toggleTaskItemsWithoutMoving(taskItems: [TaskItem], undoActionName: String) {
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)

        for taskItem in taskItems {
            taskItem.isComplete = !taskItem.isComplete

            let updatedIndex = find(presentedTaskItems, taskItem)!
          
            delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: updatedIndex)
        }
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)

        // Undo
        undoManager?.prepareWithInvocationTarget(self).toggleTaskItemsWithoutMoving(taskItems, undoActionName: undoActionName)
        undoManager?.setActionName(undoActionName)
    }
    
    // MARK: Internal Unsafe Updating Methods
    
    /**
        Inserts `taskItem` into the task based on the task item's completion state. The delegate receives a
        `taskPresenter(_:didInsertTaskItem:atIndex:)` callback. No undo registrations are performed.
        
        :param: taskItem The task item to insert.
    */
    private func unsafeInsertTaskItem(taskItem: TaskItem) {
        precondition(!contains(presentedTaskItems, taskItem), "A task item was requested to be added that is already in the task.")
        
        var indexToInsertTaskItem = taskItem.isComplete ? count : 0
        
        task.items.insert(taskItem, atIndex: indexToInsertTaskItem)
        
        delegate?.taskPresenter(self, didInsertTaskItem: taskItem, atIndex: indexToInsertTaskItem)
    }
    
    /**
        Moves `taskItem` to `toIndex`. This method also notifies the delegate that a task item was moved
        through the `taskPresenter(_:didMoveTaskItem:fromIndex:toIndex:)` callback.  No undo registrations are performed.
    
        :param: taskItem The task item to move to `toIndex`.
        :param: toIndex The index at which `taskItem` should be moved to.

        :returns: The index that `taskItem` was initially located at.
    */
    private func unsafeMoveTaskItem(taskItem: TaskItem, toIndex: Int) -> Int {
        precondition(contains(presentedTaskItems, taskItem), "A task item can only be moved if it already exists in the presented task items.")
        
        var fromIndex = find(presentedTaskItems, taskItem)!

        task.items.removeAtIndex(fromIndex)
        task.items.insert(taskItem, atIndex: toIndex)
        
        delegate?.taskPresenter(self, didMoveTaskItem: taskItem, fromIndex: fromIndex, toIndex: toIndex)
        
        return fromIndex
    }

    private func unsafeToggleTaskItem(taskItem: TaskItem) -> Int {
        precondition(contains(presentedTaskItems, taskItem), "A task item can only be toggled if it already exists in the task.")
        
        // Move the task item.
        let targetIndex = taskItem.isComplete ? 0 : count - 1
        let fromIndex = unsafeMoveTaskItem(taskItem, toIndex: targetIndex)
        
        // Update the task item's state.
        taskItem.isComplete = !taskItem.isComplete
        delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: targetIndex)
        
        return fromIndex
    }
    
    // MARK: Private Convenience Methods
    
    /**
        Returns an array that contains the same elements as `taskItems`, but sorted with incomplete task items
        followed by complete task items.
    
        :param: taskItems Task items that should be reordered.
    
        :returns: The reordered task items with incomplete task items followed by complete task items.
    */
    private func reorderedTaskItemsFromTaskItems(taskItems: [TaskItem]) -> [TaskItem] {
        let incompleteTaskItems = taskItems.filter { !$0.isComplete }
        let completeTaskItems = taskItems.filter { $0.isComplete }

        return incompleteTaskItems + completeTaskItems
    }
}
