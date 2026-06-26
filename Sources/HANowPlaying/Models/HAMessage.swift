import Foundation

// MARK: - Outbound

struct HAAuthMessage: Encodable {
    let type = "auth"
    let accessToken: String
    enum CodingKeys: String, CodingKey {
        case type, accessToken = "access_token"
    }
}

struct HASubscribeEntitiesMessage: Encodable {
    let id: Int
    let type = "subscribe_entities"
}

struct HAGetStatesMessage: Encodable {
    let id: Int
    let type = "get_states"
}

struct HACallServiceMessage: Encodable {
    let id: Int
    let type = "call_service"
    let domain: String
    let service: String
    let target: HATarget?
    let serviceData: [String: ServiceValue]?
    enum CodingKeys: String, CodingKey {
        case id, type, domain, service, target
        case serviceData = "service_data"
    }
}

struct HATarget: Encodable {
    let entityId: String
    enum CodingKeys: String, CodingKey { case entityId = "entity_id" }
}

// MARK: - Inbound envelope

struct HAInboundMessage: Decodable {
    let type: String
    let id: Int?
    let haVersion: String?
    let message: String?
    let event: HAEvent?
    let result: HAResultPayload?
    let success: Bool?

    enum CodingKeys: String, CodingKey {
        case type, id, message, event, result, success
        case haVersion = "ha_version"
    }
}

/// A single `subscribe_entities` push from HA containing adds (`a`), changes (`c`), and removes (`r`).
struct HAEvent: Decodable {
    let add: [String: HAEntityState]?
    let change: [String: HAEntityChange]?
    let remove: [String]?

    enum CodingKeys: String, CodingKey {
        case add = "a"
        case change = "c"
        case remove = "r"
    }
}

struct HAEntityState: Decodable {
    let s: String
    let a: HAAttributes?
    let lu: Double?
}

/// A diff for one entity in a `subscribe_entities` change event. Changes are wrapped under a `"+"` key.
struct HAEntityChange: Decodable {
    struct Diff: Decodable {
        let s: String?
        let a: HAAttributes?
        let lu: Double?
    }
    let added: Diff?

    enum CodingKeys: String, CodingKey {
        case added = "+"
    }
}

// MARK: - Attributes

/// Full set of `media_player` attributes from HA, used both in initial state payloads and diffs.
struct HAAttributes: Decodable {
    let friendlyName: String?
    let mediaTitle: String?
    let mediaArtist: String?
    let mediaAlbumName: String?
    let mediaAlbumArtist: String?
    let mediaContentType: String?
    let mediaSeriesTitle: String?
    let mediaSeason: FlexibleString?
    let mediaEpisode: FlexibleString?
    let mediaChannel: String?
    let appName: String?
    let appId: String?
    let entityPicture: String?
    let mediaDuration: Double?
    let mediaPosition: Double?
    let mediaPositionUpdatedAt: String?
    let supportedFeatures: Int?
    let volumeLevel: Double?
    let isMuted: Bool?
    let shuffle: Bool?
    let repeatMode: String?

    enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
        case mediaTitle = "media_title"
        case mediaArtist = "media_artist"
        case mediaAlbumName = "media_album_name"
        case mediaAlbumArtist = "media_album_artist"
        case mediaContentType = "media_content_type"
        case mediaSeriesTitle = "media_series_title"
        case mediaSeason = "media_season"
        case mediaEpisode = "media_episode"
        case mediaChannel = "media_channel"
        case appName = "app_name"
        case appId = "app_id"
        case entityPicture = "entity_picture"
        case mediaDuration = "media_duration"
        case mediaPosition = "media_position"
        case mediaPositionUpdatedAt = "media_position_updated_at"
        case supportedFeatures = "supported_features"
        case volumeLevel = "volume_level"
        case isMuted = "is_volume_muted"
        case shuffle = "shuffle"
        case repeatMode = "repeat"
    }
}

struct HAResultPayload: Decodable {}

// MARK: - Helpers

// Decodes a value that some integrations send as String and others as Int (e.g. season/episode)
struct FlexibleString: Decodable {
    let stringValue: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { stringValue = s; return }
        if let i = try? c.decode(Int.self) { stringValue = String(i); return }
        if let d = try? c.decode(Double.self) { stringValue = String(Int(d)); return }
        throw DecodingError.typeMismatch(
            String.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Expected String or numeric")
        )
    }
}

enum ServiceValue: Encodable {
    case bool(Bool)
    case double(Double)
    case string(String)

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v):   try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }
}
