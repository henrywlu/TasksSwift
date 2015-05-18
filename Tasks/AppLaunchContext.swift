//
//  AppLaunchContext.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//

import UIKit
import TasksKit

struct AppLaunchContext {
    // MARK: Properties
    
    let taskURL: NSURL
    
    let taskColor: Task.Color
    
    // MARK: Initializers
    
    /**
        Initializes an `AppLaunchContext` instance with the color and URL designated by the user activity.
        
        :param: userActivity The userActivity providing the file URL and task color to launch to.
    */
    init(userActivity: NSUserActivity) {
        assert(userActivity.userInfo != nil, "User activity provided to \(__FUNCTION__) has no `userInfo` dictionary.")
        let userInfo = userActivity.userInfo!
        
        /*
            The URL may be provided as either a URL or a URL path via separate keys. Check first for 
            `NSUserActivityDocumentURLKey`, if not provided, obtain the path and create a file URL from it.
        */
        
        var URL = userInfo[NSUserActivityDocumentURLKey] as? NSURL
        
        if URL == nil {
            let taskInfoFilePath = userInfo[AppConfiguration.UserActivity.taskURLPathUserInfoKey] as? String
            
            assert(taskInfoFilePath != nil, "The `userInfo` dictionary provided to \(__FUNCTION__) did not contain a URL or URL path.")
            
            URL = NSURL(fileURLWithPath: taskInfoFilePath!, isDirectory: false)
        }
        
        assert(URL != nil, "The `userInfo` dictionary provided to \(__FUNCTION__) did not contain a valid URL.")
        
        // Unwrap the URL obtained from the dictionary.
        taskURL = URL!
        
        // The color will be stored as an `Int` under the prescribed key.
        let rawColor = userInfo[AppConfiguration.UserActivity.taskColorUserInfoKey] as? Int
        
        assert(rawColor == nil || 0...5 ~= rawColor!, "The `userInfo` dictionary provided to \(__FUNCTION__) contains an invalid value for `color`: \(rawColor).")
        
        // Unwrap the `rawColor` value and construct a `Task.Color` from it.
        taskColor = Task.Color(rawValue: rawColor!)!
    }
    
    /**
        Initializes an `AppLaunchContext` instance with the color and URL designated by the tasker:// URL.
        
        :param: taskerURL The URL adhering to the tasker:// scheme providing the file URL and task color to launch to.
    */
    init(taskerURL: NSURL) {
        assert(taskerURL.scheme != nil && taskerURL.scheme! == AppConfiguration.TasksScheme.name, "Non-tasker URL provided to \(__FUNCTION__).")
        
        assert(taskerURL.path != nil, "URL provided to \(__FUNCTION__) is missing `path`.")
        
        // Construct a file URL from the path of the tasker:// URL.
        taskURL = NSURL(fileURLWithPath: taskerURL.path!, isDirectory: false)!
        
        // Extract the query items to initialize the `taskColor` property from the `color` query item.
        let urlComponents = NSURLComponents(URL: taskerURL, resolvingAgainstBaseURL: false)!
        let queryItems = urlComponents.queryItems as! [NSURLQueryItem]
        
        // Filter down to only the `color` query items. There should only be one.
        let colorQueryItems = queryItems.filter { $0.name == AppConfiguration.TasksScheme.colorQueryKey }
        
        assert(colorQueryItems.count == 1, "URL provided to \(__FUNCTION__) should contain only one `color` query item.")
        let colorQueryItem = colorQueryItems.first!
        
        // Obtain a `rawColor` value by converting the `String` `value` of the query item to an `Int`.
        let rawColor = colorQueryItem.value?.toInt()
        
        assert(rawColor != nil || 0...5 ~= rawColor!, "URL provided to \(__FUNCTION__) contains an invalid value for `color`: \(colorQueryItem.value).")

        // Unwrap the `rawColor` value and construct a `Task.Color` from it.
        taskColor = Task.Color(rawValue: rawColor!)!
    }
}
