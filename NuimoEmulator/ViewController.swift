//
//  ViewController.swift
//  NuimoSimulator
//
//  Created by Lars on 27.01.16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

class ViewController: UIViewController, DialViewDelegate, NuimoDelegate {

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

    private var nuimo: Nuimo = Nuimo()
    private var previousDialValue: CGFloat = 0.0
    private var isFirstDragValue = false

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

    @IBAction func didPerformTapGesture(sender: UITapGestureRecognizer) {
        nuimo.pressButton()
        nuimo.releaseButton()
    }
    
    @IBAction func didPerformSwipeGesture(sender: UISwipeGestureRecognizer) {
        nuimo.swipe(NuimoSwipeDirection(swipeDirection: sender.direction))
    }

    private func displayLEDMatrix(matrix: NuimoLEDMatrix) {
        ledView.leds = matrix.leds
        //TODO: Apply brightness and duration
    }

    //MARK: DialViewDelegate

    func dialView(dialView: DialView, didChangeValue value: CGFloat) {
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

    func dialViewDidStartDragging(dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.enabled = false }
        previousDialValue = dialView.value
        isFirstDragValue = true
    }

    func dialViewDidEndDragging(dialView: DialView) {
        gestureView.gestureRecognizers?.forEach { $0.enabled = true }
    }

    //MARK: NuimoDelegate

    func nuimo(nuimo: Nuimo, didChangeOnState on: Bool) {
        onOffStateLabel.text = on
            ? "Nuimo is On. Disable bluetooth to power off Nuimo."
            : "Nuimo is Off. Enable bluetooth to power on Nuimo."
        dialView.enabled = on
        displayLEDMatrix(on
            ? NuimoLEDMatrix.powerOn
            : NuimoLEDMatrix.powerOff)
    }

    func nuimo(nuimo: Nuimo, didReceiveLEDMatrix ledMatrix: NuimoLEDMatrix) {
        displayLEDMatrix(ledMatrix)
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

    static let powerOff = NuimoLEDMatrix(leds: [], brightness: 0.0, duration: 0.0)
}
