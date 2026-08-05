import Foundation

public struct NinjabrainResponse: Codable {
    public let resultType: String
    public let predictions: [PredictionDto]?
    public let playerPosition: PlayerPositionDto?
}

public struct PredictionDto: Codable {
    public let chunkX: Int
    public let chunkZ: Int
    public let certainty: Double
    public let overworldDistance: Double
}

public struct PlayerPositionDto: Codable {
    public let xInOverworld: Double?
    public let zInOverworld: Double?
    public let horizontalAngle: Double?
    public let isInOverworld: Bool?
    public let isInNether: Bool?
}
