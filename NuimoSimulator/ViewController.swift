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

    var nuimo = Nuimo()

    @IBAction func didPerformTapGesture(sender: UITapGestureRecognizer) {
        nuimo.pressButton()
        nuimo.releaseButton()
    }
    
    @IBAction func didPerformSwipeGesture(sender: UISwipeGestureRecognizer) {
        nuimo.swipe(NuimoSwipeDirection(swipeDirection: sender.direction))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dialView.superview?.layoutSubviews()
        self.dialView.knobSize = min(dialView.frame.width, dialView.frame.height) / 8.0
        self.dialView.ringSize = self.dialView.knobSize * 2.0 / 3.0
    }

    @IBAction func onOffSwitchDidChangeValue(sender: UISwitch) {
        sender.on
            ? nuimo.powerOn()
            : nuimo.powerOff()
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

extension NuimoSwipeDirection {
    private static let map: [UISwipeGestureRecognizerDirection : NuimoSwipeDirection] = [
        .Left  : .Left,
        .Right : .Right,
        .Up    : .Up,
        .Down  : .Down
    ]

    init(swipeDirection: UISwipeGestureRecognizerDirection) {
        self = NuimoSwipeDirection.map[swipeDirection]!
    }
}

extension UISwipeGestureRecognizerDirection : Hashable {
    public var hashValue: Int { get { return Int(self.rawValue) } }
}
