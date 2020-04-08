
import SpriteKit
import MIKMIDI
import Percent



struct Obstacle {
    
    let openingSize: Percent
    let openingPosition: Percent
}


enum GameState: Equatable {
    
    case ready
    case started(numberOfObstaclesPassed: UInt)
    case gameover
}


struct ObstaclesParameter {
    
    let openingSizeRange: ClosedRange<Percent>
    let openingPositionRange: ClosedRange<Percent>
}


struct CheckPoint {
    
    let numberOfObstaclesPassed: UInt
    let score: Int
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let scrollingSpeed: CGFloat = 200 // points per second
    
    let obstacleWidth: CGFloat = 20

    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var characterNode: SKNode!
    var obstacleNodesFromRightToLeft: [SKNode] = []
    
    var leftMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.last }
    var rightMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.first }
    
    let gameoverPhysicsBodyCategoryBitMask: UInt32 = 0b10
    let successPhysicsBodyCategoryBitMask: UInt32 = 0b01
    
    var gameState: GameState! = nil
    
    var characterDefaultPosition: CGPoint { CGPoint(x: 0, y: self.frame.height/2) }
    
    var sceneViewPortHorizon: ClosedRange<CGFloat> { (-self.frame.width/2)...(+self.frame.width/2) }
    var obstacleLivingRegion: ClosedRange<CGFloat> { self.sceneViewPortHorizon.extended(by: 100) }
    
    let obstaclesPerLevel = 5
    
    var mostRecentCheckPoint: CheckPoint?
    
    var scoreLabelNode: SKLabelNode! = nil
    
    var currentLevel: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                guard self.scoreLabelNode != nil else { return }
                self.updateScoreLabel()
            }
            if self.currentLevel > self.highestLevel {
                self.highestLevel = self.currentLevel
            }
        }
    }
    
    var currentScore: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                guard self.scoreLabelNode != nil else { return }
                self.updateScoreLabel()
            }
            if self.currentScore > self.highestScore {
                self.highestScore = self.currentScore
            }
        }
    }
    
    var highestLevel: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                guard self.scoreLabelNode != nil else { return }
                self.updateScoreLabel()
            }
            self.persistHighestLevel()
        }
    }
    
    var highestScore: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                guard self.scoreLabelNode != nil else { return }
                self.updateScoreLabel()
            }
            self.persistHighestScore()
        }
    }
    
    let highestLevelPersistanceKey = "highestLevel"
    let highestScorePersistanceKey = "highestScore"
    
    
    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        self.characterNode = self.createCharacterNode()
        self.addChild(self.characterNode)

        self.scoreLabelNode = SKLabelNode()
        self.scoreLabelNode.numberOfLines = 0
        self.scoreLabelNode.fontColor = .white
        self.scoreLabelNode.verticalAlignmentMode = .top
        self.scoreLabelNode.horizontalAlignmentMode = .right
        self.scoreLabelNode.position = CGPoint(x: self.frame.width/2 - 100, y: self.frame.height - 100)
        self.addChild(self.scoreLabelNode)
        
        self.resetGame()
        
        connectToMIDIDevice()
        
        view.showsPhysics = true
        
        physicsWorld.contactDelegate = self
        
        self.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -self.frame.width/2, y: 0),
                                               to: CGPoint(x: +self.frame.width/2, y: 0))
        self.physicsBody!.categoryBitMask = self.gameoverPhysicsBodyCategoryBitMask
        
        self.loadHighestScore()
        self.loadHighestLevel()
    }
    
    
    func loadHighestScore() {
        
        if let score = UserDefaults.standard.value(forKey: self.highestScorePersistanceKey) as? Int {
            self.highestScore = score
        }
    }
    
    
    func loadHighestLevel() {
        
        if let level = UserDefaults.standard.value(forKey: self.highestLevelPersistanceKey) as? Int {
            self.highestLevel = level
        }
    }
    
    
    func persistHighestScore() {
        
        UserDefaults.standard.set(self.highestScore, forKey: self.highestScorePersistanceKey)
    }
    
    
    func persistHighestLevel() {
        
        UserDefaults.standard.set(self.highestLevel, forKey: self.highestLevelPersistanceKey)
    }
    
    
    func updateScoreLabel() {
        
        self.scoreLabelNode.text = """
                    
                    Level: \(self.currentLevel)
                    Score: \(self.currentScore)
                    
                    Highest level: \(self.highestLevel)
                    Highest score: \(self.highestScore)
                    """
    }
    
    
    func clearObstacleNodes() {
        
        self.removeChildren(in: self.obstacleNodesFromRightToLeft)
        self.obstacleNodesFromRightToLeft.removeAll()
    }
    
    
    func spawnNewObstacle(xPositionOfPreviousObstacle: CGFloat?) {
        
        let level = self.currentLevel
        
        let levelConfigs: [ObstaclesParameter] = [
            ObstaclesParameter(openingSizeRange: 80%...90%, openingPositionRange: 40%...60%),
            ObstaclesParameter(openingSizeRange: 70%...80%, openingPositionRange: 40%...60%),
            ObstaclesParameter(openingSizeRange: 60%...70%, openingPositionRange: 40%...60%),
            ObstaclesParameter(openingSizeRange: 50%...60%, openingPositionRange: 40%...60%),
            ObstaclesParameter(openingSizeRange: 40%...50%, openingPositionRange: 40%...60%),
            ObstaclesParameter(openingSizeRange: 30%...40%, openingPositionRange: 30%...70%),
            ObstaclesParameter(openingSizeRange: 20%...30%, openingPositionRange: 20%...80%),
            ObstaclesParameter(openingSizeRange: 10%...20%, openingPositionRange: 10%...90%),
        ]
        
        let config = level < levelConfigs.count ? levelConfigs[level] : levelConfigs.last ?? ObstaclesParameter(openingSizeRange: 10%...90%, openingPositionRange: 40%...60%)
        
        let obstacleStandardSpacing: CGFloat = 400
        
        let obstacleOpeningSize = Percent.random(in: config.openingSizeRange)
        let obstacleOpeningPosition = Percent.random(in: config.openingPositionRange)
        let obstacleDistanceFromPreviousObstacle = obstacleStandardSpacing
        
        let obstacleXPosition = xPositionOfPreviousObstacle == nil ? (self.sceneViewPortHorizon.upperBound + self.obstacleWidth) : (xPositionOfPreviousObstacle! + obstacleDistanceFromPreviousObstacle)
        let obstacle = Obstacle(openingSize: obstacleOpeningSize, openingPosition: obstacleOpeningPosition)
        
        let node = self.createNode(for: obstacle)
        node.position = CGPoint(x: obstacleXPosition, y: 0)
        node.run(SKAction.repeatForever(SKAction.moveBy(x: -scrollingSpeed, y: 0, duration: 1)))
        self.addChild(node)
        register(obstacleNode: node)
    }
    
    
    func register(obstacleNode node: SKNode) {
        
        self.obstacleNodesFromRightToLeft.insert(node, at: 0)
    }
    
    
    func removeLeftMostObstacleNode() {
        
        self.obstacleNodesFromRightToLeft.popLast()?.removeFromParent()
    }
    
    
    func createCharacterNode() -> SKNode {
        
        let node = SKShapeNode(circleOfRadius: 10)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        node.physicsBody?.isDynamic = false

        node.physicsBody?.collisionBitMask = self.gameoverPhysicsBodyCategoryBitMask
        node.physicsBody?.contactTestBitMask = self.gameoverPhysicsBodyCategoryBitMask | self.successPhysicsBodyCategoryBitMask
        
        return node
    }
    
    
    func connectToMIDIDevice() {
        
        let device = MIKMIDIDeviceManager.shared.availableDevices.first(where: { $0.displayName == MIDIDeviceName })!
        
        try! MIKMIDIDeviceManager.shared.connect(device) { (_, commands) in
            commands.compactMap { $0 as? MIKMIDINoteOnCommand } .filter { $0.velocity > 0 } .forEach { command in
                self.onMIDIInput(command.velocity)
            }
        }
    }
    
    
    func onMIDIInput(_ velocity: UInt) {
        
        switch self.gameState {
            
        case .ready:
            
            self.enableCharacterGravity(true)
            self.gameState = .started(numberOfObstaclesPassed: 0)
            self.reloadMostRecentCheckPoint()
            
        case .started(_):
            
            self.resetCharacterVelocity()
            self.applyCharacterImpulse(with: velocity)
            
        default:
            
            return
        }
    }
    
    
    func resetGame() {
        
        self.clearObstacleNodes()
        
        self.resetCharacterPositionToDefaultPosition()
        self.resetCharacterVelocity()
        self.enableCharacterGravity(false)
        
        self.gameState = .ready
        
        self.currentScore = 0
        self.currentLevel = 0
    }
    
    
    func reloadMostRecentCheckPoint() {
        
        guard let checkPoint = self.mostRecentCheckPoint else { return }
        
        self.gameState = .started(numberOfObstaclesPassed: checkPoint.numberOfObstaclesPassed)
        self.currentScore = checkPoint.score
    }
    
    
    func applyCharacterImpulse(with velocity: UInt) {
        
        self.characterNode.physicsBody!.applyImpulse(CGVector(dx: 0, dy: CGFloat(velocity) * inputSensibility))
    }
    
    
    func resetCharacterPositionToDefaultPosition() {
        
        self.characterNode.position = self.characterDefaultPosition
    }
    
    
    func resetCharacterVelocity() {
        
        self.characterNode.physicsBody!.velocity = CGVector.zero
    }
    
    
    func enableCharacterGravity(_ characterGravityEnabled: Bool) {
        
        self.characterNode.physicsBody!.isDynamic = characterGravityEnabled
    }
    
    
    override func didFinishUpdate() {
        
        switch self.gameState {
        
        case .started(_):
         
            if let leftMostObstacleNode = self.leftMostObstacleNode {
                if leftMostObstacleNode.position.x < self.obstacleLivingRegion.lowerBound {
                    self.removeLeftMostObstacleNode()
                }
            }
            
            if let rightMostObstacleNode = rightMostObstacleNode {
                if rightMostObstacleNode.position.x < self.obstacleLivingRegion.upperBound {
                    self.spawnNewObstacle(xPositionOfPreviousObstacle: rightMostObstacleNode.position.x)
                }
            } else {
                self.spawnNewObstacle(xPositionOfPreviousObstacle: nil)
            }
            
        case .gameover:
            
            self.resetGame()
            
        default:
            
            return
        }
    }
    
    
    func createNode(for obstacle: Obstacle) -> SKNode {
        
        let relativeBottomHeight = obstacle.openingPosition.fraction - obstacle.openingSize.fraction/2.0
        let relativeTopHeight = (1 - obstacle.openingPosition.fraction) - obstacle.openingSize.fraction/2.0
        let relativeMiddleHeight = 1 - relativeBottomHeight - relativeTopHeight
        
        let absoluteBottomHeight = self.frame.height * CGFloat(relativeBottomHeight)
        let absoluteTopHeight = self.frame.height * CGFloat(relativeTopHeight)
        let absoluteMiddleHeight = self.frame.height * CGFloat(relativeMiddleHeight)
        
        let bottomNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                           y: 0,
                                                           width: obstacleWidth,
                                                           height: absoluteBottomHeight))
        bottomNode.position = CGPoint(x: 0, y: 0)
        bottomNode.physicsBody!.categoryBitMask = self.gameoverPhysicsBodyCategoryBitMask
        
        let middleNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                           y: 0,
                                                           width: obstacleWidth,
                                                           height: absoluteMiddleHeight))
        middleNode.position = CGPoint(x: 0, y: absoluteBottomHeight)
        middleNode.physicsBody!.categoryBitMask = self.successPhysicsBodyCategoryBitMask
        
        let topNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                        y: -absoluteTopHeight,
                                                        width: obstacleWidth,
                                                        height: absoluteTopHeight))
        topNode.position = CGPoint(x: 0, y: self.frame.height)
        topNode.physicsBody!.categoryBitMask = self.gameoverPhysicsBodyCategoryBitMask
        
        let rootNode = SKNode()
        rootNode.addChild(bottomNode)
        rootNode.addChild(middleNode)
        rootNode.addChild(topNode)
        
        return rootNode
    }
    
    
    func createObstaclePartWithRect(_ rect: CGRect) -> SKNode {
        
        let path = CGPath(rect: rect, transform: nil)
        
        let node = SKShapeNode(path: path)
        
        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.midX, y: rect.midY))
        node.physicsBody!.isDynamic = false
        
        return node
    }
}

extension GameScene: SKPhysicsContactDelegate {
    
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        let categoryBitMasks = [contact.bodyA, contact.bodyB].map { $0.categoryBitMask }
        
        switch self.gameState {
            
        case .started(let numberOfObstaclesPassed):
         
            if categoryBitMasks.contains(self.successPhysicsBodyCategoryBitMask) {
                
                let newNumberOfObstaclesPassed = numberOfObstaclesPassed + 1
                
                self.gameState = .started(numberOfObstaclesPassed: newNumberOfObstaclesPassed)
                
                self.currentLevel = Int(newNumberOfObstaclesPassed)/Int(self.obstaclesPerLevel)
                
                self.currentScore += 1
                
                self.mostRecentCheckPoint = CheckPoint(numberOfObstaclesPassed: newNumberOfObstaclesPassed, score: self.currentScore)
                
            } else if categoryBitMasks.contains(self.gameoverPhysicsBodyCategoryBitMask) {

                self.gameState = .gameover
            }
            
        default:
            
            return
        }
    }
}



extension Percent {
    
    
    static func random(in range: ClosedRange<Percent>) -> Percent {
        
        return Percent(fraction: Double.random(in: range.lowerBound.fraction...range.upperBound.fraction))
    }
}



extension ClosedRange where Bound == CGFloat {
    
    
    func extended(by value: CGFloat) -> ClosedRange<CGFloat> {
        
        (self.lowerBound - value)...(self.upperBound + value)
    }
}
