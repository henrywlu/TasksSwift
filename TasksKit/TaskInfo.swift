/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TaskInfo` class is a caching abstraction over a `Task` object that contains information about tasks (e.g. color and name).
*/

import UIKit

public class TaskInfo: NSObject {
    // MARK: Properties

    public let URL: NSURL
    
    public var color: Task.Color?

    public var name: String {
        let displayName = NSFileManager.defaultManager().displayNameAtPath(URL.path!)

        return displayName.stringByDeletingPathExtension
    }

    private let fetchQueue = dispatch_queue_create("com.locust123.taskinfo", DISPATCH_QUEUE_SERIAL)

    // MARK: Initializers

    public init(URL: NSURL) {
        self.URL = URL
    }

    // MARK: Fetch Methods

    public func fetchInfoWithCompletionHandler(completionHandler: Void -> Void) {
        dispatch_async(fetchQueue) {
            // If the color hasn't been set yet, the info hasn't been fetched.
            if self.color != nil {
                completionHandler()
                
                return
            }
            
            TaskUtilities.readTaskAtURL(self.URL) { task, error in
                dispatch_async(self.fetchQueue) {
                    if let task = task {
                        self.color = task.color
                    }
                    else {
                        self.color = .Gray
                    }
                    
                    completionHandler()
                }
            }
        }
    }
    
    // MARK: NSObject
    
    override public func isEqual(object: AnyObject?) -> Bool {
        if let taskInfo = object as? TaskInfo {
            return taskInfo.URL == URL
        }

        return false
    }
}
