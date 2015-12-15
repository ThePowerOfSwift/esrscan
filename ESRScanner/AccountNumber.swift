//
//  Account Number model
//
//  Copyright © 2015 Michael Weibel. All rights reserved.
//  License: MIT
//

import Foundation

class AccountNumber {
    var num: String
    init(num: String) {
        self.num = num
    }

    func string() -> String {
        let prefix = num.substringWithRange(
            Range(start: num.startIndex, end: num.startIndex.advancedBy(2)
        ))
        var center = num.substringWithRange(
            Range(start: num.startIndex.advancedBy(2), end: num.endIndex.advancedBy(-1)
        ))

        let regex = try! NSRegularExpression(pattern: "^0+", options: [])

        center = regex.stringByReplacingMatchesInString(center,
            options: [],
            range: NSMakeRange(0, center.characters.count),
            withTemplate: ""
        )
        let postfix = String(num[num.endIndex.advancedBy(-1)])
        return prefix + "-" + center + "-" + postfix
    }
}