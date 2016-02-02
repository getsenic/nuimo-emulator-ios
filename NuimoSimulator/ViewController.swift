//
//  ViewController.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

class ViewController: UIViewController, DialViewDelegate {

    @IBOutlet weak var gestureView: UIView!

    @IBAction func didPerformTapGesture(sender: UITapGestureRecognizer) {
        print("TAP")
    }
    
    @IBAction func didPerformSwipeGesture(sender: UISwipeGestureRecognizer) {
        print(sender.direction)
    }

    func dialView(dialView: DialView, didUpdatePosition position: CGFloat) {
        print(position)
    }

    func dialViewDidStartDragging(dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.enabled = false }
    }

    func dialViewDidEndDragging(dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.enabled = true }
    }
}
