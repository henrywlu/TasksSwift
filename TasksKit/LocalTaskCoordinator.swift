/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `LocalTaskCoordinator` class handles querying for and interacting with tasks stored as local files.
*/

import Foundation

@objc public class LocalTaskCoordinator: TaskCoordinator, DirectoryMonitorDelegate {
    // MARK: Properties

    public weak var delegate: TaskCoordinatorDelegate?
    
    /**
        A GCD based monitor used to observe changes to the local documents directory.
    */
    private var directoryMonitor: DirectoryMonitor
    
    /**
        Closure executed after the first update provided by the coordinator regarding tracked
        URLs.
    */
    private var firstQueryUpdateHandler: (Void -> Void)?

    private let predicate: NSPredicate
    
    private var currentLocalContents: [NSURL] = []

    // MARK: Initializers
    
    public init(pathExtension: String, firstQueryUpdateHandler: (Void -> Void)? = nil) {
        directoryMonitor = DirectoryMonitor(URL: TaskUtilities.localDocumentsDirectory)
        
        predicate = NSPredicate(format: "(pathExtension = %@)", argumentArray: [pathExtension])
        self.firstQueryUpdateHandler = firstQueryUpdateHandler
        
        directoryMonitor.delegate = self
    }
    
    public init(lastPathComponent: String, firstQueryUpdateHandler: (Void -> Void)? = nil) {
        directoryMonitor = DirectoryMonitor(URL: TaskUtilities.localDocumentsDirectory)
        
        predicate = NSPredicate(format: "(lastPathComponent = %@)", argumentArray: [lastPathComponent])
        self.firstQueryUpdateHandler = firstQueryUpdateHandler
        
        directoryMonitor.delegate = self
    }
    
    // MARK: TaskCoordinator
    
    public func startQuery() {
        processChangeToLocalDocumentsDirectory()
        
        directoryMonitor.startMonitoring()
    }
    
    public func stopQuery() {
        directoryMonitor.stopMonitoring()
    }
    
    public func removeTaskAtURL(URL: NSURL) {
        TaskUtilities.removeTaskAtURL(URL) { error in
            if let realError = error {
                self.delegate?.taskCoordinatorDidFailRemovingTaskAtURL(URL, withError: realError)
            }
            else {
                self.delegate?.taskCoordinatorDidUpdateContents(insertedURLs: [], removedURLs: [URL], updatedURLs: [])
            }
        }
    }
    
    public func createURLForTask(task: Task, withName name: String) {
        let documentURL = documentURLForName(name)

        TaskUtilities.createTask(task, atURL: documentURL) { error in
            if let realError = error {
                self.delegate?.taskCoordinatorDidFailCreatingTaskAtURL(documentURL, withError: realError)
            }
            else {
                self.delegate?.taskCoordinatorDidUpdateContents(insertedURLs: [documentURL], removedURLs: [], updatedURLs: [])
            }
        }
    }

    public func canCreateTaskWithName(name: String) -> Bool {
        if name.isEmpty {
            return false
        }

        let documentURL = documentURLForName(name)

        return !NSFileManager.defaultManager().fileExistsAtPath(documentURL.path!)
    }
    
    // MARK: DirectoryMonitorDelegate
    
    func directoryMonitorDidObserveChange(directoryMonitor: DirectoryMonitor) {
        processChangeToLocalDocumentsDirectory()
    }
    
    // MARK: Convenience
    
    func processChangeToLocalDocumentsDirectory() {
        let defaultQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        dispatch_async(defaultQueue) {
            let fileManager = NSFileManager.defaultManager()
            
            // Fetch the task documents from container documents directory.
            let localDocumentURLs = fileManager.contentsOfDirectoryAtURL(TaskUtilities.localDocumentsDirectory, includingPropertiesForKeys: nil, options: .SkipsPackageDescendants, error: nil) as! [NSURL]
            
            var localTaskURLs = localDocumentURLs.filter { self.predicate.evaluateWithObject($0) }
            
            if !localTaskURLs.isEmpty {
                let insertedURLs = localTaskURLs.filter { !contains(self.currentLocalContents, $0) }
                let removedURLs = self.currentLocalContents.filter { !contains(localTaskURLs, $0) }
                
                self.delegate?.taskCoordinatorDidUpdateContents(insertedURLs: insertedURLs, removedURLs: removedURLs, updatedURLs: [])
                
                self.currentLocalContents = localTaskURLs
            }
            
            // Execute the `firstQueryUpdateHandler`, it will contain the closure from initialization on first update.
            if let handler = self.firstQueryUpdateHandler {
                handler()
                // Set `firstQueryUpdateHandler` to an empty closure so that the handler provided is only run on first update.
                self.firstQueryUpdateHandler = nil
            }
        }
    }
    
    private func documentURLForName(name: String) -> NSURL {
        let documentURLWithoutExtension = TaskUtilities.localDocumentsDirectory.URLByAppendingPathComponent(name)

        return documentURLWithoutExtension.URLByAppendingPathExtension(AppConfiguration.taskerFileExtension)
    }
}
