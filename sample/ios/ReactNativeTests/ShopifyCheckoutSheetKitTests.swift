/*
 MIT License

 Copyright 2023 - Present, Shopify Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import XCTest
@testable import ShopifyCheckoutSheetKit
@testable import RNShopifyCheckoutSheetKit

class ShopifyCheckoutSheetKitTests: XCTestCase {
  private var shopifyCheckoutSheetKit: RCTShopifyCheckoutSheetKit!

  override func setUp() {
    super.setUp()
    shopifyCheckoutSheetKit = getShopifyCheckoutSheetKit()
    resetShopifyCheckoutSheetKitDefaults()
  }

  override func tearDown() {
    shopifyCheckoutSheetKit = nil
    super.tearDown()
  }

  private func resetShopifyCheckoutSheetKitDefaults() {
    ShopifyCheckoutSheetKit.configuration.preloading = Configuration.Preloading(enabled: true)
    ShopifyCheckoutSheetKit.configuration.colorScheme = .automatic
  }

  private func getShopifyCheckoutSheetKit() -> RCTShopifyCheckoutSheetKit {
    return RCTShopifyCheckoutSheetKit()
  }

  /// getConfig
  func testReturnsDefaultConfig() {
    // Call getConfig and capture the result
    var result: [String: Any]?
    shopifyCheckoutSheetKit.getConfig({ config in result = config as? [String: Any] }, reject: { _, _, _ in })

    // Verify that getConfig returned the expected result
    XCTAssertEqual(result?["preloading"] as? Bool, true)
    XCTAssertEqual(result?["colorScheme"] as? String, "automatic")
  }

  /// configure
  func testConfigure() {
    let configuration: [AnyHashable: Any] = [
      "preloading": true,
      "colorScheme": "dark",
      "colors": [
        "ios": [
          "spinnerColor": "#FF0000",
          "backgroundColor": "#0000FF"
        ]
      ]
    ]

    shopifyCheckoutSheetKit.setConfig(configuration)

    XCTAssertTrue(ShopifyCheckoutSheetKit.configuration.preloading.enabled)
    XCTAssertEqual(ShopifyCheckoutSheetKit.configuration.colorScheme, .dark)
    XCTAssertEqual(ShopifyCheckoutSheetKit.configuration.spinnerColor, UIColor(hex: "#FF0000"))
    XCTAssertEqual(ShopifyCheckoutSheetKit.configuration.backgroundColor, UIColor(hex: "#0000FF"))
  }

  func testConfigureWithPartialConfig() {
    let configuration: [AnyHashable: Any] = [
      "preloading": false
    ]

    shopifyCheckoutSheetKit.setConfig(configuration)

    XCTAssertFalse(ShopifyCheckoutSheetKit.configuration.preloading.enabled)
  }

  func testConfigureWithInvalidColors() {
    let configuration: [AnyHashable: Any] = [
      "colors": [
        "ios": [
          "spinnerColor": "invalid"
        ]
      ]
    ]

    let defaultColorFallback = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    shopifyCheckoutSheetKit.setConfig(configuration)

    XCTAssertEqual(ShopifyCheckoutSheetKit.configuration.spinnerColor, defaultColorFallback)
  }

  /// checkoutDidComplete
  func testCheckoutDidCompleteSendsEvent() {
    let mock = mockSendEvent(eventName: "completed")

    mock.startObserving()
    mock.checkoutDidComplete()

    XCTAssertTrue(mock.didSendEvent)
  }

  /// checkoutDidCancel
  func testCheckoutDidCancelSendsEvent() {
    let mock = mockAsyncSendEvent(eventName: "close")

    let expectation = self.expectation(description: "CheckoutDidCancel")

    mock.sendEventImplementation = { name, _ in
      if name == "close" {
        mock.didSendEvent = true
        expectation.fulfill()
      }
    }

    mock.startObserving()
    mock.checkoutDidCancel()

    // Wait for the expectation to be fulfilled
    waitForExpectations(timeout: 1, handler: nil)

    XCTAssertTrue(mock.didSendEvent)
  }

  /// checkoutDidFail
  func testCheckoutDidFailSendsEvent() {
    let mock = mockSendEvent(eventName: "error")

    mock.startObserving()
    let error = CheckoutError.checkoutExpired(message: "Checkout expired")
    mock.checkoutDidFail(error: error)

    XCTAssertTrue(mock.didSendEvent)
    if let eventBody = mock.eventBody as? [String: Any], let message = eventBody["message"] as? String {
      XCTAssertEqual(message, error.localizedDescription)
    } else {
      XCTFail("Failed to get the message from eventBody")
    }
  }

  /// checkoutDidEmitWebPixelEvent
  func testCheckoutDidEmitStandardWebPixelEvent() {
    let mock = mockSendEvent(eventName: "pixel")

    let context = Context(
      document: WebPixelsDocument(
        characterSet: "utf8",
        location: nil,
        referrer: "test",
        title: nil),
      navigator: nil,
      window: nil
    )
    let event = StandardEvent(context: context, id: "test", name: "test", timestamp: "test", data: nil)
    let pixelEvent = PixelEvent.standardEvent(event)

    mock.startObserving()
    mock.checkoutDidEmitWebPixelEvent(event: pixelEvent)

    XCTAssertTrue(mock.didSendEvent)
    if let eventBody = mock.eventBody as? [String: Any] {
      XCTAssertEqual(eventBody["type"] as? String, "STANDARD")
      XCTAssertEqual(eventBody["id"] as? String, "test")
      XCTAssertEqual(eventBody["name"] as? String, "test")
      XCTAssertEqual(eventBody["timestamp"] as? String, "test")
      // swiftlint:disable:next force_cast
      XCTAssertEqual(eventBody["context"] as! [String: [String: String?]], [
        "document": [
          "characterSet": "utf8",
          "referrer": "test"
        ]
      ])
    } else {
      XCTFail("Failed to parse standard event")
    }
  }

  func testCheckoutDidEmitCustomWebPixelEvent() {
    let mock = mockSendEvent(eventName: "pixel")

    let context = Context(
      document: WebPixelsDocument(
        characterSet: "utf8",
        location: nil,
        referrer: "test",
        title: nil),
      navigator: nil,
      window: nil
    )
    let customData = "{\"nestedData\": {\"someAttribute\": \"456\"}}"
    let event = CustomEvent(context: context, customData: customData, id: "test", name: "test", timestamp: "test")
    let pixelEvent = PixelEvent.customEvent(event)

    mock.startObserving()
    mock.checkoutDidEmitWebPixelEvent(event: pixelEvent)

    XCTAssertTrue(mock.didSendEvent)
    if let eventBody = mock.eventBody as? [String: Any] {
      XCTAssertEqual(eventBody["type"] as? String, "CUSTOM")
      XCTAssertEqual(eventBody["id"] as? String, "test")
      XCTAssertEqual(eventBody["name"] as? String, "test")
      XCTAssertEqual(eventBody["timestamp"] as? String, "test")
      // swiftlint:disable:next force_cast
      XCTAssertEqual(eventBody["context"] as! [String: [String: String?]], [
        "document": [
          "characterSet": "utf8",
          "referrer": "test"
        ]
      ])
      // swiftlint:disable:next force_cast
      XCTAssertEqual(eventBody["customData"] as! [String: [String: String]], [
        "nestedData": [
          "someAttribute": "456"
        ]
      ])
    } else {
      XCTFail("Failed to parse custom event")
    }
  }

  private func mockSendEvent(eventName: String) -> RCTShopifyCheckoutSheetKitMock {
    let mock = RCTShopifyCheckoutSheetKitMock()
    mock.eventName = eventName
    return mock
  }

  private func mockAsyncSendEvent(eventName: String) -> AsyncRCTShopifyCheckoutSheetKitMock {
    let mock = AsyncRCTShopifyCheckoutSheetKitMock()
    mock.eventName = eventName
    return mock
  }
}

class RCTShopifyCheckoutSheetKitMock: RCTShopifyCheckoutSheetKit {
  var didSendEvent = false
  var eventName: String?
  var eventBody: Any!

  override func sendEvent(withName name: String!, body: Any!) {
    if name == self.eventName {
      didSendEvent = true
      eventBody = body
    }
  }
}

class AsyncRCTShopifyCheckoutSheetKitMock: RCTShopifyCheckoutSheetKit {
  var didSendEvent = false
  var eventName: String?
  var sendEventImplementation: ((String?, Any?) -> Void)?

  override func sendEvent(withName name: String!, body: Any!) {
    sendEventImplementation?(name, body)
  }
}
