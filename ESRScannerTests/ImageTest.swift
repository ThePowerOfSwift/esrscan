//
//  ImageTest.swift
//  ESRScanner
//
//  Created by Michael on 14.11.15.
//  Copyright © 2015 Michael Weibel. All rights reserved.
//

import XCTest
@testable import ESRScanner

class ImageTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        let bundle = NSBundle(forClass: self.dynamicType)
        let path = bundle.pathForResource("esr", ofType: "png")

        let img = UIImage.init(named: path!)
        XCTAssertNotNil(img)
        let rect = getWhiteRectangle(img!)

        XCTAssertEqual(458.0, rect.origin.x)
        XCTAssertEqual(531.0, rect.origin.y)
        XCTAssertEqual(1187.0, rect.width)
        XCTAssertEqual(280.0, rect.height)
    }
}
