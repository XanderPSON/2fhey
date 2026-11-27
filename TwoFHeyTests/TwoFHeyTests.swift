//
//  TwoFHeyTests.swift
//  TwoFHeyTests
//
//  Parser tests: every supported message format must parse, and no phone
//  number may ever be returned as a code.
//

import XCTest
@testable import _FHey

class OTPParserTests: XCTestCase {
    let parser = OTPParser()

    private func assertCode(_ message: String, _ expected: String, sender: String? = nil,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(parser.parse(message, sender: sender)?.code, expected, file: file, line: line)
    }

    private func assertNoCode(_ message: String, sender: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(parser.parse(message, sender: sender), file: file, line: line)
    }

    // MARK: - Supported formats (feature parity)

    func testCommonEnglishFormats() {
        assertCode("Your Apple ID Code is: 654321. Don't share it with anyone.", "654321")
        assertCode("123456 is your Amazon OTP. Do not share it with anyone.", "123456")
        assertCode("Your code: 456789", "456789")
        assertCode("Your verification code is 789012", "789012")
        assertCode("Your security code is: 654321", "654321")
        assertCode("Your login code: 123456", "123456")
        assertCode("Your one-time password is 987654", "987654")
        assertCode("Your validation code is 456123", "456123")
        assertCode("Your confirmation code: 789456", "789456")
        assertCode("132637 is your Link verification code.", "132637")
        assertCode("Your portal verification code is : jh7112 Msg&Data rates may apply.", "jh7112")
    }

    func testGoogleFormat() {
        let parsed = parser.parse("G-123456 is your Google verification code.")
        XCTAssertEqual(parsed?.code, "G-123456")
        XCTAssertEqual(parsed?.service, "google")
    }

    func testAlphanumericCodes() {
        assertCode("ABC123 is your verification code", "ABC123")
        assertCode("GEICO: Your verification code is: ABC123. It expires in 10 minutes.", "ABC123")
        assertCode("Your code is AB12C.", "AB12C")
    }

    func testBankFormats() {
        assertCode("Truist Alerts: To verify the JAILATM CO transaction on card 0323, use 582270. We won't contact you for this code.", "582270")
        assertCode("From: Chase\nWe'll NEVER call you to ask for this code.\nOne-Time Code:12345678\nOnly use this online. Code expires in 30 min.", "12345678")
        assertCode("123456 is the OTP for transaction on your Kotak Bank Card valid for 15 mins. DONT SHARE OTP WITH ANYONE.", "123456")
    }

    func testChineseFormats() {
        assertCode("【知乎】你的验证码是 700185，此验证码用于登录知乎或重置密码。10 分钟内有效。", "700185")
        assertCode("【京东】验证码：548393，您正在新设备上登录。", "548393")
    }

    func testHebrewFormat() {
        assertCode("קוד האימות שלך הוא 123456", "123456")
    }

    func testCustomPatterns() {
        assertCode("Please use SGD-123456 within 3 minutes to authorize this transaction.", "123456")
        assertCode("Your passcode is\n1234-567890", "1234")
        assertCode("12345678\nValid 5 minutes. Do not share.", "12345678")
        assertCode("@valid.aoc.cat #654321", "654321")
        assertCode("Ihr Bestätigungscode ist: AB3C45", "AB3C45")
        assertCode("OTP to MAKE A NEW PAYMENT of GBP 9.94 to 560027 & 27613445. Call us if this wasn't you. NEVER share this code, not even with Cater Allen staff 699486", "699486")
    }

    func testSpacedAndDashedCodes() {
        assertCode("Your verification code is 123 456", "123456")
        assertCode("Your code: 123-456", "123456")
    }

    func testServiceExtraction() {
        XCTAssertEqual(parser.parse("Your Google verification code is 123456")?.service, "google")
        XCTAssertEqual(parser.parse("123456 is your Amazon OTP.")?.service, "amazon")
    }

    // MARK: - Phone numbers must never be codes

    func testPhoneNumberIsNeverTheCode() {
        // Phone numbers in every common format, alongside a real code.
        assertCode("New login from +1 (415) 555-2671. Your code is 887766.", "887766")
        assertCode("Your verification code is 123456. Call us at 555-123-4567 if this wasn't you.", "123456")
        assertCode("Call 555.123.4567 to opt out. Your code: 246810", "246810")
        assertCode("Your code is 445566. Questions? Text 787473.", "445566")
        assertCode("Verification code 998877. Support: +447911123456.", "998877")
    }

    func testMessageWithOnlyPhoneNumbersHasNoCode() {
        assertNoCode("Call us to verify your account at 555-123-4567.")
        assertNoCode("Your verification call will come from +1 415 555 2671.")
        assertNoCode("To verify, text HELP to 466453.")
        assertNoCode("787473") // bare short-code sender in a title
    }

    func testSenderNumberIsNeverTheCode() {
        // The sender's own number (or any fragment of it) must never be returned,
        // even when the message contains keywords licensing digit extraction.
        assertNoCode("Verification message from 787473", sender: "787473")
        assertNoCode("Your code is 314159", sender: "314159263")
        assertCode("Use code 528491 to log in.", "528491", sender: "+15555551234")
    }

    func testTenDigitNumbersAreNotCodes() {
        // Bare 10-digit strings look like phone numbers, not OTPs.
        assertNoCode("Your verification code request was received. Ref 4155552671123.")
        assertNoCode("code: 4155552671")
    }

    // MARK: - Other non-codes

    func testMoneyTimesAndDatesAreNotCodes() {
        assertNoCode("Your payment of 1234.56 was confirmed at 10:30 on 12/25/2025.")
        assertCode("Your code 654321 expires at 10:30 am on the 25th.", "654321")
    }

    func testURLPathsAreNotCodes() {
        assertCode("Your code is 246813. Details: https://example.com/verify/999999", "246813")
        assertNoCode("Verify at https://example.com/session/12345678")
    }

    func testOptOutFootersAreNotCodes() {
        // A keyword with no real code must not fall through to the opt-out footer.
        assertNoCode("Please verify your account at example.com/account. Reply Stop2End to opt out")
        assertNoCode("Please verify your account at example.com/account. Reply STOP2END to opt out")
        assertNoCode("Please verify your account at example.com/account.\n\nEnd2End")
        // A real code in the same message is still returned.
        assertCode("Your verification code is 482913. Reply Stop2End to opt out", "482913")
    }

    func testKeywordInsideOrdinaryWordDoesNotEnableExtraction() {
        // "auth" appears only inside "authoritarian".
        assertNoCode("His authoritarian agenda is a threat. We won in 2024 and can win again. Give $15 today.")
        // "pin" appears only inside "helping".
        assertNoCode("Thanks for helping us grow. Our 2024 goal is on track.")
    }

    func testShortKeywordsStillMatchAsWholeWords() {
        assertCode("Your PIN is 7391", "7391")
        assertCode("Your PINs are 7391 and 8264", "7391")
        assertCode("Your codes are 123456 and 654321", "123456")
        assertCode("Use the auth code 246810 to log in.", "246810")
        assertCode("Your OTP: 482913", "482913")
        assertCode("Use 2FA code 135790 now", "135790")
    }

    func testCompoundKeywordsStillMatchInsideLongerWords() {
        // German keywords are often the stem of a compound word.
        assertCode("Ihr Sicherheitscode ist 123456", "123456")
        assertCode("Ihr Verifizierungscode lautet 654321", "654321")
    }

    func testKeywordInsideURLDoesNotEnableExtraction() {
        // "pin" appears only in the link path, so nothing else in the message may become a code.
        assertNoCode("Will you chip in $15 to our campaign? i.example.com/ppiNg4AP\n\nStop2End")
        // "code" appears only in a query parameter name.
        assertNoCode("Chip in today: https://example.com/donate?refcode=abc\n\nSD26")
    }

    func testMessagesWithoutKeywordsAreIgnored() {
        assertNoCode("Hey, meet me at 123456 Main St")
        assertNoCode("Running 15 minutes late, sorry!")
    }
}

// Fork: emailed codes, site/app check before auto-paste
class ForkPasteGuardTests: XCTestCase {
    func testSiteName() {
        XCTAssertEqual(PasteGuard.siteName(fromHost: "www.cgtrader.com"), "cgtrader")
        XCTAssertEqual(PasteGuard.siteName(fromHost: "shop.example.co.uk"), "example")
        XCTAssertEqual(PasteGuard.siteName(fromHost: "localhost"), "localhost")
        XCTAssertEqual(PasteGuard.siteName(fromHost: ""), "")
    }

    func testServiceMatching() {
        XCTAssertTrue(PasteGuard.serviceMatches("CGTrader", host: "www.cgtrader.com", title: "Log in"))
        XCTAssertTrue(PasteGuard.serviceMatches("google", host: "accounts.google.com", title: ""))
        XCTAssertTrue(PasteGuard.serviceMatches("Chase", host: "", title: "Chase Bank - Sign in"))
        XCTAssertFalse(PasteGuard.serviceMatches("Amazon", host: "chatgpt.com", title: "ChatGPT"))
        XCTAssertTrue(PasteGuard.serviceMatches(nil, host: "chatgpt.com", title: "ChatGPT"))
        XCTAssertTrue(PasteGuard.serviceMatches("Amazon", host: "", title: ""))
    }

    func testEmailDecision() {
        let matched = PasteGuard.decide(origin: .email(match: true, onlyFresh: false), host: "a.com", title: "", focusedIsTextInput: true)
        XCTAssertTrue(matched.paste)
        let wrongSite = PasteGuard.decide(origin: .email(match: false, onlyFresh: true), host: "chatgpt.com", title: "", focusedIsTextInput: true)
        XCTAssertEqual(wrongSite, PasteDecision(paste: false, reason: "didn't match chatgpt.com"))
        XCTAssertFalse(PasteGuard.decide(origin: .email(match: false, onlyFresh: false), host: "", title: "Terminal", focusedIsTextInput: true).paste)
        XCTAssertTrue(PasteGuard.decide(origin: .email(match: false, onlyFresh: true), host: "", title: "Terminal", focusedIsTextInput: true).paste)
    }

    func testMessageAndFocusDecision() {
        XCTAssertFalse(PasteGuard.decide(origin: .message(service: "Amazon"), host: "chatgpt.com", title: "ChatGPT", focusedIsTextInput: true).paste)
        XCTAssertTrue(PasteGuard.decide(origin: .message(service: nil), host: "chatgpt.com", title: "", focusedIsTextInput: true).paste)
        let noField = PasteGuard.decide(origin: .message(service: nil), host: "x.com", title: "", focusedIsTextInput: false)
        XCTAssertEqual(noField.reason, "no text field focused")
        XCTAssertTrue(PasteGuard.decide(origin: .message(service: nil), host: "x.com", title: "", focusedIsTextInput: nil).paste)
        XCTAssertTrue(PasteGuard.isTextInputRole("AXComboBox"))
        XCTAssertFalse(PasteGuard.isTextInputRole("AXWebArea"))
        XCTAssertFalse(PasteGuard.isTextInputRole(nil))
    }

    func testRecentTitle() {
        XCTAssertEqual(PasteGuard.recentTitle(code: "123456", service: "GitHub", isEmail: true), "123456 - ✉ GitHub")
        XCTAssertEqual(PasteGuard.recentTitle(code: "123456", service: nil, isEmail: false), "123456 - 💬 Unknown")
    }
}

class ForkFrontmostContextTests: XCTestCase {
    func testBrowserKinds() {
        XCTAssertEqual(FrontmostContext.browserKind(bundleID: "com.google.Chrome"), .chromium)
        XCTAssertEqual(FrontmostContext.browserKind(bundleID: "com.apple.Safari"), .safari)
        XCTAssertNil(FrontmostContext.browserKind(bundleID: "com.apple.Terminal"))
    }

    func testParseScriptOutput() {
        let ctx = FrontmostContext.parse(scriptOutput: "https://www.cgtrader.com/login?x=1\nLog in | CGTrader")
        XCTAssertEqual(ctx, FrontmostContext(host: "www.cgtrader.com", title: "Log in | CGTrader"))
        XCTAssertNil(FrontmostContext.parse(scriptOutput: "missing value"))
    }
}

class ForkEmailCodeTests: XCTestCase {
    private let json = """
    {"codes":[
      {"id":"a","account":"x@gmail.com","code":"123456","from":"GitHub","subject":"Your code","match":true,"age_s":30},
      {"id":"b","account":"x@gmail.com","code":"654321","from":"Old","subject":"Old code","match":false,"age_s":500},
      {"id":"c","account":"x@gmail.com","code":"111111","from":"Seen","subject":"s","match":false,"age_s":10}
    ]}
    """.data(using: .utf8)!

    func testFiltersOldAndSeen() {
        let result = EmailCodeManager.newCodes(from: json, seen: ["c"])
        XCTAssertEqual(result?.codes.map(\.id), ["a"])
        XCTAssertEqual(result?.onlyFresh, false)
    }

    func testOnlyFreshAndBadJSON() {
        let one = #"{"codes":[{"id":"a","account":"x","code":"1234","from":"F","subject":"S","match":false,"age_s":5}]}"#.data(using: .utf8)!
        XCTAssertEqual(EmailCodeManager.newCodes(from: one, seen: [])?.onlyFresh, true)
        XCTAssertNil(EmailCodeManager.newCodes(from: Data("nope".utf8), seen: []))
    }

    func testMessageMapping() {
        let code = EmailCode(id: "g1", account: "x", code: "123456", from: "GitHub", subject: "Your code", match: true, ageSeconds: 1)
        let (message, otp) = EmailCodeManager.makeMessage(code)
        XCTAssertEqual(message.guid, "g1")
        XCTAssertEqual(message.text, "GitHub: Your code")
        XCTAssertEqual(message.handle, "GitHub")
        XCTAssertEqual(otp, ParsedOTP(service: "GitHub", code: "123456"))
    }

    // Fork: skipped codes stay unused (email) / unread (text)
    func testMarksUsedOnlyWhenPasted() {
        XCTAssertTrue(PasteGuard.marksUsed(PasteDecision(paste: true, reason: nil)))
        XCTAssertFalse(PasteGuard.marksUsed(PasteDecision(paste: false, reason: "didn't match x.com")))
        XCTAssertFalse(PasteGuard.marksUsed(nil)) // auto-paste off
        XCTAssertFalse(PasteGuard.marksUsed(PasteDecision(paste: true, reason: nil), asked: true)) // waits for Fill
    }
}

// Fork: Apple's AutoFill goes first; a code that lands in the field is marked done
class ForkAppleAutoFillTests: XCTestCase {
    func testRecognisesApplesAutoFillHelper() {
        XCTAssertTrue(PasteGuard.isAppleAutoFill(ownerPath: "/System/Library/PrivateFrameworks/SafariPlatformSupport.framework/Versions/A/XPCServices/com.apple.SafariPlatformSupport.Helper.xpc/Contents/MacOS/com.apple.SafariPlatformSupport.Helper"))
        XCTAssertFalse(PasteGuard.isAppleAutoFill(ownerPath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
    }

    func testFieldHasCode() {
        XCTAssertTrue(PasteGuard.fieldHasCode("656600", code: "656600"))
        XCTAssertTrue(PasteGuard.fieldHasCode("656 600", code: "656-600"))
        XCTAssertTrue(PasteGuard.fieldHasCode("g-12345", code: "G-12345"))
        XCTAssertFalse(PasteGuard.fieldHasCode("65660", code: "656600")) // still typing
        XCTAssertFalse(PasteGuard.fieldHasCode(nil, code: "656600"))
        XCTAssertFalse(PasteGuard.fieldHasCode("anything", code: ""))
    }
}

// Fork: finding the code's conversation row in Messages.app
class ForkMessagesReadMarkerTests: XCTestCase {
    let bofa = "<#>BofA: DO NOT share this code. Code 656600. We NEVER call or text for it. Reply HELP if you didn't request it."

    func testMatchesUnreadRowByPreview() {
        XCTAssertTrue(MessagesReadMarker.rowMatches(label: "Bank of America, Unread, \(bofa) , Yesterday ", messageText: bofa))
        XCTAssertFalse(MessagesReadMarker.rowMatches(label: "Bank of America, Unread, \(bofa.replacingOccurrences(of: "656600", with: "290760")) , 8:00 AM", messageText: bofa))
        XCTAssertFalse(MessagesReadMarker.rowMatches(label: "Steve, Pinned", messageText: ""))
    }

    func testLineBreaksAndLongPreviews() {
        let text = "BofA Security: your card was used at:\n\nPROTON, $71.76, Declined, 11/25.\n\nDid you authorize this activity? Reply YES or NO. To opt out of fraud text alerts, reply STOP"
        let label = "Bank of America, Unread, BofA Security: your card was used at: PROTON, $71.76, Declined, 11/25. Did you authorize this activity? Reply YES or, 7:14 AM"
        XCTAssertTrue(MessagesReadMarker.rowMatches(label: label, messageText: text)) // only the first 100 characters count
    }
}

// Fork: Ask Before Filling popup placement
class ForkFillPopupTests: XCTestCase {
    let size = CGSize(width: 240, height: 40)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    func testSitsUnderTheField() {
        let field = CGRect(x: 500, y: 300, width: 200, height: 30) // AX: top-left origin
        let o = FillPopup.origin(field: field, size: size, primaryHeight: 900, visible: visible)
        XCTAssertEqual(o, CGPoint(x: 500, y: 900 - 330 - FillPopup.gap - 40))
    }

    func testFlipsAboveNearTheBottom() {
        let field = CGRect(x: 500, y: 860, width: 200, height: 30)
        let o = FillPopup.origin(field: field, size: size, primaryHeight: 900, visible: visible)
        XCTAssertEqual(o.y, 900 - 860 + FillPopup.gap)
    }

    func testStaysOnScreenAtTheRightEdge() {
        let field = CGRect(x: 1400, y: 300, width: 30, height: 30)
        XCTAssertEqual(FillPopup.origin(field: field, size: size, primaryHeight: 900, visible: visible).x, 1440 - 240)
    }
}
