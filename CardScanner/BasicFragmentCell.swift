//
//  BasicFragmentCell.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/15.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

class BasicFragmentCell: UITableViewCell {
    @IBOutlet weak var contentTextField: UITextField!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentTextField.text = nil
    }
}
