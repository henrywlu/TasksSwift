/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    The `Task` class manages a task of items and the color of the task.
*/

import Foundation

/**
    The `Task` class manages the color of a task and each `TaskItem` object. `Task` objects are copyable and
    archivable. `Task` objects are normally associated with an object that conforms to `TaskPresenterType`.
    This object manages how the task is presented, archived, and manipulated. To ensure that the `Task` class
    is unarchivable from an instance that was archived in the Objective-C version of Tasks, the `Task` class
    declaration is annotated with @objc(AAPLTask). This annotation ensures that the runtime name of the `Task`
    class is the same as the `AAPLTask` class defined in the Objective-C version of the app. It also allows 
    the Objective-C version of Tasks to unarchive a `Task` instance that was archived in the Swift version.
*/
@objc(AAPLTask)
final public class Task: NSObject, NSCoding, NSCopying, DebugPrintable {
    // MARK: Types
    
    /**
        String constants that are used to archive the stored properties of a `Task`. These constants
        are used to help implement `NSCoding`.
    */
    private struct SerializationKeys {
        static let items = "items"
        static let color = "color"
    }
    
    /**
        The possible colors a task can have. Because a task's color is specific to a `Task` object,
        it is represented by a nested type. The `Printable` representation of the enumeration is 
        the name of the value. For example, .Gray corresponds to "Gray".

        - Gray (default)
        - Blue
        - Green
        - Yellow
        - Orange
        - Red
    */
    public enum Color: Int, Printable {
        case Gray, Blue, Green, Yellow, Orange, Red
        
        // MARK: Properties

        public var name: String {
            switch self {
                case .Gray:     return "Gray"
                case .Blue:     return "Blue"
                case .Green:    return "Green"
                case .Orange:   return "Orange"
                case .Yellow:   return "Yellow"
                case .Red:      return "Red"
            }
        }

        // MARK: Printable
        
        public var description: String {
            return name
        }
    }
    
    // MARK: Properties
    
    /// The task's color. This property is stored when it is archived and read when it is unarchived.
    public var color: Color
    
    /// The task's items.
    public var items = [TaskItem]()
    
    // MARK: Initializers
    
    /**
        Initializes a `Task` instance with the designated color and items. The default color of a `Task` is
        gray.
        
        :param: color The intended color of the task.
        :param: items The items that represent the underlying task. The `Task` class copies the items
                      during initialization.
    */
    public init(color: Color = .Gray, items: [TaskItem] = []) {
        self.color = color
        
        self.items = items.map { $0.copy() as! TaskItem }
    }

    // MARK: NSCoding
    
    public required init(coder aDecoder: NSCoder) {
        items = aDecoder.decodeObjectForKey(SerializationKeys.items) as! [TaskItem]
        color = Color(rawValue: aDecoder.decodeIntegerForKey(SerializationKeys.color))!
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(items, forKey: SerializationKeys.items)
        aCoder.encodeInteger(color.rawValue, forKey: SerializationKeys.color)
    }
    
    // MARK: NSCopying
    
    public func copyWithZone(zone: NSZone) -> AnyObject  {
        return Task(color: color, items: items)
    }

    // MARK: Equality
    
    /**
        Overrides NSObject's isEqual(_:) instance method to return whether the task is equal to 
        another task. A `Task` is considered to be equal to another `Task` if its color and items
        are equal.
        
        :param: object Any object, or nil.
        
        :returns: `true` if the object is a `Task` and it has the same color and items as the receiving
                  instance. `false` otherwise.
    */
    override public func isEqual(object: AnyObject?) -> Bool {
        if let task = object as? Task {
            if color != task.color {
                return false
            }
            
            return items == task.items
        }
        
        return false
    }

    // MARK: DebugPrintable

    public override var debugDescription: String {
        return "{color: \(color), items: \(items)}"
    }
}
