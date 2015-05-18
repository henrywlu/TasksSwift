/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `TaskItem` class represents the text and completion state of a single item in the task.
*/

import Foundation

/**
    A `TaskItem` object is composed of a text property, a completion status, and an underlying opaque identity
    that distinguishes one `TaskItem` object from another. `TaskItem` objects are copyable and archivable.
    To ensure that the `TaskItem` class is unarchivable from an instance that was archived in the
    Objective-C version of Tasks, the `TaskItem` class declaration is annotated with @objc(AAPLTaskItem).
    This annotation ensures that the runtime name of the `TaskItem` class is the same as the
    `AAPLTaskItem` class defined in the Objective-C version of the app. It also allows the Objective-C
    version of Tasks to unarchive a `TaskItem` instance that was archived in the Swift version.
*/
@objc(AAPLTaskItem)
final public class TaskItem: NSObject, NSCoding, NSCopying, DebugPrintable {
    // MARK: Types
    
    /**
        String constants that are used to archive the stored properties of a `TaskItem`. These
        constants are used to help implement `NSCoding`.
    */
    private struct SerializationKeys {
        static let text = "text"
        static let uuid = "uuid"
        static let complete = "completed"
    }
    
    // MARK: Properties
    
    /// The text content for a `TaskItem`.
    public var text: String
    
    /// Whether or not this `TaskItem` is complete.
    public var isComplete: Bool
    
    /// An underlying identifier to distinguish one `TaskItem` from another.
    private var UUID: NSUUID
    
    // MARK: Initializers
    
    /**
        Initializes a `TaskItem` instance with the designated text, completion state, and UUID. This
        is the designated initializer for `TaskItem`. All other initializers are convenience initializers.
        However, this is the only private initializer.
        
        :param: text The intended text content of the task item.
        :param: complete The item's initial completion state.
        :param: UUID The item's initial UUID.
    */
    private init(text: String, complete: Bool, UUID: NSUUID) {
        self.text = text
        self.isComplete = complete
        self.UUID = UUID
    }
    
    /**
        Initializes a `TaskItem` instance with the designated text and completion state.
        
        :param: text The text content of the task item.
        :param: complete The item's initial completion state.
    */
    public convenience init(text: String, complete: Bool) {
        self.init(text: text, complete: complete, UUID: NSUUID())
    }
    
    /**
        Initializes a `TaskItem` instance with the designated text and a default value for `isComplete`.
        The default value for `isComplete` is false.
    
        :param: text The intended text content of the task item.
    */
    public convenience init(text: String) {
        self.init(text: text, complete: false)
    }
    
    // MARK: NSCopying
    
    public func copyWithZone(zone: NSZone) -> AnyObject  {
        return TaskItem(text: text, complete: isComplete, UUID: UUID)
    }
    
    // MARK: NSCoding
    
    public required init(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObjectForKey(SerializationKeys.text) as! String
        isComplete = aDecoder.decodeBoolForKey(SerializationKeys.complete)
        UUID = aDecoder.decodeObjectForKey(SerializationKeys.uuid) as! NSUUID
    }
    
    public func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(text, forKey: SerializationKeys.text)
        encoder.encodeBool(isComplete, forKey: SerializationKeys.complete)
        encoder.encodeObject(UUID, forKey: SerializationKeys.uuid)
    }
    
    /**
        Resets the underlying identity of the `TaskItem`. If a copy of this item is made, and a call
        to refreshIdentity() is made afterward, the items will no longer be equal.
    */
    public func refreshIdentity() {
        UUID = NSUUID()
    }
    
    // MARK: Overrides
    
    /**
        Overrides NSObject's isEqual(_:) instance method to return whether or not the task item is
        equal to another task item. A `TaskItem` is considered to be equal to another `TaskItem` if
        the underyling identities of the two task items are equal.

        :param: object Any object, or nil.
        
        :returns: `true` if the object is a `TaskItem` and it has the same underlying identity as the
                  receiving instance. `false` otherwise.
    */
    override public func isEqual(object: AnyObject?) -> Bool {
        if let item = object as? TaskItem {
            return UUID == item.UUID
        }
        
        return false
    }
    
    // MARK: DebugPrintable
    
    public override var debugDescription: String {
        return "\"\(text)\""
    }
}
