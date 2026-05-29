import SwiftUI

struct GameView: View {
    enum GameState {
        case initial
        case running
        case over
    }
    
    @StateObject var bird: Bird = Bird(
        initialPosition: CGPoint(x: -120, y: -250),
        size: CGSize(width: 40 * (CGFloat(34) / CGFloat(24)), height: 40),
        hitboxDiameter: 40,
        initialEpsilon: Config.initialEpsilon,
        minEpsilon: Config.minEpsilon,
        learningRate: Config.learningRate,
        discountFactor: Config.discountFactor
    )
    
    @State var backgroundPositions: [CGPoint] = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: GameView.gameSize.width, y: 0)
    ]
    
    @State var groundPositions: [CGPoint] = [
        CGPoint(x: 0, y: GameView.gameSize.height / 2 - GameView.groundSize.height / 2),
        CGPoint(x: GameView.gameSize.width / 2 + GameView.groundSize.width / 2, y: GameView.gameSize.height / 2 - GameView.groundSize.height / 2)
    ]
    
    @State var pipePairs: [PipePair] = []
    @State var gameStarted: Bool = false
    @State var gameOver: Bool = false
    @State var gamePaused: Bool = false
    @State var gameState: GameState = .initial
    @State var tapCountdownText: String? = nil
    @State var score: Int = 0
    @AppStorage("highScore") var highScore: Int = 0
    
    static let gameSize: CGSize = CGSize(width: 400, height: UIScreen.main.bounds.height)
    static let groundSize: CGSize = CGSize(width: GameView.gameSize.width, height: GameView.gameSize.width / 3)
    
    let frameTime: TimeInterval = 1 / 60
    let backgroundSpeed: CGFloat = Pipe.speed * 0.6
    let tapCountdownTime: Double = 1
    
    func restartGame() {
        pipePairs = []
        backgroundPositions = [CGPoint(x: 0, y: 0), CGPoint(x: GameView.gameSize.width, y: 0)]
        gameState = .running
        score = 0
        bird.lastState = nil
        bird.lastAction = nil
        
        bird.resetPosition()
        pipePairs.append(PipePair())
    }
    
    func getBirdState() -> CGFloat {
        var nextPipePair: PipePair? = nil
        
        for pipePair in pipePairs {
            if pipePair.topPipePosition.x + Pipe.size.width / 2 > bird.position.x - bird.hitboxDiameter / 2 {
                nextPipePair = pipePair
                
                break
            }
        }
        
        let yDistanceToNextPipePair: CGFloat = (bird.position.y + bird.hitboxDiameter / 2) - (nextPipePair!.bottomPipePosition.y - Pipe.size.height / 2)
        
        return round(yDistanceToNextPipePair)
    }
    
    var body: some View {
        ZStack {
            ForEach(backgroundPositions.indices, id: \.self) { i in
                Image("Background")
                    .resizable()
                    .frame(width: GameView.gameSize.width, height: GameView.gameSize.height)
                    .offset(x: backgroundPositions[i].x, y: backgroundPositions[i].y)
            }
            
            Image(bird.velocityY < 0 ? bird.images["downFlap"]! : (bird.velocityY > 2.5 ? bird.images["upFlap"]! : bird.images["midFlap"]!))
                .resizable()
                .frame(width: bird.size.width, height: bird.size.height)
                .rotationEffect(Angle(degrees: max(min(bird.velocityY * 3, 90), -90)))
                .offset(x: bird.position.x, y: bird.position.y)
            
            ForEach(pipePairs.indices, id: \.self) { i in
                Image(pipePairs[i].image)
                    .resizable()
                    .frame(width: Pipe.size.width, height: Pipe.size.height)
                    .rotationEffect(Angle(degrees: 180))
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: pipePairs[i].topPipePosition.x, y: pipePairs[i].topPipePosition.y)
                
                Image(pipePairs[i].image)
                    .resizable()
                    .frame(width: Pipe.size.width, height: Pipe.size.height)
                    .offset(x: pipePairs[i].bottomPipePosition.x, y: pipePairs[i].bottomPipePosition.y)
                
                ForEach(bird.qTable.keys.sorted(), id: \.self) { j in
                    let maxQValue = bird.qTable[j]!.max()!
                    let color: Color = (maxQValue == bird.qTable[j]![0] ? .red : .green)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: GameView.gameSize.width / 6, height: 1)
                        .offset(x: -GameView.gameSize.width / 2, y: pipePairs[i].bottomPipePosition.y - Pipe.size.height / 2 + j)
                }
            }
            
            ForEach(groundPositions.indices, id: \.self) { i in
                Image("Ground")
                    .resizable()
                    .frame(width: GameView.groundSize.width, height: GameView.groundSize.height)
                    .offset(x: groundPositions[i].x, y: groundPositions[i].y)
            }
            
            Rectangle()
                .fill(.black)
                .frame(width: (UIScreen.main.bounds.width - GameView.gameSize.width) / 2, height: GameView.gameSize.height)
                .offset(x: (-UIScreen.main.bounds.width - GameView.gameSize.width) / 4)
            
            Rectangle()
                .fill(.black)
                .frame(width: (UIScreen.main.bounds.width - GameView.gameSize.width) / 2, height: GameView.gameSize.height)
                .offset(x: (UIScreen.main.bounds.width + GameView.gameSize.width) / 4)
            
            Text(tapCountdownText == nil ? (gameState == .over ? "Tap to Retry" : "Tap to Start") : tapCountdownText ?? "")
                .font(.system(size: 30, design: .monospaced))
                .foregroundStyle(.black)
                .opacity(gameState == .running ? 0 : 1)
        
            Text("SCORE: \(score)  HI: \(highScore)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .offset(y: -GameView.gameSize.height / 2 + 60)
            
            Text("EPSILON: \(bird.epsilon)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .offset(y: GameView.gameSize.height / 2 - 90)
            
            Text(bird.lastQTableUpdate ?? "")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .offset(y: GameView.gameSize.height / 2 - 60)
            
            Text("\(bird.last5Actions)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .offset(y: GameView.gameSize.height / 2 - 30)
        }
        .ignoresSafeArea()
        .onAppear {
            if Config.useSavedQTable {
                bird.loadQTable(key: "qTable")
            }
            
            restartGame()
        }
        .onReceive(Timer.publish(every: frameTime, on: .main, in: .common).autoconnect()) { _ in
            if gameState == .running {
                for pipePair in pipePairs {
                    pipePair.topPipePosition.x -= Pipe.speed
                    pipePair.bottomPipePosition.x = pipePair.topPipePosition.x
                    
                    if pipePair.topPipePosition.x <= -GameView.gameSize.width / 2 - Pipe.size.width / 2 {
                        let index: Int = pipePairs.firstIndex(where: {$0.id == pipePair.id})!
                        
                        pipePairs.remove(at: index)
                    }
                    else if !pipePair.passedBird && pipePair.topPipePosition.x < bird.position.x - bird.size.width / 2 - Pipe.size.width / 2 {
                        score += (pipePair.isBonus ? 20 : 1)
                        pipePair.passedBird = true
                        
                        if score > highScore {
                            highScore = score
                        }
                    }
                }
                
                if pipePairs.last!.topPipePosition.x < GameView.gameSize.width / 2 - Pipe.horizontalGap {
                    pipePairs.append(PipePair())
                }
                
                groundPositions[0].x -= Pipe.speed
                
                for i in 1..<groundPositions.count {
                    groundPositions[i].x = groundPositions[0].x + GameView.groundSize.width
                }
                
                if groundPositions.first!.x <= -GameView.gameSize.width / 2 - GameView.groundSize.width / 2 {
                    groundPositions.removeFirst()
                    groundPositions.append(CGPoint(x: GameView.gameSize.width / 2 + GameView.groundSize.width / 2, y: groundPositions.first!.y))
                }
                
                backgroundPositions[0].x -= backgroundSpeed
                
                for i in 1..<backgroundPositions.count {
                    backgroundPositions[i].x = backgroundPositions[i - 1].x + GameView.gameSize.width
                }
                
                if backgroundPositions.first!.x <= -GameView.gameSize.width {
                    backgroundPositions.removeFirst()
                    backgroundPositions.append(CGPoint(x: GameView.gameSize.width, y: backgroundPositions.first!.y))
                }
                
                let state: CGFloat = getBirdState()
                let action: Int = bird.chooseAction(state: state)
                
                bird.last5Actions.append(action)
                
                if bird.last5Actions.count > 5 {
                    bird.last5Actions.removeFirst()
                }
                
                if bird.lastState != nil && bird.lastAction != nil {
                    let reward: Double = bird.getReward(state: bird.lastState!, action: bird.lastAction!)
                    
                    bird.updateQTable(state: bird.lastState!, action: bird.lastAction!, nextState: state, reward: reward)
                    bird.saveQTable(key: "qTable")
                }
                
                bird.lastState = state
                bird.lastAction = action
                
                if action == 1 {
                    bird.flap()
                }
                
                if bird.epsilon > bird.minEpsilon {
                    bird.epsilon -= (bird.initialEpsilon - bird.minEpsilon) / CGFloat(Config.episodes)
                    
                    if bird.epsilon < bird.minEpsilon {
                        bird.epsilon = bird.minEpsilon
                    }
                }
                
                bird.update()
                
                if bird.isGameOver(pipePairs: pipePairs, groundPositions: groundPositions) {
                    let reward: Double = bird.getReward(state: bird.lastState!, action: bird.lastAction!)
                    
                    bird.updateQTable(state: bird.lastState!, action: bird.lastAction!, nextState: state, reward: reward)
                    
                    gameState = .over
                    tapCountdownText = "..."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + tapCountdownTime / 3) {
                        tapCountdownText = ".."
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + tapCountdownTime / 3) {
                            tapCountdownText = "."
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + tapCountdownTime / 3) {
                                tapCountdownText = nil
                                
                                restartGame()
                            }
                        }
                    }
                }
            }
        }
    }
}
