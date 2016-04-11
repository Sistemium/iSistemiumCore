//
//  STMThreeLinesAndCheckboxTVCell.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 25/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import UIKit

class STMThreeLinesAndCheckboxTVCell: STMTableViewCell, STMTDMCell{
    
    @IBOutlet weak var titleLabel:UILabel?
    @IBOutlet weak var detailLabel:UILabel?
    @IBOutlet weak var messageLabel:UILabel?
    @IBOutlet weak var checkboxView:UIView!
    var heightLimiter:CGFloat?{
        get{
            for subview in contentView.subviews {
                for constraint in subview.constraints as [NSLayoutConstraint] {
                    if constraint.identifier == "heightLimiter" {
                        return constraint.constant
                    }
                }
            }
            return nil
        }
        set{
            for subview in contentView.subviews {
                for constraint in subview.constraints as [NSLayoutConstraint] {
                    if constraint.identifier == "heightLimiter" {
                        constraint.constant = newValue ?? 0
                    }
                }
            }
        }
    }

}
