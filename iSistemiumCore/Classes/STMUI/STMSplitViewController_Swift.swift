//
//  STMSplitViewController.swift
//  iSistemium
//
//  Created by Edgar Jan Vuicik on 15/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

import UIKit

@available(iOS 8.0, *)
class STMSplitViewController_Swift: STMSplitViewController, UISplitViewControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .allVisible
        self.delegate = self
        //use this to config split size
        //minimumPrimaryColumnWidth = CGFloat(0.25)
        //preferredPrimaryColumnWidthFraction = CGFloat(0.25)
        //maximumPrimaryColumnWidth = view.bounds.size.width
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool{
        return true
    }
    
}
