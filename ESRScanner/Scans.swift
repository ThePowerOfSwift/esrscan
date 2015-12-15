//
//  List of ESR scans - model
//
//  Copyright © 2015 Michael Weibel. All rights reserved.
//  License: MIT
//

import Foundation

class Scans {
    var scans : [ESR] = []

    func addScan(scan : ESR) {
        self.scans.insert(scan, atIndex: 0)
    }

    func count() -> Int {
        return self.scans.count
    }

    func clear() {
        self.scans = []
    }

    func string() -> String {
        return scans.map{ $0.string() }.joinWithSeparator("\n----\n")
    }

    subscript(index: Int) -> ESR {
        get {
            return scans[index]
        }
    }
}