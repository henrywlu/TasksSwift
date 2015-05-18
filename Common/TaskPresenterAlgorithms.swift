/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    Simple internal helper functions to share across `IncompleteTaskItemsPresenter` and `AllTaskItemsPresenter`. These functions help diff two arrays of `TaskItem` objects.
*/

import Foundation

/// An enum to keep track of the different kinds of changes that may take place within a task.
enum TaskItemsBatchChangeKind {
    case Removed
    case Inserted
    case Toggled
    case UpdatedText
    case Multiple
}

/// Returns an array of `TaskItem` objects in `initialTaskItems` that don't exist in `changedTaskItems`.
func findRemovedTaskItems(#initialTaskItems: [TaskItem], #changedTaskItems: [TaskItem]) -> [TaskItem] {
    return initialTaskItems.filter { !contains(changedTaskItems, $0) }
}

/// Returns an array of `TaskItem` objects in `changedTaskItems` that don't exist in `initialTaskItems`.
func findInsertedTaskItems(#initialTaskItems: [TaskItem], #changedTaskItems: [TaskItem], filter filterHandler: TaskItem -> Bool = { _ in return true }) -> [TaskItem] {
    return changedTaskItems.filter { !contains(initialTaskItems, $0) && filterHandler($0) }
}

/**
    Returns an array of `TaskItem` objects in `changedTaskItems` whose completion state changed from `initialTaskItems`
    relative to `changedTaskItems`.
*/
func findToggledTaskItems(#initialTaskItems: [TaskItem], #changedTaskItems: [TaskItem]) -> [TaskItem] {
    return changedTaskItems.filter { changedTaskItem in
        if let indexOfChangedTaskItemInInitialTaskItems = find(initialTaskItems, changedTaskItem) {
            let initialTaskItem = initialTaskItems[indexOfChangedTaskItemInInitialTaskItems]
            
            if initialTaskItem.isComplete != changedTaskItem.isComplete {
                return true
            }
        }
        
        return false
    }
}

/**
    Returns an array of `TaskItem` objects in `changedTaskItems` whose text changed from `initialTaskItems`
    relative to `changedTaskItems.
*/
func findTaskItemsWithUpdatedText(#initialTaskItems: [TaskItem], #changedTaskItems: [TaskItem]) -> [TaskItem] {
    return changedTaskItems.filter { changedTaskItem in
        if let indexOfChangedTaskItemInInitialTaskItems = find(initialTaskItems, changedTaskItem) {
            let initialTaskItem = initialTaskItems[indexOfChangedTaskItemInInitialTaskItems]

            if initialTaskItem.text != changedTaskItem.text {
                return true
            }
        }
        
        return false
    }
}

/**
    Update `replaceableNewTaskItems` in place with all of the task items that are equal in `previousUnchangedTaskItems`.
    For example, if `replaceableNewTaskItems` has task items of UUID "1", "2", and "3" and `previousUnchangedTaskItems`
    has task items of UUID "2" and "3", the `replaceableNewTaskItems` array will have it's task items with UUID
    "2" and "3" replaced with the task items whose UUID is "2" and "3" in `previousUnchangedTaskItems`. This is
    used to ensure that the task items in multiple arrays are referencing the same objects in memory as what the
    presented task items are presenting.
*/
func replaceAnyEqualUnchangedNewTaskItemsWithPreviousUnchangedTaskItems(inout #replaceableNewTaskItems: [TaskItem], #previousUnchangedTaskItems: [TaskItem]) {
    let replaceableNewTaskItemsCopy = replaceableNewTaskItems
    
    for (idx, replaceableNewTaskItem) in enumerate(replaceableNewTaskItemsCopy) {
        if let indexOfUnchangedTaskItem = find(previousUnchangedTaskItems, replaceableNewTaskItem) {
            replaceableNewTaskItems[idx] = previousUnchangedTaskItems[indexOfUnchangedTaskItem]
        }
    }
}

/**
    Returns the type of `TaskItemsBatchChangeKind` based on the different types of changes. The parameters for
    this function should be based on the result of the functions above. If there were no changes whatsoever,
    `nil` is returned.
*/
func taskItemsBatchChangeKindForChanges(#removedTaskItems: [TaskItem], #insertedTaskItems: [TaskItem], #toggledTaskItems: [TaskItem], #taskItemsWithUpdatedText: [TaskItem]) -> TaskItemsBatchChangeKind? {
    /**
        Switch on the different scenarios that we can isolate uniquely for whether or not changes were made in
        a specific kind of change. Look at the case values for a quick way to see which batch change kind is
        being targeted.
    */

    switch (!removedTaskItems.isEmpty, !insertedTaskItems.isEmpty, !toggledTaskItems.isEmpty, !taskItemsWithUpdatedText.isEmpty) {
        case (false, false, false, false):  return nil
        case (true,  false, false, false):  return .Removed
        case (false, true,  false, false):  return .Inserted
        case (false, false, true,  false):  return .Toggled
        case (false, false, false, true):   return .UpdatedText
        default:                            return .Multiple
    }
}
