//
//  LEDView.swift
//  NuimoSimulator
//
//  Created by Lars Blumberg on 2/4/16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

@IBDesignable
public class LEDView : UIView {
    @IBInspectable
    public var columns: Int = 3 { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var rows: Int = 3 { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var ledSize: CGFloat = 24 { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var onColor: UIColor = UIColor(red: 1.0, green: 0.0, blue: 0, alpha: 1) { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var offColor: UIColor = UIColor(red: 1.0, green: 0.0, blue: 0, alpha: 0.2) { didSet { setNeedsDisplay() } }
    @IBInspectable
    public var leds: [Bool] = [true, true, true, true, true, true, true, true, true] { didSet { setNeedsDisplay() } }

    public override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        let horzSpace = columns > 1
            ? (bounds.width - CGFloat(columns) * ledSize) / (CGFloat(columns) - 1.0)
            : 0
        let vertSpace = rows > 1
            ? (bounds.width - CGFloat(rows) * ledSize) / (CGFloat(rows) - 1.0)
            : 0

        (0..<rows).forEach { row in
            (0..<columns).forEach { col in
                CGContextAddEllipseInRect(context, CGRect(x: CGFloat(col) * (ledSize + horzSpace), y: CGFloat(row) * (ledSize + vertSpace), width: ledSize, height: ledSize))
                let ledIndex = row * columns + col
                let color: UIColor = ledIndex < leds.count ? (leds[ledIndex] ? onColor : offColor) : offColor
                CGContextSetFillColor(context, CGColorGetComponents(color.CGColor))
                CGContextFillPath(context)
            }
        }
    }
}
