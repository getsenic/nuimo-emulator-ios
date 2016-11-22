//
//  DialView.swift
//  NuimoSimulator
//
//  Created by Lars Blumberg on 2/1/16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

//TODO: Publish as Cocoa Pod with GIF animation on github showing how the value changes on rotating
@IBDesignable
class DialView : UIControl {
    @IBInspectable
    var ringColor: UIColor = UIColor(colorLiteralRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0) { didSet { setNeedsDisplay() } }
    @IBInspectable
    var knobColor: UIColor = UIColor(colorLiteralRed: 0.75, green: 0.75, blue: 0.75, alpha: 0.5) { didSet { setNeedsDisplay() } }
    @IBInspectable
    var surfaceColor: UIColor = UIColor(colorLiteralRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) { didSet { setNeedsDisplay() } }
    @IBInspectable
    var ringSize: CGFloat = 40.0 { didSet { setNeedsDisplay() } }
    @IBInspectable
    var handleSize: CGFloat = 50.0 { didSet { setNeedsDisplay() } }

    @IBInspectable
    var value: CGFloat = 0.0 {
        didSet {
            guard oldValue != value else { return }
            self.setNeedsDisplay()
            self.sendActions(for: .valueChanged)
            self.delegate?.dialView(self, didChangeValue: value)
        }
    }

    override var isEnabled: Bool { didSet { setNeedsDisplay() } }

    @IBOutlet
    var delegate: DialViewDelegate?

    /// Workaround for Xcode bug that prevents you from connecting the delegate in the storyboard.
    /// Remove this extra property once Xcode gets fixed.
    /// See also http://stackoverflow.com/a/35155533/543875
    @IBOutlet
    var ibDelegate: AnyObject? {
        get { return delegate }
        set { delegate = newValue as? DialViewDelegate }
    }

    private var size: CGFloat { return min(frame.width, frame.height) }

    private var rotationSize: CGFloat { return size - max(handleSize, ringSize) }

    private var dragging = false

    open override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw outer circle = ring
        let x = max(0, handleSize - ringSize)
        context.addEllipse(in: CGRect(x: (bounds.width - size + x) / 2.0, y: (bounds.height - size + x) / 2.0, width: size - x, height: size - x))
        context.setFillColor(ringColor.cgColor.components!)
        context.fillPath()

        // Draw inner circle = surface
        context.addEllipse(in: bounds.insetBy(dx: (frame.width - rotationSize + ringSize) / 2.0, dy: (frame.height - rotationSize + ringSize) / 2.0))
        context.setFillColor(surfaceColor.cgColor.components!)
        context.fillPath()

        if !isEnabled { return }

        // Draw knob circle
        let deltaX = sin(value * 2.0 * CGFloat(M_PI)) * rotationSize / 2.0
        let deltaY = cos(value * 2.0 * CGFloat(M_PI)) * rotationSize / 2.0
        context.addEllipse(in: CGRect(x: bounds.midX + deltaX - handleSize / 2.0, y: bounds.midY - deltaY - handleSize / 2.0, width: handleSize, height: handleSize))
        context.setFillColor(knobColor.cgColor.components!)
        context.fillPath()
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        dragging = isRingTouch(touches.first!)
        guard dragging else { return }
        delegate?.dialViewDidStartDragging?(self)
        performRotation(touches.first!)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragging else { return }
        performRotation(touches.first!)
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragging else { return }
        delegate?.dialViewDidEndDragging?(self)
        dragging = false
    }

    fileprivate func isRingTouch(_ touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        return abs(sqrt(pow(frame.height / 2.0 - point.y, 2.0) + pow(point.x - frame.width / 2.0, 2.0)) - rotationSize / 2.0) < max(handleSize, ringSize) / 2.0
    }

    fileprivate func performRotation(_ touch: UITouch) {
        let point = touch.location(in: self)
        let pos = atan2(point.x - frame.width / 2.0, frame.height / 2.0 - point.y) / 2.0 / CGFloat(M_PI)
        value = pos >= 0 ? pos : pos + 1.0
    }
}

@objc protocol DialViewDelegate {
    func dialView(_ dialView: DialView, didChangeValue value: CGFloat)
    @objc optional func dialViewDidStartDragging(_ dialView: DialView)
    @objc optional func dialViewDidEndDragging(_ dialView: DialView)
}
