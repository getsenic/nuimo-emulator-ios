//
//  ViewController.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var onOffStateLabel: UILabel!
    @IBOutlet weak var gestureView: UIView!
    @IBOutlet weak var dialView: DialView!
    @IBOutlet weak var ledView: LEDView!
    @IBOutlet weak var ledViewWidthLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var ledViewHeightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var flySensor: UIView!
    @IBOutlet weak var flySensorWidthLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var flySensorHeightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var flySensorTopLayoutConstraint: NSLayoutConstraint!

    fileprivate var nuimo: Nuimo = Nuimo()
    fileprivate var previousDialValue: CGFloat = 0.0
    fileprivate var isFirstDragValue = false
    fileprivate var ledFadeOutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        nuimo(nuimo, didChangeOnState: false)
        nuimo.delegate = self
        nuimo.powerOn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        gestureView.layoutSubviews()
        let nuimoSize = min(dialView.frame.width, dialView.frame.height)

        dialView.ringSize = nuimoSize * 0.11
        dialView.handleSize = dialView.ringSize * 1.5

        let ledViewSize = nuimoSize * 0.2
        ledView.superview?.layoutSubviews()
        ledView.ledSize = ledViewSize * 0.09
        ledViewWidthLayoutConstraint.constant = ledViewSize
        ledViewHeightLayoutConstraint.constant = ledViewSize
        ledView.setNeedsLayout()

        let flySensorTopOffset = dialView.frame.height > dialView.frame.width
            ? (dialView.frame.height - dialView.frame.width) / 2
            : 0
        flySensorWidthLayoutConstraint.constant = nuimoSize * 0.03
        flySensorHeightLayoutConstraint.constant = nuimoSize * 0.1
        flySensorTopLayoutConstraint.constant = flySensorTopOffset + dialView.handleSize * 1.2
        flySensor.layer.cornerRadius = flySensorWidthLayoutConstraint.constant / 2.0

        dialView.setNeedsLayout()
    }

    @IBAction func didPerformTapGesture(_ sender: UITapGestureRecognizer) {
        nuimo.pressButton()
        nuimo.releaseButton()
    }
    
    @IBAction func didPerformSwipeGesture(_ sender: UISwipeGestureRecognizer) {
        nuimo.swipe(NuimoSwipeDirection(swipeDirection: sender.direction))
    }

    fileprivate func displayLEDMatrix(_ matrix: NuimoLEDMatrix) {
        ledFadeOutTimer?.invalidate()
        ledView.leds = matrix.leds

        UIView.animate(withDuration: 0.4) { self.ledView.alpha = CGFloat(matrix.brightness) }
        if matrix.duration > 0 {
            ledFadeOutTimer = Timer.schedule(delay: matrix.duration) { _ in
                UIView.animate(withDuration: 1.0, animations: { self.ledView.alpha = 0 })
            }
        }
    }
}

extension ViewController: DialViewDelegate {
    func dialView(_ dialView: DialView, didChangeValue value: CGFloat) {
        defer {
            isFirstDragValue = false
            previousDialValue = value
        }
        guard previousDialValue != value else { return }
        guard !isFirstDragValue else { return }

        var delta = Double(value - previousDialValue)
        if delta > 0.5 {
            delta = 1 - delta
        }
        else if delta < -0.5 {
            delta = 1 + delta
        }
        nuimo.rotate(delta)
    }

    func dialViewDidStartDragging(_ dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.isEnabled = false }
        previousDialValue = dialView.value
        isFirstDragValue = true
    }

    func dialViewDidEndDragging(_ dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.isEnabled = true }
    }
}

extension ViewController: NuimoDelegate{
    func nuimo(_ nuimo: Nuimo, didChangeOnState on: Bool) {
        let onOffText = on
            ? "Nuimo is On\nDisable bluetooth to power off Nuimo"
            : "Nuimo is Off\nEnable bluetooth to power on Nuimo"
        onOffStateLabel.attributedText = NSMutableAttributedString(string: onOffText).then {
            $0.addAttribute(NSFontAttributeName, value: UIFont(name: "OpenSans-Bold", size: onOffStateLabel.font!.pointSize)!, range: NSRange(location: 0, length: (onOffText as NSString).range(of: "\n").location))
        }
        dialView.isEnabled = on
        ledView.alpha = 0.0
        if on { displayLEDMatrix(NuimoLEDMatrix.powerOn) }
    }

    func nuimo(_ nuimo: Nuimo, didReceiveLEDMatrix ledMatrix: NuimoLEDMatrix) {
        displayLEDMatrix(ledMatrix)
    }
}

extension NuimoSwipeDirection {
    fileprivate static let map: [UISwipeGestureRecognizerDirection : NuimoSwipeDirection] = [
        .left  : .left,
        .right : .right,
        .up    : .up,
        .down  : .down
    ]

    init(swipeDirection: UISwipeGestureRecognizerDirection) {
        self = NuimoSwipeDirection.map[swipeDirection]!
    }
}

extension UISwipeGestureRecognizerDirection : Hashable {
    public var hashValue: Int { get { return Int(self.rawValue) } }
}

extension NuimoLEDMatrix {
    static let powerOn = NuimoLEDMatrix(leds: [
        0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, 1, 0, 1, 1, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1,
        0, 1, 1, 1, 1, 1, 1, 1, 0,
        0, 0, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 1, 1, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0
    ].map{ $0 > 0 }, brightness: 1.0, duration: 2.0)
}

extension Timer {
    class func schedule(delay: TimeInterval, handler: @escaping ((Timer?) -> Void)) -> Timer! {
        let fireDate = CFAbsoluteTimeGetCurrent() + delay
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, handler)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, CFRunLoopMode.commonModes)
        return timer
    }
}
