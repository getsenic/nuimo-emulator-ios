//
//  ViewController.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

class ViewController: UIViewController, DialViewDelegate, NuimoDelegate {

    @IBOutlet weak var gestureView: UIView!
    @IBOutlet weak var dialView: DialView!
    @IBOutlet weak var ledView: LEDView!
    @IBOutlet weak var ledViewWidthLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var ledViewHeightLayoutConstraint: NSLayoutConstraint!

    private lazy var nuimo: Nuimo = Nuimo().then{ $0.delegate = self }
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
        dialView.ringSize = min(dialView.frame.width, dialView.frame.height) * 0.1
        dialView.knobSize = self.dialView.ringSize * 1.5

        let ledViewSize = min(dialView.frame.width, dialView.frame.height) * 0.25
        ledView.superview?.layoutSubviews()
        ledView.ledSize = ledViewSize * 0.09
        ledViewWidthLayoutConstraint.constant = ledViewSize
        ledViewHeightLayoutConstraint.constant = ledViewSize
        ledView.setNeedsLayout()
    }

    @IBAction func onOffSwitchDidChangeValue(sender: UISwitch) {
        sender.on
            ? nuimo.powerOn()
            : nuimo.powerOff()
    }

    //MARK: DialViewDelegate

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

    //MARK: NuimoDelegate
    func nuimo(nuimo: Nuimo, didReceiveLEDMatrix ledMatrix: NuimoLEDMatrix) {
        ledView.leds = ledMatrix.leds
        //TODO: Apply brightness and duration
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
