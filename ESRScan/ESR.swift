//
//  ESR parser & model
//
//  Copyright © 2015 Michael Weibel. All rights reserved.
//  License: MIT
//

import Foundation

enum ESRError : ErrorType {
    case AngleNotFound
    case RefNumNotFound
}

public class ESR {
    var fullStr: String
    var amountCheckDigit: Int?
    var amount: Amount?
    var refNum: ReferenceNumber
    var refNumCheckDigit: Int
    var accNum: AccountNumber

    var transmitted = false

    init(fullStr : String, amountCheckDigit : Int?, amount : Amount?, refNum : ReferenceNumber, refNumCheckDigit : Int, accNum : AccountNumber) {
        self.fullStr = fullStr
        self.amountCheckDigit = amountCheckDigit
        self.amount = amount
        self.refNum = refNum
        self.refNumCheckDigit = refNumCheckDigit
        self.accNum = accNum
    }

    static func parseText(str : String) throws -> ESR {
        let newStr = str.stringByReplacingOccurrencesOfString(" ", withString: "")
        let newStrLength = newStr.characters.count

        let angleRange = newStr.rangeOfString(">")
        if angleRange == nil {
            throw ESRError.AngleNotFound
        }
        let angleIndex = newStr.startIndex.distanceTo(angleRange!.startIndex)
        let afterAngle = angleIndex + 1

        let start = newStr.startIndex.advancedBy(angleIndex - 1)
        let end = newStr.startIndex.advancedBy(angleIndex)
        let amountCheckDigit = Int(newStr.substringWithRange(
            start..<end
        ))

        var amount : Amount?
        if angleIndex > 3 {
            let amountValue = Double(newStr.substringWithRange(
                newStr.startIndex.advancedBy(2)..<newStr.startIndex.advancedBy(angleIndex - 1)
            ))
            amount = Amount.init(value: amountValue! / 100.0)
        }

        let refNumStart = newStr.startIndex.advancedBy(afterAngle)
        var refNumLength = 27

        let plusRange = newStr.rangeOfString("+")
        if plusRange != nil {
            refNumLength = refNumStart.distanceTo(plusRange!.startIndex)
        }

        if newStr.startIndex.distanceTo(refNumStart)+refNumLength > newStrLength {
            throw ESRError.RefNumNotFound
        }

        let refNum = ReferenceNumber.init(num: newStr.substringWithRange(
            refNumStart..<refNumStart.advancedBy(refNumLength)
        ))

        let idx = refNum.num.endIndex.advancedBy(-1)
        let refNumCheckDigit = Int(refNum.num.substringFromIndex(idx))!

        let accNum = newStr.substringWithRange(
            newStr.endIndex.advancedBy(-10)..<newStr.endIndex.advancedBy(-1)
        )
        let accountNumber = AccountNumber.init(num: accNum)

        return ESR.init(
            fullStr: newStr,
            amountCheckDigit: amountCheckDigit,
            amount: amount,
            refNum: refNum,
            refNumCheckDigit: refNumCheckDigit,
            accNum: accountNumber
        )
    }

    func amountCheckDigitValid() -> Bool {
        let angleRange = self.fullStr.rangeOfString(">")
        if angleRange == nil {
            return false
        }
        let angleIndex = self.fullStr.startIndex.distanceTo(angleRange!.startIndex)
        let str = self.fullStr.substringWithRange(
            self.fullStr.startIndex..<self.fullStr.startIndex.advancedBy(angleIndex - 1)
        )
        return self.amountCheckDigit == calcControlDigit(str)
    }

    func refNumCheckDigitValid() -> Bool {
        let idx = self.refNum.num.endIndex.advancedBy(-1)
        let refNum = self.refNum.num.substringToIndex(idx)

        return self.refNumCheckDigit == calcControlDigit(refNum)
    }

    func string() -> String {
        var str = "Reference number: \(self.refNum.string())"
        if !self.refNumCheckDigitValid() {
            str.appendContentsOf(" ⚠︎")
        }

        str.appendContentsOf("\nAccount number: \(self.accNum.string())")
        if self.amount != nil {
            str.appendContentsOf("\nAmount: CHF \(self.amount!.string())")
            if !self.amountCheckDigitValid() {
                str.appendContentsOf(" ⚠︎")
            }
        }
        return str
    }

    func dictionary() -> [String : AnyObject] {
        var dict = [String : AnyObject]()
        dict["referenceNumber"] = self.refNum.string()
        dict["amount"] = self.amount?.string()
        dict["accountNumber"] = self.accNum.string()

        dict["amountCorrect"] = self.amountCheckDigitValid()
        dict["referenceNumberCorrect"] = self.refNumCheckDigitValid()

        return dict
    }

    private func calcControlDigit(str: String) -> Int {
        let table = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]
        var carry = 0
        for char in str.characters {
            let num = Int.init(String(char), radix: 10)
            if num == nil {
                return -1
            }
            carry = table[(carry + num!) % 10]
        }
        return (10 - carry) % 10
    }

    // only CHF for now
    // ref: ESR Handbuch Postfinance
    static let validTypeCodes: Set<String> = [
        "01", "03", "04", "11", "14"
    ]

    static func isValidTypeCode(str: String) -> Bool {
        for typeCode in validTypeCodes {
            if(str.hasPrefix(typeCode)) {
                return true
            }
        }
        return false
    }
}