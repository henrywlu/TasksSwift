/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    Helper functions to perform common operations in `IncompleteTaskItemsPresenter` and `AllTaskItemsPresenter`.
*/

import Foundation

/**
    Removes each task item found in `taskItemsToRemove` from the `initialTaskItems` array. For each removal,
    the function notifies the `taskPresenter`'s delegate of the change.
*/
func removeTaskItemsFromTaskItemsWithTaskPresenter(taskPresenter: TaskPresenterType, inout #initialTaskItems: [TaskItem], #taskItemsToRemove: [TaskItem]) {
    let sortedTaskItemsToRemove = taskItemsToRemove.sorted { find(initialTaskItems, $0)! > find(initialTaskItems, $1)! }
    
    for taskItemToRemove in sortedTaskItemsToRemove {
        // Use the index of the task item to remove in the current task's task items.
        let indexOfTaskItemToRemoveInOldTask = find(initialTaskItems, taskItemToRemove)!
        
        initialTaskItems.removeAtIndex(indexOfTaskItemToRemoveInOldTask)
        
        taskPresenter.delegate?.taskPresenter(taskPresenter, didRemoveTaskItem: taskItemToRemove, atIndex: indexOfTaskItemToRemoveInOldTask)
    }
}

/**
    Inserts each task item in `taskItemsToInsert` into `initialTaskItems`. For each insertion, the function
    notifies the `taskPresenter`'s delegate of the change.
*/
func insertTaskItemsIntoTaskItemsWithTaskPresenter(taskPresenter: TaskPresenterType, inout #initialTaskItems: [TaskItem], #taskItemsToInsert: [TaskItem]) {
    for (idx, insertedIncompleteTaskItem) in enumerate(taskItemsToInsert) {
        initialTaskItems.insert(insertedIncompleteTaskItem, atIndex: idx)
        
        taskPresenter.delegate?.taskPresenter(taskPresenter, didInsertTaskItem: insertedIncompleteTaskItem, atIndex: idx)
    }
}

/**
    Replaces the stale task items in `presentedTaskItems` with the new ones found in `newUpdatedTaskItems`. For
    each update, the function notifies the `taskPresenter`'s delegate of the update.
*/
func updateTaskItemsWithTaskItemsForTaskPresenter(taskPresenter: TaskPresenterType, inout #presentedTaskItems: [TaskItem], #newUpdatedTaskItems: [TaskItem]) {
    for newlyUpdatedTaskItem in newUpdatedTaskItems {
        let indexOfTaskItem = find(presentedTaskItems, newlyUpdatedTaskItem)!
        
        presentedTaskItems[indexOfTaskItem] = newlyUpdatedTaskItem
        
        taskPresenter.delegate?.taskPresenter(taskPresenter, didUpdateTaskItem: newlyUpdatedTaskItem, atIndex: indexOfTaskItem)
    }
}

/**
    Replaces `color` with `newColor` if the colors are different. If the colors are different, the function
    notifies the delegate of the updated color change. If `isForInitialLayout` is not `nil`, the function wraps
    the changes in a call to `taskPresenterWillChangeTaskLayout(_:isInitialLayout:)`
    and a call to `taskPresenterDidChangeTaskLayout(_:isInitialLayout:)` with the value `isForInitialLayout!`.
*/
func updateTaskColorForTaskPresenterIfDifferent(taskPresenter: TaskPresenterType, inout color: Task.Color, newColor: Task.Color, isForInitialLayout: Bool? = nil) {    
    // Don't trigger any updates if the new color is the same as the current color.
    if color == newColor { return }
    
    if isForInitialLayout != nil {
        taskPresenter.delegate?.taskPresenterWillChangeTaskLayout(taskPresenter, isInitialLayout: isForInitialLayout!)
    }
    
    color = newColor
    
    taskPresenter.delegate?.taskPresenter(taskPresenter, didUpdateTaskColorWithColor: newColor)
    
    if isForInitialLayout != nil {
        taskPresenter.delegate?.taskPresenterDidChangeTaskLayout(taskPresenter, isInitialLayout: isForInitialLayout!)
    }
}