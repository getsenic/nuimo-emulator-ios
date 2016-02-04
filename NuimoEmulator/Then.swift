//
//  Then.swift
//  NuimoSimulator
//
//  Created by Lars Blumberg on 2/2/16.
//  Copyright © 2016 Senic GmbH. All rights reserved.
//

import Foundation

// Inspired from https://github.com/devxoul/Then/blob/master/Sources/Then.swift

protocol Then { }

extension Then {
    func then(@noescape block: Self -> Void) -> Self {
        block(self)
        return self
    }
}

extension NSObject: Then { }
