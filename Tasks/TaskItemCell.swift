//
//  TaskItemCell.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//
    
//    Abstract:
//    A custom cell used to display a task item or the row used to create a new item.


import UIKit
import TasksKit

class TaskItemCell: UITableViewCell {
    // MARK: Properties

    @IBOutlet weak var textField: UITextField!
    
    @IBOutlet weak var checkBox: CheckBox!
    
    var isComplete: Bool = false {
        didSet {
            textField.enabled = !isComplete
            checkBox.isChecked = isComplete
            
            textField.textColor = isComplete ? UIColor.lightGrayColor() : UIColor.darkTextColor()
        }
    }
}
