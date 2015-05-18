/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TaskDocument` class is a `UIDocument` subclass that represents a task. `TaskDocument` manages the serialization / deserialization of the task object in addition to a task presenter.
*/

import UIKit

/// Protocol that allows a task document to notify other objects of it being deleted.
@objc public protocol TaskDocumentDelegate {
    func taskDocumentWasDeleted(taskDocument: TaskDocument)
}

public class TaskDocument: UIDocument {
    // MARK: Properties

    public weak var delegate: TaskDocumentDelegate?
    
    // Use a default, empty task.
    public var taskPresenter: TaskPresenterType?

    // MARK: Initializers
    
    public init(fileURL URL: NSURL, taskPresenter: TaskPresenterType? = nil) {
        self.taskPresenter = taskPresenter

        super.init(fileURL: URL)
    }

    // MARK: Serialization / Deserialization
    
    override public func loadFromContents(contents: AnyObject, ofType typeName: String, error outError: NSErrorPointer) -> Bool {
        if let unarchivedTask = NSKeyedUnarchiver.unarchiveObjectWithData(contents as! NSData) as? Task {
            /*
                This method is called on the queue that the `openWithCompletionHandler(_:)` method was called
                on (typically, the main queue). Task presenter operations are main queue only, so explicitly
                call on the main queue.
            */
            dispatch_async(dispatch_get_main_queue()) {
                self.taskPresenter?.setTask(unarchivedTask)
                
                return
            }

            return true
        }
        
        if outError != nil {
            outError.memory = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Could not read file", comment: "Read error description"),
                NSLocalizedFailureReasonErrorKey: NSLocalizedString("File was in an invalid format", comment: "Read failure reason")
            ])
        }
        
        return false
    }

    override public func contentsForType(typeName: String, error outError: NSErrorPointer) -> AnyObject? {
        if let archiveableTask = taskPresenter?.archiveableTask {
            return NSKeyedArchiver.archivedDataWithRootObject(archiveableTask)
        }

        return nil
    }
    
    // MARK: Deletion

    override public func accommodatePresentedItemDeletionWithCompletionHandler(completionHandler: NSError? -> Void) {
        super.accommodatePresentedItemDeletionWithCompletionHandler(completionHandler)
        
        delegate?.taskDocumentWasDeleted(self)
    }
    
    // MARK: Handoff
    
    override public func updateUserActivityState(userActivity: NSUserActivity) {
        super.updateUserActivityState(userActivity)
        
        if let rawColorValue = taskPresenter?.color.rawValue {
            userActivity.addUserInfoEntriesFromDictionary([
                AppConfiguration.UserActivity.taskColorUserInfoKey: rawColorValue
            ])
        }
    }
}
