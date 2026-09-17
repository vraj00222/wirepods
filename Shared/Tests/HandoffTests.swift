import XCTest
@testable import WirePodsCore

final class HandoffTests: XCTestCase {

    func testEncodeDecode() throws {
        let msg = HandoffMessage(action: .claim, device: .iphone, deviceName: "Test iPhone")
        let data = try msg.encoded()
        // strip trailing newline for decode
        let trimmed = data.dropLast()
        let decoded = try HandoffMessage.decode(from: Data(trimmed))
        XCTAssertEqual(decoded.action, .claim)
        XCTAssertEqual(decoded.device, .iphone)
    }

    func testDecodeLines() throws {
        let m1 = HandoffMessage(action: .claim, device: .iphone, deviceName: "iPhone")
        let m2 = HandoffMessage(action: .release, device: .iphone, deviceName: "iPhone")
        var buf = Data()
        buf.append(try m1.encoded())
        buf.append(try m2.encoded())
        let (msgs, remainder) = HandoffMessage.decodeLines(from: buf)
        XCTAssertEqual(msgs.count, 2)
        XCTAssertTrue(remainder.isEmpty)
        XCTAssertEqual(msgs[0].action, .claim)
        XCTAssertEqual(msgs[1].action, .release)
    }

    func testStateMachineClaimRelease() {
        let sm = HandoffStateMachine()
        let claimMac = HandoffMessage(action: .claim, device: .mac, deviceName: "Mac")
        let claimPhone = HandoffMessage(action: .claim, device: .iphone, deviceName: "iPhone")
        let releasePhone = HandoffMessage(action: .release, device: .iphone, deviceName: "iPhone")

        XCTAssertEqual(sm.focus, .idle)
        sm.handle(claimPhone)
        XCTAssertEqual(sm.focus, .iphoneActive)
        // Mac claims — should switch
        sm.handle(claimMac)
        // Note: debounce may drop if called too fast with same device; different device should switch
        // Allow small delay to avoid debounce
        Thread.sleep(forTimeInterval: 0.9)
        sm.handle(claimMac)
        XCTAssertEqual(sm.focus, .macActive)
        sm.handle(releasePhone)
        // release from non-holder should not clear
        XCTAssertEqual(sm.focus, .macActive)
        let releaseMac = HandoffMessage(action: .release, device: .mac, deviceName: "Mac")
        sm.handle(releaseMac)
        XCTAssertEqual(sm.focus, .idle)
    }
}
