//
//  ViewController.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBAction func didPerformTapGesture(sender: UITapGestureRecognizer) {
        print("TAP")
    }
    
    @IBAction func didPerformSwipeGesture(sender: UISwipeGestureRecognizer) {
        print(sender.direction)
    }
}

