/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    A custom check box used in the tasks. It supports designing live in Interface Builder.
*/

import UIKit

@IBDesignable public class CheckBox: UIControl {
    // MARK: Properties
    
    @IBInspectable public var isChecked: Bool {
        get {
            return checkBoxLayer.isChecked
        }
        
        set {
            checkBoxLayer.isChecked = newValue
        }
    }

    @IBInspectable public var strokeFactor: CGFloat {
        set {
            checkBoxLayer.strokeFactor = newValue
        }

        get {
            return checkBoxLayer.strokeFactor
        }
    }
    
    @IBInspectable public var insetFactor: CGFloat {
        set {
            checkBoxLayer.insetFactor = newValue
        }

        get {
            return checkBoxLayer.insetFactor
        }
    }
    
    @IBInspectable public var markInsetFactor: CGFloat {
        set {
            checkBoxLayer.markInsetFactor = newValue
        }
    
        get {
            return checkBoxLayer.markInsetFactor
        }
    }
    
    // MARK: Overrides
    
    override public func didMoveToWindow() {
        if let window = window {
            contentScaleFactor = window.screen.scale
        }
    }

    override public class func layerClass() -> AnyClass {
        return CheckBoxLayer.self
    }
    
    override public func tintColorDidChange() {
        super.tintColorDidChange()
        
        checkBoxLayer.tintColor = tintColor.CGColor
    }

    // MARK: Convenience
    
    var checkBoxLayer: CheckBoxLayer {
        return layer as! CheckBoxLayer
    }
}
