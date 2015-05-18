/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    Handles application configuration logic and information.
*/

import Foundation

public typealias StorageState = (storageOption: AppConfiguration.Storage, accountDidChange: Bool, cloudAvailable: Bool)

public class AppConfiguration {
    // MARK: Types
    
    private struct Defaults {
        static let firstLaunchKey = "AppConfiguration.Defaults.firstLaunchKey"
        static let storageOptionKey = "AppConfiguration.Defaults.storageOptionKey"
        static let storedUbiquityIdentityToken = "AppConfiguration.Defaults.storedUbiquityIdentityToken"
    }
    
    // Keys used to store relevant task data in the userInfo dictionary of an NSUserActivity for continuation.
    public struct UserActivity {
        // The editing user activity is integrated into the ubiquitous UI/NSDocument architecture.
        public static let editing = "com.locust123.Tasks.editing"
        
        // The watch user activity is used to continue activities started on the watch on other devices.
        public static let watch = "com.locust123.Tasks.watch"
        
        public static let taskURLPathUserInfoKey = "taskURLPathUserInfoKey"
        public static let taskColorUserInfoKey = "taskColorUserInfoKey"
    }
    
    // Constants used in assembling and handling the custom tasker:// URL scheme.
    public struct TasksScheme {
        public static let name = "tasker"
        public static let colorQueryKey = "color"
    }
    
    /*
        The value of the `LISTER_BUNDLE_PREFIX` user-defined build setting is written to the Info.ptask file of
        every target in Swift version of the Tasks project. Specifically, the value of `LISTER_BUNDLE_PREFIX` 
        is used as the string value for a key of `AAPLTasksBundlePrefix`. This value is loaded from the target's
        bundle by the lazily evaluated static variable "prefix" from the nested "Bundle" struct below the first
        time that "Bundle.prefix" is accessed. This avoids the need for developers to edit both `LISTER_BUNDLE_PREFIX`
        and the code below. The value of `Bundle.prefix` is then used as part of an interpolated string to insert
        the user-defined value of `LISTER_BUNDLE_PREFIX` into several static string constants below.
    */
    private struct Bundle {
        static var prefix = NSBundle.mainBundle().objectForInfoDictionaryKey("AAPLTasksBundlePrefix") as! String
    }

    struct ApplicationGroups {
        static let primary = "group.\(Bundle.prefix).Tasks.Documents"
    }
    
    #if os(OSX)
    public struct App {
        public static let bundleIdentifier = "\(Bundle.prefix).TasksOSX"
    }
    #endif
    
    public struct Extensions {
        #if os(iOS)
        public static let widgetBundleIdentifier = "\(Bundle.prefix).Tasks.TasksToday"
        #elseif os(OSX)
        public static let widgetBundleIdentifier = "\(Bundle.prefix).Tasks.TasksTodayOSX"
        #endif
    }
    
    public enum Storage: Int {
        case NotSet = 0, Local, Cloud
    }
    
    public class var sharedConfiguration: AppConfiguration {
        struct Singleton {
            static let sharedAppConfiguration = AppConfiguration()
        }

        return Singleton.sharedAppConfiguration
    }
    
    public class var taskerUTI: String {
        return "com.locust123.Tasks"
    }
    
    public class var taskerFileExtension: String {
        return "task"
    }
    
    public class var defaultTasksDraftName: String {
        return NSLocalizedString("Task", comment: "")
    }
    
    public class var localizedTodayDocumentName: String {
        return NSLocalizedString("Today", comment: "The name of the Today task")
    }
    
    public class var localizedTodayDocumentNameAndExtension: String {
        return "\(localizedTodayDocumentName).\(taskerFileExtension)"
    }
    
    private var applicationUserDefaults: NSUserDefaults {
        return NSUserDefaults(suiteName: ApplicationGroups.primary)!
    }
    
    public private(set) var isFirstLaunch: Bool {
        get {
            registerDefaults()
            
            return applicationUserDefaults.boolForKey(Defaults.firstLaunchKey)
        }
        set {
            applicationUserDefaults.setBool(newValue, forKey: Defaults.firstLaunchKey)
        }
    }
    
    private func registerDefaults() {
        #if os(iOS)
            let defaultOptions: [NSObject: AnyObject] = [
                Defaults.firstLaunchKey: true,
                Defaults.storageOptionKey: Storage.NotSet.rawValue
            ]
        #elseif os(OSX)
            let defaultOptions: [NSObject: AnyObject] = [
                Defaults.firstLaunchKey: true
            ]
        #endif
        
        applicationUserDefaults.registerDefaults(defaultOptions)
    }
    
    public func runHandlerOnFirstLaunch(firstLaunchHandler: Void -> Void) {
        if isFirstLaunch {
            isFirstLaunch = false

            firstLaunchHandler()
        }
    }
    
    public var isCloudAvailable: Bool {
        return NSFileManager.defaultManager().ubiquityIdentityToken != nil
    }
    
    #if os(iOS)
    public var storageState: StorageState {
        return (storageOption, hasAccountChanged(), isCloudAvailable)
    }
    
    public var storageOption: Storage {
        get {
            let value = applicationUserDefaults.integerForKey(Defaults.storageOptionKey)
            
            return Storage(rawValue: value)!
        }

        set {
            applicationUserDefaults.setInteger(newValue.rawValue, forKey: Defaults.storageOptionKey)
        }
    }

    // MARK: Ubiquity Identity Token Handling (Account Change Info)
    
    public func hasAccountChanged() -> Bool {
        var hasChanged = false
        
        let currentToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? = NSFileManager.defaultManager().ubiquityIdentityToken
        let storedToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? = storedUbiquityIdentityToken
        
        let currentTokenNilStoredNonNil = currentToken == nil && storedToken != nil
        let storedTokenNilCurrentNonNil = currentToken != nil && storedToken == nil
        
        // Compare the tokens.
        let currentNotEqualStored = currentToken != nil && storedToken != nil && !currentToken!.isEqual(storedToken!)
        
        if currentTokenNilStoredNonNil || storedTokenNilCurrentNonNil || currentNotEqualStored {
            persistAccount()
            
            hasChanged = true
        }
        
        return hasChanged
    }

    private func persistAccount() {
        var defaults = applicationUserDefaults
        
        if let token = NSFileManager.defaultManager().ubiquityIdentityToken {
            let ubiquityIdentityTokenArchive = NSKeyedArchiver.archivedDataWithRootObject(token)
            
            defaults.setObject(ubiquityIdentityTokenArchive, forKey: Defaults.storedUbiquityIdentityToken)
        }
        else {
            defaults.removeObjectForKey(Defaults.storedUbiquityIdentityToken)
        }
    }
    
    // MARK: Convenience

    private var storedUbiquityIdentityToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? {
        var storedToken: protocol<NSCoding, NSCopying, NSObjectProtocol>?
        
        // Determine if the logged in iCloud account has changed since the user last launched the app.
        let archivedObject: AnyObject? = applicationUserDefaults.objectForKey(Defaults.storedUbiquityIdentityToken)
        
        if let ubiquityIdentityTokenArchive = archivedObject as? NSData {
            if let archivedObject = NSKeyedUnarchiver.unarchiveObjectWithData(ubiquityIdentityTokenArchive) as? protocol<NSCoding, NSCopying, NSObjectProtocol> {
                storedToken = archivedObject
            }
        }
        
        return storedToken
    }
    
    /**
        Returns a `TaskCoordinator` based on the current configuration that queries based on `pathExtension`.
        For example, if the user has chosen local storage, a local `TaskCoordinator` object will be returned.
    */
    public func taskCoordinatorForCurrentConfigurationWithPathExtension(pathExtension: String, firstQueryHandler: (Void -> Void)? = nil) -> TaskCoordinator {
        if AppConfiguration.sharedConfiguration.storageOption != .Cloud {
            // This will be called if the storage option is either `.Local` or `.NotSet`.
            return LocalTaskCoordinator(pathExtension: pathExtension, firstQueryUpdateHandler: firstQueryHandler)
        }
        else {
            return CloudTaskCoordinator(pathExtension: pathExtension, firstQueryUpdateHandler: firstQueryHandler)
        }
    }
    
    /**
        Returns a `TaskCoordinator` based on the current configuration that queries based on `lastPathComponent`.
        For example, if the user has chosen local storage, a local `TaskCoordinator` object will be returned.
    */
    public func taskCoordinatorForCurrentConfigurationWithLastPathComponent(lastPathComponent: String, firstQueryHandler: (Void -> Void)? = nil) -> TaskCoordinator {
        if AppConfiguration.sharedConfiguration.storageOption != .Cloud {
            // This will be called if the storage option is either `.Local` or `.NotSet`.
            return LocalTaskCoordinator(lastPathComponent: lastPathComponent, firstQueryUpdateHandler: firstQueryHandler)
        }
        else {
            return CloudTaskCoordinator(lastPathComponent: lastPathComponent, firstQueryUpdateHandler: firstQueryHandler)
        }
    }
    
    /**
        Returns a `TasksController` instance based on the current configuration. For example, if the user has
        chosen local storage, a `TasksController` object will be returned that uses a local task coordinator.
        `pathExtension` is passed down to the task coordinator to filter results.
    */
    public func tasksControllerForCurrentConfigurationWithPathExtension(pathExtension: String, firstQueryHandler: (Void -> Void)? = nil) -> TasksController {
        let taskCoordinator = taskCoordinatorForCurrentConfigurationWithPathExtension(pathExtension, firstQueryHandler: firstQueryHandler)
        
        return TasksController(taskCoordinator: taskCoordinator, delegateQueue: NSOperationQueue.mainQueue()) { lhs, rhs in
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == NSComparisonResult.OrderedAscending
        }
    }

    /**
        Returns a `TasksController` instance based on the current configuration. For example, if the user has
        chosen local storage, a `TasksController` object will be returned that uses a local task coordinator.
        `lastPathComponent` is passed down to the task coordinator to filter results.
    */
    public func tasksControllerForCurrentConfigurationWithLastPathComponent(lastPathComponent: String, firstQueryHandler: (Void -> Void)? = nil) -> TasksController {
        let taskCoordinator = taskCoordinatorForCurrentConfigurationWithLastPathComponent(lastPathComponent, firstQueryHandler: firstQueryHandler)
        
        return TasksController(taskCoordinator: taskCoordinator, delegateQueue: NSOperationQueue.mainQueue()) { lhs, rhs in
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == NSComparisonResult.OrderedAscending
        }
    }
    
    #endif
}