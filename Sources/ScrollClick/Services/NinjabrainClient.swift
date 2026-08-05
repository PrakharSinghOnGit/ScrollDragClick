import Foundation

public struct DisplayPrediction: Identifiable {
    public let id = UUID()
    public let coords: String
    public let netherCoords: String
    public let percent: String
    public let angle: String
    public let distance: String
}

public final class NinjabrainClient: ObservableObject {
    public static let shared = NinjabrainClient()
    
    @Published public var topPredictions: [DisplayPrediction] = []
    
    private var timer: Timer?
    
    private init() {}
    
    public func start(pollRateMs: Int) {
        timer?.invalidate()
        let interval = max(0.1, Double(pollRateMs) / 1000.0)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.topPredictions = []
        }
    }
    
    private func fetch() {
        guard let url = URL(string: "http://127.0.0.1:52533/api/v1/stronghold") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5 // Fast timeout for local API
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode(NinjabrainResponse.self, from: data)
                self.process(response: decoded)
            } catch {
                // Silently ignore decode errors or connection refused, as bot might not be running
            }
        }.resume()
    }
    
    private func process(response: NinjabrainResponse) {
        guard let preds = response.predictions, !preds.isEmpty else {
            DispatchQueue.main.async { self.topPredictions = [] }
            return
        }
        
        let maxRows = ConfigStore.shared.config.ninjabrainMaxRows
        let top = Array(preds.prefix(maxRows))
        
        let playerX = response.playerPosition?.xInOverworld
        let playerZ = response.playerPosition?.zInOverworld
        
        var newDisplay: [DisplayPrediction] = []
        
        for p in top {
            let sx = p.chunkX * 16 + 4
            let sz = p.chunkZ * 16 + 4
            
            let coords = "(\(sx), \(sz))"
            
            let nx = Double(sx) / 8.0
            let nz = Double(sz) / 8.0
            let netherCoords = String(format: "(%.1f, %.1f)", nx, nz)
            
            let percentStr = String(format: "%.1f%%", p.certainty * 100.0)
            let distStr = String(format: "%.1f", p.overworldDistance)
            
            var angleStr = "N/A"
            if let px = playerX, let pz = playerZ {
                let dx = Double(sx) - px
                let dz = Double(sz) - pz
                
                // Minecraft angle logic (0 is +Z, 90 is -X, 180 is -Z, -90 is +X)
                // standard atan2(dz, dx) with offset
                var rad = atan2(dz, dx)
                // convert to minecraft degrees
                var mcAngle = (rad * 180.0 / .pi) - 90.0
                if mcAngle < -180.0 { mcAngle += 360.0 }
                if mcAngle > 180.0 { mcAngle -= 360.0 }
                
                angleStr = String(format: "%.2f", mcAngle)
            }
            
            newDisplay.append(DisplayPrediction(
                coords: coords,
                netherCoords: netherCoords,
                percent: percentStr,
                angle: angleStr,
                distance: distStr
            ))
        }
        
        DispatchQueue.main.async {
            self.topPredictions = newDisplay
        }
    }
}
