//
//  AppDelegate.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//
import UIKit
import TasksKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    // MARK: Types
    
    struct MainStoryboard {
        static let name = "Main"
        
        struct Identifiers {
            static let emptyViewController = "emptyViewController"
        }
    }

    // MARK: Properties

    var window: UIWindow?

    var tasksController: TasksController!
    
    /**
        A private, local queue used to ensure serialized access to Cloud containers during application
        startup.
    */
    let appDelegateQueue = dispatch_queue_create("com.locust123.tasker.appdelegate", DISPATCH_QUEUE_SERIAL)

    // MARK: View Controller Accessor Convenience
    
    /**
        The root view controller of the window will always be a `UISplitViewController`. This is set up
        in the main storyboard.
    */
    var splitViewController: UISplitViewController {
        return window!.rootViewController as! UISplitViewController
    }

    /// The primary view controller of the split view controller defined in the main storyboard.
    var primaryViewController: UINavigationController {
        return splitViewController.viewControllers.first as! UINavigationController
    }
    
    /**
        The view controller that displays the task of documents. If it's not visible, then this value
        is `nil`.
    */
    var taskDocumentsViewController: TaskDocumentsViewController? {
        return primaryViewController.viewControllers.first as? TaskDocumentsViewController
    }
    
    // MARK: UIApplicationDelegate
    
    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        let appConfiguration = AppConfiguration.sharedConfiguration
        if appConfiguration.isCloudAvailable {
            /*
                Ensure the app sandbox is extended to include the default container. Perform this action on the
                `AppDelegate`'s serial queue so that actions dependent on the extension always follow it.
            */
            dispatch_async(appDelegateQueue) {
                // The initial call extends the sandbox. No need to capture the URL.
                NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(nil)
                
                return
            }
        }
        
        return true
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Observe changes to the user's iCloud account status (account changed, logged out, etc...).
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUbiquityIdentityDidChangeNotification:", name: NSUbiquityIdentityDidChangeNotification, object: nil)
        
        // Provide default tasks from the app's bundle on first launch.
        AppConfiguration.sharedConfiguration.runHandlerOnFirstLaunch {
            TaskUtilities.copyInitialTasks()
        }

        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .AllVisible
        
        // Configure the detail controller in the `UISplitViewController` at the root of the view hierarchy.
        let navigationController = splitViewController.viewControllers.last as! UINavigationController
        navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        navigationController.topViewController.navigationItem.leftItemsSupplementBackButton = true
        
        return true
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Make sure that user storage preferences are set up after the app sandbox is extended. See `application(_:, willFinishLaunchingWithOptions:)` above.
        dispatch_async(appDelegateQueue) {
            self.setupUserStoragePreferences()
        }
    }
    
    func application(_: UIApplication, continueUserActivity: NSUserActivity, restorationHandler: [AnyObject]! -> Void) -> Bool {
        // Tasks only supports a single user activity type; if you support more than one the type is available from the `continueUserActivity` parameter.
        if let taskDocumentsViewController = taskDocumentsViewController {
            // Make sure that user activity continuation occurs after the app sandbox is extended. See `application(_:, willFinishLaunchingWithOptions:)` above.
            dispatch_async(appDelegateQueue) {
                restorationHandler([taskDocumentsViewController])
            }
            
            return true
        }
        
        return false
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        // Tasks currently only opens URLs of the Tasks scheme type.
        if url.scheme == AppConfiguration.TasksScheme.name {
            // Obtain an app launch context from the provided tasker:// URL and configure the view controller with it.
            let launchContext = AppLaunchContext(taskerURL: url)
            
            if let taskDocumentsViewController = taskDocumentsViewController {
                // Make sure that URL opening is handled after the app sandbox is extended. See `application(_:, willFinishLaunchingWithOptions:)` above.
                dispatch_async(appDelegateQueue) {
                    taskDocumentsViewController.configureViewControllerWithLaunchContext(launchContext)
                }
                
                return true
            }
        }
        
        return false
    }
    
    // MARK: UISplitViewControllerDelegate

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController _: UIViewController) -> Bool {
        /*
            In a regular width size class, Tasks displays a split view controller with a navigation controller
            displayed in both the master and detail areas.
            If there's a task that's currently selected, it should be on top of the stack when collapsed. 
            Ensuring that the navigation bar takes on the appearance of the selected task requires the 
            transfer of the configuration of the navigation controller that was shown in the detail area.
        */
        if secondaryViewController is UINavigationController && (secondaryViewController as! UINavigationController).topViewController is TaskViewController {
            // Obtain a reference to the navigation controller currently displayed in the detail area.
            let secondaryNavigationController = secondaryViewController as! UINavigationController
            
            // Transfer the settings for the `navigationBar` and the `toolbar` to the main navigation controller.
            primaryViewController.navigationBar.titleTextAttributes = secondaryNavigationController.navigationBar.titleTextAttributes
            primaryViewController.navigationBar.tintColor = secondaryNavigationController.navigationBar.tintColor
            primaryViewController.toolbar?.tintColor = secondaryNavigationController.toolbar?.tintColor
            
            return false
        }
        
        return true
    }
    
    func splitViewController(splitViewController: UISplitViewController, separateSecondaryViewControllerFromPrimaryViewController _: UIViewController) -> UIViewController? {
        /*
            In this delegate method, the reverse of the collapsing procedure described above needs to be
            carried out if a task is being displayed. The appropriate controller to display in the detail area
            should be returned. If not, the standard behavior is obtained by returning nil.
        */
        if primaryViewController.topViewController is UINavigationController && (primaryViewController.topViewController as! UINavigationController).topViewController is TaskViewController {
            // Obtain a reference to the navigation controller containing the task controller to be separated.
            let secondaryViewController = primaryViewController.popViewControllerAnimated(false) as! UINavigationController
            let taskViewController = secondaryViewController.topViewController as! TaskViewController
            
            // Obtain the `textAttributes` and `tintColor` to setup the separated navigation controller.    
            let textAttributes = taskViewController.textAttributes
            let tintColor = taskViewController.taskPresenter.color.colorValue
            
            // Transfer the settings for the `navigationBar` and the `toolbar` to the detail navigation controller.
            secondaryViewController.navigationBar.titleTextAttributes = textAttributes
            secondaryViewController.navigationBar.tintColor = tintColor
            secondaryViewController.toolbar?.tintColor = tintColor
            
            // Display a bar button on the left to allow the user to expand or collapse the main area, similar to Mail.
            secondaryViewController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
            
            return secondaryViewController
        }
        
        return nil
    }
    
    // MARK: Notifications
    
    func handleUbiquityIdentityDidChangeNotification(notification: NSNotification) {
        primaryViewController.popToRootViewControllerAnimated(true)
        
        setupUserStoragePreferences()
    }
    
    // MARK: User Storage Preferences
    
    func setupUserStoragePreferences() {
        let storageState = AppConfiguration.sharedConfiguration.storageState
    
        /*
            Check to see if the account has changed since the last time the method was called. If it has, let
            the user know that their documents have changed. If they've already chosen local storage (i.e. not
            iCloud), don't notify them since there's no impact.
        */
        if storageState.accountDidChange && storageState.storageOption == .Cloud {
            notifyUserOfAccountChange(storageState)
            // Return early. State resolution will take place after the user acknowledges the change.
            return
        }

        resolveStateForUserStorageState(storageState)
    }
    
    func resolveStateForUserStorageState(storageState: StorageState) {
        if storageState.cloudAvailable {
            if storageState.storageOption == .NotSet  || (storageState.storageOption == .Local && storageState.accountDidChange) {
                // iCloud is available, but we need to ask the user what they prefer.
                promptUserForStorageOption()
            }
            else {
                /*
                    The user has already selected a specific storage option. Set up the tasks controller to use
                    that storage option.
                */
                configureTasksController(accountChanged: storageState.accountDidChange)
            }
        }
        else {
            /* 
                iCloud is not available, so we'll reset the storage option and configure the task controller.
                The next time that the user signs in with an iCloud account, he or she can change provide their
                desired storage option.
            */
            if storageState.storageOption != .NotSet {
                AppConfiguration.sharedConfiguration.storageOption = .NotSet
            }
            
            configureTasksController(accountChanged: storageState.accountDidChange)
        }
    }
    
    // MARK: Alerts
    
    func notifyUserOfAccountChange(storageState: StorageState) {
        /*
            Copy a 'Today' task from the bundle to the local documents directory if a 'Today' task doesn't exist.
            This provides more context for the user than no tasks and ensures the user always has a 'Today' task (a
            design choice made in Tasks).
        */
        if !storageState.cloudAvailable {
            TaskUtilities.copyTodayTask()
        }
        
        let title = NSLocalizedString("Sign Out of iCloud", comment: "")
        let message = NSLocalizedString("You have signed out of the iCloud account previously used to store documents. Sign back in with that account to access those documents.", comment: "")
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let signedOutController = UIAlertController(title: title, message: message, preferredStyle: .Alert)

        let action = UIAlertAction(title: okActionTitle, style: .Cancel) { _ in
            self.resolveStateForUserStorageState(storageState)
        }
        signedOutController.addAction(action)
        
        taskDocumentsViewController?.presentViewController(signedOutController, animated: true, completion: nil)
    }
    
    func promptUserForStorageOption() {
        let title = NSLocalizedString("Choose Storage Option", comment: "")
        let message = NSLocalizedString("Do you want to store documents in iCloud or only on this device?", comment: "")
        let localOnlyActionTitle = NSLocalizedString("Local Only", comment: "")
        let cloudActionTitle = NSLocalizedString("iCloud", comment: "")
        
        let storageController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let localOption = UIAlertAction(title: localOnlyActionTitle, style: .Default) { localAction in
            AppConfiguration.sharedConfiguration.storageOption = .Local

            self.configureTasksController(accountChanged: true)
        }
        storageController.addAction(localOption)
        
        let cloudOption = UIAlertAction(title: cloudActionTitle, style: .Default) { cloudAction in
            AppConfiguration.sharedConfiguration.storageOption = .Cloud

            self.configureTasksController(accountChanged: true) {
                TaskUtilities.migrateLocalTasksToCloud()
            }
        }
        storageController.addAction(cloudOption)
        
        taskDocumentsViewController?.presentViewController(storageController, animated: true, completion: nil)
    }
   
    // MARK: Convenience
    
    func configureTasksController(#accountChanged: Bool, storageOptionChangeHandler: (Void -> Void)? = nil) {
        if tasksController != nil && !accountChanged {
            // The current controller is correct. There is no need to reconfigure it.
            return
        }

        if tasksController == nil {
            // There is currently no tasks controller. Configure an appropriate one for the current configuration.
            tasksController = AppConfiguration.sharedConfiguration.tasksControllerForCurrentConfigurationWithPathExtension(AppConfiguration.taskerFileExtension, firstQueryHandler: storageOptionChangeHandler)
            
            // Ensure that this controller is passed along to the `TaskDocumentsViewController`.
            taskDocumentsViewController?.tasksController = tasksController
            
            tasksController.startSearching()
        }
        else if accountChanged {
            // A tasks controller is configured; however, it needs to have its coordinator updated based on the account change. 
            tasksController.taskCoordinator = AppConfiguration.sharedConfiguration.taskCoordinatorForCurrentConfigurationWithLastPathComponent(AppConfiguration.taskerFileExtension, firstQueryHandler: storageOptionChangeHandler)
        }
    }
}

