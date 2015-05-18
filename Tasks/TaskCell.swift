//
//  TaskCell.swift
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
//
//

import UIKit

class TaskCell: UITableViewCell {
    // MARK: Properties

    @IBOutlet weak var label: UILabel!

    @IBOutlet weak var taskColorView: UIView!
    
    override func setHighlighted(highlighted: Bool, animated: Bool) {
        let color = taskColorView.backgroundColor!
        
        super.setHighlighted(highlighted, animated: animated)
        
        // Reset the background color for the task color; the default implementation makes it clear.
        taskColorView.backgroundColor = color
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        let color = taskColorView.backgroundColor!
        
        super.setSelected(selected, animated: animated)
        
        // Reset the background color for the task color; the default implementation makes it clear.
        taskColorView.backgroundColor = color
        
        // Ensure that tapping on a selected cell doesn't re-trigger the display of the document.
        userInteractionEnabled = !selected
    }
}
