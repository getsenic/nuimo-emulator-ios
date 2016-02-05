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
public class DialView : UIControl {
    @IBInspectable
    public var ringColor: UIColor = UIColor(colorLiteralRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0) { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var knobColor: UIColor = UIColor(colorLiteralRed: 0.75, green: 0.75, blue: 0.75, alpha: 0.5) { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var surfaceColor: UIColor = UIColor(colorLiteralRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var ringSize: CGFloat = 40.0 { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var handleSize: CGFloat = 50.0 { didSet { setNeedsDisplay() } }

    @IBInspectable
    public var value: CGFloat = 0.0 {
        didSet {
            guard oldValue != value else { return }
            self.setNeedsDisplay()
            self.sendActionsForControlEvents(.ValueChanged)
            self.delegate?.dialView(self, didChangeValue: value)
        }
    }

    public override var enabled: Bool { didSet { setNeedsDisplay() } }

    @IBOutlet
    public var delegate: DialViewDelegate?

    /// Workaround for Xcode bug that prevents you from connecting the delegate in the storyboard.
    /// Remove this extra property once Xcode gets fixed.
    /// See also http://stackoverflow.com/a/35155533/543875
    @IBOutlet
    public var ibDelegate: AnyObject? {
        get { return delegate }
        set { delegate = newValue as? DialViewDelegate }
    }

    private var size: CGFloat { return min(frame.width, frame.height) }

    private var rotationSize: CGFloat { return size - max(handleSize, ringSize) }

    private var dragging = false

    public override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        // Draw outer circle = ring
        let x = max(0, handleSize - ringSize)
        CGContextAddEllipseInRect(context, CGRect(x: (bounds.width - size + x) / 2.0, y: (bounds.height - size + x) / 2.0, width: size - x, height: size - x))
        CGContextSetFillColor(context, CGColorGetComponents(ringColor.CGColor))
        CGContextFillPath(context)

        // Draw inner circle = surface
        CGContextAddEllipseInRect(context, bounds.insetBy(dx: (frame.width - rotationSize + ringSize) / 2.0, dy: (frame.height - rotationSize + ringSize) / 2.0))
        CGContextSetFillColor(context, CGColorGetComponents(surfaceColor.CGColor))
        CGContextFillPath(context)

        if !enabled { return }

        // Draw knob circle
        let deltaX = sin(value * 2.0 * CGFloat(M_PI)) * rotationSize / 2.0
        let deltaY = cos(value * 2.0 * CGFloat(M_PI)) * rotationSize / 2.0
        CGContextAddEllipseInRect(context, CGRect(x: bounds.midX + deltaX - handleSize / 2.0, y: bounds.midY - deltaY - handleSize / 2.0, width: handleSize, height: handleSize))
        CGContextSetFillColor(context, CGColorGetComponents(knobColor.CGColor))
        CGContextFillPath(context)
    }

    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard enabled else { return }
        dragging = isRingTouch(touches.first!)
        guard dragging else { return }
        delegate?.dialViewDidStartDragging?(self)
        performRotation(touches.first!)
    }

    public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard dragging else { return }
        performRotation(touches.first!)
    }

    public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard dragging else { return }
        delegate?.dialViewDidEndDragging?(self)
        dragging = false
    }

    private func isRingTouch(touch: UITouch) -> Bool {
        let point = touch.locationInView(self)
        return sqrt(pow(frame.height / 2.0 - point.y, 2.0) + pow(point.x - frame.width / 2.0, 2.0)) > (rotationSize - max(handleSize, ringSize)) / 2.0
    }

    private func performRotation(touch: UITouch) {
        let point = touch.locationInView(self)
        let pos = atan2(point.x - frame.width / 2.0, frame.height / 2.0 - point.y) / 2.0 / CGFloat(M_PI)
        value = pos >= 0 ? pos : pos + 1.0
    }
}

@objc
public protocol DialViewDelegate {
    func dialView(dialView: DialView, didChangeValue value: CGFloat)
    optional func dialViewDidStartDragging(dialView: DialView)
    optional func dialViewDidEndDragging(dialView: DialView)
}
