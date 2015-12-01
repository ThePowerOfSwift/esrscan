//
//  ReferenceNumber.swift
//  ESRScanner
//
//  Created by Michael on 23.11.15.
//  Copyright © 2015 Michael Weibel. All rights reserved.
//

import Foundation

class ReferenceNumber {
    var num: String
    init(num: String) {
        self.num = num
    }

    func string() -> String {
        var str = ""
        let l = num.characters.count
        for var i = l - 1; i >= 0; i-- {
            let char = num[num.startIndex.advancedBy(i)]
            str = String(char) + str
            if (i - l) % 5 == 0 {
                str = " " + str
            }
        }
        return str
    }
}