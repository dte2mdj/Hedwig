//
//  SMTPTests.swift
//  Hedwig
//
//  Created by WANG WEI on 16/12/27.
//
//

import XCTest
@testable import Hedwig

private func logLocalServerNotUp() {
    print("----------------------------------------------------------------------------------")
    print("| WARNING: Local test server is not up. Local server test will not be performed! |")
    print("----------------------------------------------------------------------------------")
}

class SMTPTests: XCTestCase {
    
    var smtps: [SMTP]!
    
    override func setUp() {
        let smtp1 = try! SMTP(hostName: "smtp.mailgun.org", user: nil, password: nil, secure: .tls, domainName: "onevcat.com")
        let smtp2 = try! SMTP(hostName: "smtp.zoho.com", user: nil, password: nil, secure: .ssl, domainName: "onevcat.com")
        let smtp3 = try! SMTP(hostName: "smtp.gmail.com", user: nil, password: nil, secure: .plain, domainName: "onevcat.com")
        smtps = [smtp1, smtp2, smtp3]
        
        // Only test on local smtp server when accessible. 
        // Use `sudo npm start` in the test_smtp_server to start the test server.
        // After testing, use `sudo npm stop` to free the listened port.
        do {
            let smtp4 = try SMTP(hostName: "127.0.0.1", user: nil, password: nil, secure: .plain, domainName: "onevcat.com")
            defer { try? smtp4.close() }
            _ = try smtp4.connect()

            // Only add when local server is on
            smtps.append(smtp4)
            
        } catch {
            logLocalServerNotUp()
        }
    }
    
    override func tearDown() {
        if smtps != nil {
            smtps.forEach {
                try? $0.close()
            }
        }
    }
    
    func testSMTPConnect() {
        try! smtps.forEach { smtp in
            do {
                let res = try smtp.connect()
                XCTAssertEqual(res.code, .serviceReady)
            } catch {
                XCTFail("Should not catch an error, but got \(error)")
            }
            
            XCTAssertNoThrows(try smtp.close())
        }
    }
    
    func testSMTPCannotConnect() {
        XCTAssertThrowsError(
            try SMTP(hostName: "nosuchsite.org", user: nil, password: nil),
            "Unsupported host name should fail."
        )
    }
    
    func testSMTPSendHelo() {
        smtps.forEach { smtp in
            do {
                _ = try smtp.connect()
                let res = try smtp.helo()
                XCTAssertEqual(res.code, .commandOK)
            } catch {
                XCTFail("Should not catch an error, but got \(error)")
            }
        }
    }
    
    func testSMTPSendEhlo() {
        smtps.forEach { smtp in
            do {
                _ = try smtp.connect()
                let res = try smtp.ehlo()
                XCTAssertEqual(res.code, .commandOK)
            } catch {
                XCTFail("Should not catch an error, but got \(error)")
            }
        }
    }
    
    func testSMTPParseFeature() {
        let response = "250-ak47\n250-AUTH PLAIN LOGIN\n250-SIZE 52428800\n250-8BITMIME\n250-ENHANCEDSTATUSCODES\n250 STARTTLS"
        let feature = response.featureDictionary()
        XCTAssertTrue(feature.supported("ak47"))
        XCTAssertTrue(feature.supported(auth: .plain))
        XCTAssertTrue(feature.supported(auth: .login))
        XCTAssertFalse(feature.supported(auth: .cramMD5))
        
        XCTAssertTrue(feature.supported("ak47"))
        XCTAssertEqual(feature.value(for: "SIZE"), "52428800")
        XCTAssertTrue(feature.supported("8BITMIME"))
        XCTAssertTrue(feature.supported("ENHANCEDSTATUSCODES"))
        XCTAssertTrue(feature.supported("STARTTLS"))
    }
    
    func testSMTPAuth() {
        
        let methods: [SMTP.AuthMethod] = [.plain, .login, .cramMD5, .xOauth2]
        for method in methods {
            guard let smtp = try? SMTP(
                hostName: "127.0.0.1",
                user: "foo@bar.com",
                password: "password",
                secure: .plain,
                domainName: "onevcat.com",
                authMethods: [method]) else
            {
                logLocalServerNotUp()
                return
            }

            do {
                _ = try smtp.connect()
            } catch {
                logLocalServerNotUp()
                return
            }
            
            XCTAssertNoThrows(try smtp.login())
        }
    }
    
    func testSMTPAuthPlainErrorPassword() {
        guard let smtp = try? SMTP(
            hostName: "127.0.0.1",
            user: "foo@bar.com",
            password: "wrong_password",
            secure: .plain,
            domainName: "onevcat.com",
            authMethods: [.plain]) else
        {
            logLocalServerNotUp()
            return
        }

        do {
            _ = try smtp.connect()
        } catch {
            logLocalServerNotUp()
            return
        }

        do {
            try smtp.login()
            XCTFail("The login should fail due to wrong password")
        } catch SMTP.SMTPError.authFailed {
            
        } catch {
            XCTFail("The error type is not corrected. Expect \(SMTP.SMTPError.authFailed), but got \(error)")
        }
    }
    
    static var allTests : [(String, (SMTPTests) -> () throws -> Void)] {
        return [
            ("testSMTPConnect", testSMTPConnect),
            ("testSMTPCannotConnect", testSMTPCannotConnect),
            ("testSMTPSendHelo", testSMTPSendHelo),
            ("testSMTPSendEhlo", testSMTPSendEhlo),
            ("testSMTPParseFeature", testSMTPParseFeature),
            ("testSMTPAuth", testSMTPAuth),
            ("testSMTPAuthPlainErrorPassword", testSMTPAuthPlainErrorPassword)
        ]
    }
}
