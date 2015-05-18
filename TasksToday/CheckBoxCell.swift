/*
//  Tasks
//
//  Created by Henry W. Lu on 5/17/15.
    
    Abstract:
    A check box cell for the Today view.
*/

import UIKit
import TasksKit

class CheckBoxCell: UITableViewCell {
    // MARK: Properties

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var checkBox: CheckBox!
}
