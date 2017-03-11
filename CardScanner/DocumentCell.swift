//
//  DocumentCell.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/15.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

class DocumentCell: UITableViewCell {
    @IBOutlet weak var backgroundImageView: UIImageView?
    @IBOutlet weak var placeholderImageView: UIImageView?
    @IBOutlet weak var documentView: DocumentView?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var subtitleLabel: UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if let layer = backgroundImageView?.layer {
            layer.backgroundColor = UIColor.white.cgColor
            layer.masksToBounds = false
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 0)
            layer.shadowOpacity = 0.5
            layer.shadowRadius = 4
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let backgroundImageView = self.backgroundImageView {
            let layer = backgroundImageView.layer
            layer.shadowPath = UIBezierPath(rect: backgroundImageView.bounds).cgPath
        }
    }
}
