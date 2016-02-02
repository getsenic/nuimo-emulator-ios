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
    @IBOutlet weak var dialView: DialView!

    @IBAction func didPerformTapGesture(sender: UITapGestureRecognizer) {
        print("TAP")
    }
    
    @IBAction func didPerformSwipeGesture(sender: UISwipeGestureRecognizer) {
        print(sender.direction)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dialView.superview?.layoutSubviews()
        self.dialView.knobSize = min(dialView.frame.width, dialView.frame.height) / 8.0
        self.dialView.ringSize = self.dialView.knobSize * 2.0 / 3.0
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
