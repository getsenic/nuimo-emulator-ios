//
//  DialView.swift
//  NuimoSimulator
//
//  Created by Lars Blumberg on 2/1/16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import UIKit

@IBDesignable
class DialView : UIView {
    @IBInspectable
    var knobSize: CGFloat = 40.0

    private var knobPosition: CGFloat = 0.0

    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        CGContextAddEllipseInRect(context, rect.insetBy(dx: knobSize / 2.0, dy: knobSize / 2.0))
        CGContextSetFillColor(context, CGColorGetComponents(UIColor.blueColor().CGColor))
        CGContextFillPath(context)

        let deltaX = sin(CGFloat(Double(knobPosition) * 2.0 * M_PI)) * (rect.width - knobSize) / 2.0
        let deltaY = cos(CGFloat(Double(knobPosition) * 2.0 * M_PI)) * (rect.height - knobSize) / 2.0

        let r = CGRect(x: rect.midX + deltaX - knobSize / 2.0, y: rect.midY - deltaY - knobSize / 2.0, width: knobSize, height: knobSize)
        CGContextAddEllipseInRect(context, r)
        CGContextSetFillColor(context, CGColorGetComponents(UIColor.redColor().CGColor))
        CGContextFillPath(context)
    }
}
