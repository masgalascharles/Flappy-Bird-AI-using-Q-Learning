import SwiftUI

struct Pipe {
    static let size: CGSize = CGSize(width: 70, height: 70 * (CGFloat(320) / CGFloat(52)))
    static let initialX: CGFloat = GameView.gameSize.width / 2 + Pipe.size.width / 2
    static let minY: CGFloat = -GameView.gameSize.height / 2 - Pipe.size.height / 2 + Pipe.size.height / 3
    static let maxY: CGFloat = -GameView.gameSize.height / 2 + Pipe.size.height / 3
    static let horizontalGap: CGFloat = GameView.gameSize.width / 1.6
    static let verticalGap: CGFloat = GameView.gameSize.height / 4.68
    static let bonusPipeVerticalGap: CGFloat = GameView.gameSize.height / 5.5
    static let speed: CGFloat = 2.5
}

class PipePair: ObservableObject {
    @Published var topPipePosition: CGPoint
    @Published var bottomPipePosition: CGPoint
    @Published var passedBird: Bool
    @Published var image: String
    
    let isBonus: Bool
    let id: UUID = UUID()
    
    init() {
        self.isBonus = (Int.random(in: 1...40) == 1)
        
        let topPipeY: CGFloat = .random(in: Pipe.minY...Pipe.maxY)
        let bottomPipeY: CGFloat = topPipeY + Pipe.size.height + (self.isBonus ? Pipe.bonusPipeVerticalGap : Pipe.verticalGap)
        
        self.topPipePosition = CGPoint(x: Pipe.initialX, y: topPipeY)
        self.bottomPipePosition = CGPoint(x: Pipe.initialX, y: bottomPipeY)
        self.passedBird = false
        self.image = (self.isBonus ? "RedPipe" : "GreenPipe")
    }
}

class Bird: ObservableObject {
    let initialPosition: CGPoint
    let gravity: Double = 0.7
    let flapStrength: Double = 11.5
    let initialEpsilon: CGFloat
    let minEpsilon: CGFloat
    
    var velocityY: Double = 0
    var hitboxDiameter: CGFloat
    var qTable: [CGFloat: [Double]] = [:]
    var learningRate: Double
    var discountFactor: Double
    var lastState: CGFloat? = nil
    var lastAction: Int? = nil
    
    @Published var position: CGPoint
    @Published var size: CGSize
    @Published var images: [String: String]
    @Published var epsilon: CGFloat
    @Published var lastQTableUpdate: String? = nil
    @Published var last5Actions: [Int] = []
    
    init(initialPosition: CGPoint, size: CGSize, hitboxDiameter: CGFloat, initialEpsilon: CGFloat, minEpsilon: CGFloat, learningRate: Double, discountFactor: Double) {
        self.initialPosition = initialPosition
        self.position = initialPosition
        self.size = size
        self.hitboxDiameter = hitboxDiameter
        self.images = [:]
        self.initialEpsilon = initialEpsilon
        self.minEpsilon = minEpsilon
        self.epsilon = initialEpsilon
        self.learningRate = learningRate
        self.discountFactor = discountFactor
        
        self.setRandomImages()
    }
    
    func resetPosition() {
        self.position = self.initialPosition
        self.velocityY = 0
    }
    
    func update() {
        self.velocityY += self.gravity
        self.position.y += self.velocityY
    }
    
    func initQValues(state: CGFloat) {
        self.qTable[state] = [0, 0]
    }
    
    func getQValues(state: CGFloat) -> [Double] {
        if self.qTable[state] == nil {
            self.initQValues(state: state)
        }
        
        let qValues: [Double] = self.qTable[state]!
        
        return qValues
    }
    
    func updateQTable(state: CGFloat, action: Int, nextState: CGFloat, reward: Double) {
        if self.qTable[state] == nil {
            self.initQValues(state: state)
        }
        if self.qTable[nextState] == nil {
            self.initQValues(state: nextState)
        }
        
        let maxFutureQValue: Double = self.qTable[nextState]!.max()!
        
        self.qTable[state]![action] = self.qTable[state]![action] + self.learningRate * (reward + self.discountFactor * maxFutureQValue - self.qTable[state]![action])
        self.lastQTableUpdate = "\(state): [\(roundToNearestThousandth(self.qTable[state]![0])), \(roundToNearestThousandth(self.qTable[state]![1]))]"
    }
    
    func saveQTable(key: String) {
        let stringKeyQTable = Dictionary(uniqueKeysWithValues: self.qTable.map { (key, value) in
            (String(describing: key), value)
        })
        
        UserDefaults.standard.set(stringKeyQTable, forKey: key)
    }
    
    func loadQTable(key: String) {
        if let stringKeyQTable = UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]] {
            let cgFloatKeyQTable = Dictionary(uniqueKeysWithValues: stringKeyQTable.compactMap { (stringKey, value) in
                if let cgFloatKey = Double(stringKey) {
                    return (CGFloat(cgFloatKey), value)
                }
                
                return nil
            })
            
            self.qTable = cgFloatKeyQTable
        }
    }
    
    func getBestLearnedAction(state: CGFloat) -> Int {
        if self.qTable[state] == nil {
            self.initQValues(state: state)
        }
        
        let maxQValue: Double = self.qTable[state]!.max()!
        let bestLearnedAction: Int = self.qTable[state]!.firstIndex(of: maxQValue)!
        
        return bestLearnedAction
    }
    
    func chooseAction(state: CGFloat) -> Int {
        let randomNumber: CGFloat = .random(in: 0...1)
        var action: Int = (Int.random(in: 1...20) == 1 ? 1 : 0)
        
        if randomNumber > self.epsilon || (randomNumber == 0 && self.epsilon == 0) {
            action = self.getBestLearnedAction(state: state)
        }
        
        return action
    }
    
    func getReward(state: CGFloat, action: Int) -> Double {
        if state > -20 {
            if action == 0 {
                return -2
            }
            
            return 1
        }
        
        if action == 0 {
            return 1
        }
        
        return -2
    }
    
    func flap() {
        if self.position.y > -GameView.gameSize.height / 2 {
            self.velocityY = -flapStrength
        }
    }
    
    func setRandomImages() {
        let colors: [String] = ["Yellow", "Red", "Blue"]
        let randomColor: String = colors.randomElement()!
        
        self.images = [
            "upFlap": "\(randomColor)BirdUpFlap",
            "midFlap": "\(randomColor)BirdMidFlap",
            "downFlap": "\(randomColor)BirdDownFlap"
        ]
    }
    
    func isGameOver(pipePairs: [PipePair], groundPositions: [CGPoint]) -> Bool {
        for pipePair in pipePairs {
            let topPipeDistance: CGFloat = getDistance(point1: self.position, point2: pipePair.topPipePosition)
            let bottomPipeDistance: CGFloat = getDistance(point1: self.position, point2: pipePair.bottomPipePosition)
            let closestPipePosition: CGPoint = (topPipeDistance < bottomPipeDistance ? pipePair.topPipePosition : pipePair.bottomPipePosition)
            let closestPipeTop: CGFloat = closestPipePosition.y - Pipe.size.height / 2
            let closestPipeBottom: CGFloat = closestPipePosition.y + Pipe.size.height / 2
            let closestPipeLeft: CGFloat = closestPipePosition.x - Pipe.size.width / 2
            let closestPipeRight: CGFloat = closestPipePosition.x + Pipe.size.width / 2
            let closestX: CGFloat = max(closestPipeLeft, min(self.position.x, closestPipeRight))
            let closestY = max(closestPipeTop, min(self.position.y, closestPipeBottom))
            let closestPoint = CGPoint(x: closestX, y: closestY)
            
            if getDistance(point1: self.position, point2: closestPoint) < self.hitboxDiameter / 2 {
                return true
            }
        }
        
        return (self.position.y > groundPositions.first!.y - GameView.groundSize.height / 2 - self.hitboxDiameter / 2)
    }
}
