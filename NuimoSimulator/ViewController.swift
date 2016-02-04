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

    private var nuimo = Nuimo()
    private var previousDialPosition: CGFloat = 0.0
    private var isFirstDragPosition = false

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
        self.dialView.ringSize = min(dialView.frame.width, dialView.frame.height) / 10.0
        self.dialView.knobSize = self.dialView.ringSize * 3.0 / 2.0

    }

    @IBAction func onOffSwitchDidChangeValue(sender: UISwitch) {
        sender.on
            ? nuimo.powerOn()
            : nuimo.powerOff()
    }

    func dialView(dialView: DialView, didUpdatePosition position: CGFloat) {
        defer {
            isFirstDragPosition = false
            previousDialPosition = position
        }
        guard previousDialPosition != position else { return }
        guard !isFirstDragPosition else { return }

        var delta = Double(position - previousDialPosition)
        if delta > 0.5 {
            delta = 1 - delta
        }
        else if delta < -0.5 {
            delta = 1 + delta
        }
        nuimo.rotate(delta)
    }

    func dialViewDidStartDragging(dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.enabled = false }
        previousDialPosition = dialView.position
        isFirstDragPosition = true
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
