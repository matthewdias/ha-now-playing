import Testing
@testable import HANowPlaying
import Foundation

@Suite("HAMessage")
struct HAMessageTests {

    // MARK: - FlexibleString

    @Test func flexibleStringDecodesFromString() throws {
        let data = Data(#""hello""#.utf8)
        let result = try JSONDecoder().decode(FlexibleString.self, from: data)
        #expect(result.stringValue == "hello")
    }

    @Test func flexibleStringDecodesFromInt() throws {
        let data = Data("42".utf8)
        let result = try JSONDecoder().decode(FlexibleString.self, from: data)
        #expect(result.stringValue == "42")
    }

    @Test func flexibleStringDecodesFromDouble() throws {
        let data = Data("3.0".utf8)
        let result = try JSONDecoder().decode(FlexibleString.self, from: data)
        #expect(result.stringValue == "3")
    }

    // MARK: - HAEvent compact keys

    @Test func haeventDecodesCompactAddKey() throws {
        let json = Data("""
        {"a": {"media_player.foo": {"s": "playing", "lu": 0}}}
        """.utf8)
        let event = try JSONDecoder().decode(HAEvent.self, from: json)
        #expect(event.add?["media_player.foo"] != nil)
        #expect(event.change == nil)
        #expect(event.remove == nil)
    }

    @Test func haeventDecodesCompactChangeKey() throws {
        let json = Data("""
        {"c": {"media_player.foo": {"+": {"s": "paused"}}}}
        """.utf8)
        let event = try JSONDecoder().decode(HAEvent.self, from: json)
        #expect(event.change?["media_player.foo"] != nil)
    }

    @Test func haeventDecodesCompactRemoveKey() throws {
        let json = Data("""
        {"r": ["media_player.foo", "media_player.bar"]}
        """.utf8)
        let event = try JSONDecoder().decode(HAEvent.self, from: json)
        #expect(event.remove == ["media_player.foo", "media_player.bar"])
    }

    // MARK: - HAEntityChange "+" wrapper

    @Test func entityChangeUnwrapsPlusKey() throws {
        let json = Data("""
        {"+": {"s": "paused", "lu": 1700000000.0}}
        """.utf8)
        let change = try JSONDecoder().decode(HAEntityChange.self, from: json)
        #expect(change.added?.s == "paused")
        #expect(change.added?.lu == 1700000000.0)
    }

    @Test func entityChangeAddedNilWhenPlusKeyAbsent() throws {
        let json = Data("{}".utf8)
        let change = try JSONDecoder().decode(HAEntityChange.self, from: json)
        #expect(change.added == nil)
    }

    @Test func entityChangeAttributesDecodedUnderPlusKey() throws {
        let json = Data("""
        {"+": {"a": {"media_title": "Karma Police", "friendly_name": "Spotify"}}}
        """.utf8)
        let change = try JSONDecoder().decode(HAEntityChange.self, from: json)
        #expect(change.added?.a?.mediaTitle == "Karma Police")
        #expect(change.added?.a?.friendlyName == "Spotify")
    }

    // MARK: - ServiceValue encoding

    @Test func serviceValueEncodesBoolNotNumber() throws {
        let data = try JSONEncoder().encode(ServiceValue.bool(true))
        #expect(String(data: data, encoding: .utf8) == "true")
    }

    @Test func serviceValueEncodesFalse() throws {
        let data = try JSONEncoder().encode(ServiceValue.bool(false))
        #expect(String(data: data, encoding: .utf8) == "false")
    }

    @Test func serviceValueEncodesDouble() throws {
        let data = try JSONEncoder().encode(ServiceValue.double(0.75))
        #expect(String(data: data, encoding: .utf8) == "0.75")
    }

    @Test func serviceValueEncodesString() throws {
        let data = try JSONEncoder().encode(ServiceValue.string("all"))
        #expect(String(data: data, encoding: .utf8) == #""all""#)
    }
}
