/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The implementation for the `IncompleteTaskItemsPresenter` type. This class is responsible for managing how a task is presented in the iOS and OS X app Today widgets, as well as the Tasks WatchKit application.
*/

import Foundation

/**
    The `IncompleteTaskItemsPresenter` task presenter is responsible for managing the how a task's incomplete
    task items are displayed in the iOS and OS X Today widgets as well as the Tasks WatchKit app. The
    `IncompleteTaskItemsPresenter` class conforms to `TaskPresenterType` so consumers of this class can work
    with the presenter using a common interface.

    When a task is initially presented with an `IncompleteTaskItemsPresenter`, only the incomplete task items
    are presented. That can change, however, if a user toggles task items (changing the task item's completion
    state). An `IncompleteTaskItemsPresenter` always shows the task items that are initially presented (unless
    they are removed from the task from another device). If an `IncompleteTaskItemsPresenter` stops presenting
    a task that has some presented task items that are complete (after toggling them) and another
    `IncompleteTaskItemsPresenter` presents the same task, the presenter displays *only* the incomplete task
    items.

    The `IncompleteTaskItemsPresenter` can be interacted with in a two ways. `TaskItem` instances can be
    toggled individually or using a batch update, and the color of the task presenter can be changed.  All of
    these methods trigger calls to the delegate to be notified about inserted task items, removed task items,
    updated task items, etc.
*/
final public class IncompleteTaskItemsPresenter: NSObject, TaskPresenterType {
    // MARK: Properties

    /// The internal storage for the task that we're presenting. By default, it's an empty task.
    private var task = Task()
    
    /// Flag to see whether or not the first `setTask(_:)` call should trigger a batch reload.
    private var isInitialTask = true

    /**
        A cached array of the task items that should be presented. When the presenter initially has its
        underlying `task` set, the `_presentedTaskItems` is set to all of the incomplete task items.  As task
        items are toggled, `_presentedTaskItems` may contain incomplete task items as well as complete items
        that were incomplete when the presenter's task was set. Note that we've named the property
        `_presentedTaskItems` since there's already a readonly `presentedTaskItems` property (which returns the
        value of `_presentedTaskItems`).
    */
    private var _presentedTaskItems = [TaskItem]()
    
    // MARK: TaskPresenterType
    
    public weak var delegate: TaskPresenterDelegate?
    
    public var color: Task.Color {
        get {
            return task.color
        }
        
        set {
            updateTaskColorForTaskPresenterIfDifferent(self, &task.color, newValue, isForInitialLayout: false)
        }
    }
    
    public var archiveableTask: Task {
        return task
    }
    
    public var presentedTaskItems: [TaskItem] {
        return _presentedTaskItems
    }

    /**
        This methods determines the changes betwen the current task and the new task provided, and it notifies
        the delegate accordingly. The delegate is notified of all changes except for reordering task items (an
        implementation detail). If the task is the initial task to be presented, we just reload all of the
        data.
    */
    public func setTask(newTask: Task) {
        // If this is the initial task that's being presented, just tell the delegate to reload all of the data.
        if isInitialTask {
            isInitialTask = false
            
            task = newTask
            _presentedTaskItems = task.items.filter { !$0.isComplete }
            
            delegate?.taskPresenterDidRefreshCompleteLayout(self)
            
            return
        }

        /**
            First find all the differences between the tasks that we want to reflect in the presentation of
            the task: task items that were removed, inserted task items that are incomplete, presented task
            items that are toggled, and presented task items whose text has changed. Note that although we'll
            gradually update `_presentedTaskItems` to reflect the changes we find, we also want to save the
            latest state of the task (i.e. the `newTask` parameter) as the underlying storage of the task.
            Since we'll be presenting the same task either way, it's better not to change the underlying task
            representation unless we need to. Keep in mind, however, that all of the task items in
            `_presentedTaskItems` should also be in `task.items`.  In short, once we modify `_presentedTaskItems`
            with all of the changes, we need to also update `task.items` to contain all of the task items that
            were unchanged (this can be done by replacing the new task item representation by the old
            representation of the task item). Once that happens, all of the presentation logic carries on as
            normal.
        */
        let oldTask = task
        
        let newRemovedPresentedTaskItems = findRemovedTaskItems(initialTaskItems: _presentedTaskItems, changedTaskItems: newTask.items)
        let newInsertedIncompleteTaskItems = findInsertedTaskItems(initialTaskItems: _presentedTaskItems, changedTaskItems: newTask.items) { taskItem in
            return !taskItem.isComplete
        }
        let newPresentedToggledTaskItems = findToggledTaskItems(initialTaskItems: _presentedTaskItems, changedTaskItems: newTask.items)
        let newPresentedTaskItemsWithUpdatedText = findTaskItemsWithUpdatedText(initialTaskItems: _presentedTaskItems, changedTaskItems: newTask.items)

        let taskItemsBatchChangeKind = taskItemsBatchChangeKindForChanges(removedTaskItems: newRemovedPresentedTaskItems, insertedTaskItems: newInsertedIncompleteTaskItems, toggledTaskItems: newPresentedToggledTaskItems, taskItemsWithUpdatedText: newPresentedTaskItemsWithUpdatedText)

        // If no changes occured we'll ignore the update.
        if taskItemsBatchChangeKind == nil && oldTask.color == newTask.color {
            return
        }
        
        // Start performing changes to the presentation of the task.
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: true)
        
        // Remove the task items from the presented task items that were removed somewhere else.
        if !newRemovedPresentedTaskItems.isEmpty {
            removeTaskItemsFromTaskItemsWithTaskPresenter(self, initialTaskItems: &_presentedTaskItems, taskItemsToRemove: newRemovedPresentedTaskItems)
        }
        
        // Insert the incomplete task items into the presented task items that were inserted elsewhere.
        if !newInsertedIncompleteTaskItems.isEmpty {
            insertTaskItemsIntoTaskItemsWithTaskPresenter(self, initialTaskItems: &_presentedTaskItems, taskItemsToInsert: newInsertedIncompleteTaskItems)
        }
        
        /**
            For all of the task items whose content has changed elsewhere, we need to update the task items in
            place.  Since the `IncompleteTaskItemsPresenter` keeps toggled task items in place, we only need
            to perform one update for task items that have a different completion state and text. We'll batch
            both of these changes into a single update.
        */
        if !newPresentedToggledTaskItems.isEmpty || !newPresentedTaskItemsWithUpdatedText.isEmpty {
            // Find the unique task of task items that are updated.
            let uniqueUpdatedTaskItems = Set(newPresentedToggledTaskItems).union(newPresentedTaskItemsWithUpdatedText)

            updateTaskItemsWithTaskItemsForTaskPresenter(self, presentedTaskItems: &_presentedTaskItems, newUpdatedTaskItems: Array(uniqueUpdatedTaskItems))
        }

        /**
            At this point, the presented task items have been updated. As mentioned before, to ensure that
            we're consistent about how we persist the updated task, we'll just use new the new task as the
            underlying model. To do that, we'll need to update the new task's unchanged task items with the
            task items that are stored in the visual task items. Specifically, we need to make sure that any
            references to task items in `_presentedTaskItems` are reflected in the new task's items.
        */
        task = newTask
        
        // Obtain the presented task items that were unchanged. We need to update the new task to reference the old task items.
        let unchangedPresentedTaskItems = _presentedTaskItems.filter { oldTaskItem in
            return !contains(newRemovedPresentedTaskItems, oldTaskItem) && !contains(newInsertedIncompleteTaskItems, oldTaskItem) && !contains(newPresentedToggledTaskItems, oldTaskItem) && !contains(newPresentedTaskItemsWithUpdatedText, oldTaskItem)
        }
        replaceAnyEqualUnchangedNewTaskItemsWithPreviousUnchangedTaskItems(replaceableNewTaskItems: &task.items, previousUnchangedTaskItems: unchangedPresentedTaskItems)

        /**
            Even though the old task's color will change if there's a difference between the old task's color
            and the new task's color, the delegate only cares about this change in reference to what it
            already knows.  Because the delegate hasn't seen a color change yet, the update (if it happens) is
            ok.
        */
        updateTaskColorForTaskPresenterIfDifferent(self, &oldTask.color, newTask.color)
        
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
        Toggles `taskItem` within the task. This method keeps the task item in the same place, but it toggles
        the completion state of the task item. Toggling a task item calls the delegate's
        `taskPresenter(_:didUpdateTaskItem:atIndex:)` method.
        
        :param: taskItem The task item to toggle.
    */
    public func toggleTaskItem(taskItem: TaskItem) {
        precondition(contains(presentedTaskItems, taskItem), "The task item must already be in the presented task items.")
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        taskItem.isComplete = !taskItem.isComplete
        
        let currentIndex = find(presentedTaskItems, taskItem)!
        
        delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: currentIndex)
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
    }

    /**
        Sets all of the presented task item's completion states to `completionState`. This method does not move
        the task items around in any way. Changing the completion state on all of the task items calls the
        delegate's `taskPresenter(_:didUpdateTaskItem:atIndex:)` method for each task item that has been
        updated. 

        :param: completionState The value that all presented task item instances should have as their `isComplete` property.
    */
    public func updatePresentedTaskItemsToCompletionState(completionState: Bool) {
        var presentedTaskItemsNotMatchingCompletionState = presentedTaskItems.filter { $0.isComplete != completionState }
        
        // If there are no task items that match the completion state, it's a no op.
        if presentedTaskItemsNotMatchingCompletionState.isEmpty { return }
        
        delegate?.taskPresenterWillChangeTaskLayout(self, isInitialLayout: false)
        
        for taskItem in presentedTaskItemsNotMatchingCompletionState {
            taskItem.isComplete = !taskItem.isComplete
            
            let indexOfTaskItem = find(presentedTaskItems, taskItem)!
            
            delegate?.taskPresenter(self, didUpdateTaskItem: taskItem, atIndex: indexOfTaskItem)
        }
        
        delegate?.taskPresenterDidChangeTaskLayout(self, isInitialLayout: false)
    }
}
