//
//  TaskColorCell.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//

import UIKit
import TasksKit

/// Provides the ability to send a delegate a message about newly created task info objects.
@objc protocol TaskColorCellDelegate {
    func taskColorCellDidChangeSelectedColor(taskColorCell: TaskColorCell)
}

/**
    A UIView subclass that's used to test whether or not a `colorTap(_:)` action occurs from a view
    that we designate as color tappable (e.g. the "Color" label should not be tappable).
*/
class ColorTappableView: UIView {}

class TaskColorCell: UITableViewCell {
    // MARK: Properties

    @IBOutlet weak var gray: UIView!

    @IBOutlet weak var blue: UIView!
    
    @IBOutlet weak var green: UIView!
    
    @IBOutlet weak var yellow: UIView!
    
    @IBOutlet weak var orange: UIView!
    
    @IBOutlet weak var red: UIView!

    weak var delegate: TaskColorCellDelegate?
    
    var selectedColor = Task.Color.Gray

    // MARK: Configuration

    func configure() {
        // Set up a gesture recognizer to track taps on color views in the cell.
        let colorGesture = UITapGestureRecognizer(target: self, action: "colorTap:")
        colorGesture.numberOfTapsRequired = 1
        colorGesture.numberOfTouchesRequired = 1
        
        addGestureRecognizer(colorGesture)
    }
    
    // MARK: UITapGestureRecognizer Handling
    
    @IBAction func colorTap(tapGestureRecognizer: UITapGestureRecognizer) {
        if tapGestureRecognizer.state != .Ended {
            return
        }
        
        let tapLocation = tapGestureRecognizer.locationInView(contentView)

        // If the user tapped on a color (identified by its tag), notify the delegate.
        if let view = contentView.hitTest(tapLocation, withEvent: nil) as? ColorTappableView {
            selectedColor = Task.Color(rawValue: view.tag)!

            delegate?.taskColorCellDidChangeSelectedColor(self)
        }
    }
}
