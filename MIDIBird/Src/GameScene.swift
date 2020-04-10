
import SpriteKit
import MIKMIDI
import Percent



struct Obstacle {
    
    let openingSize: Percent
    let openingPosition: Percent
}


struct ObstaclesParameter {
    
    let openingSizeRange: ClosedRange<Percent>
    let openingPositionRange: ClosedRange<Percent>
}


enum GameState: Equatable {
    
    case ready
    case started
    case gameover
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let scrollingSpeed: CGFloat = 200 // points per second
    let obstacleWidth: CGFloat = 20
    
    let gameoverPhysicsBodyCategoryBitMask: UInt32 = 0b10
    let successPhysicsBodyCategoryBitMask: UInt32 = 0b01
    
    let highscorePersistanceKey = "highscore"
    
    
    var characterDefaultPosition: CGPoint { CGPoint(x: 0, y: self.frame.height/2) }
    
    var sceneViewPortHorizon: ClosedRange<CGFloat> { (-self.frame.width/2)...(+self.frame.width/2) }
    var obstacleLivingRegion: ClosedRange<CGFloat> { self.sceneViewPortHorizon.extended(by: 100) }
    
    
    var characterNode: SKNode! = nil
    var obstacleNodesFromRightToLeft: [SKNode] = []
    
    var leftMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.last }
    var rightMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.first }
    
    var scoreLabelNode: SKLabelNode! = nil
    var deviceLabelNode: SKLabelNode! = nil
    
    
    var gameState: GameState! = nil
    
    var numberOfObstaclesGenerated: Int = 0

    var currentScore: Int = 0
    var highscore: Int = 0
    
    
    var MIDIDevice: MIKMIDIDevice! = nil
    
    var customDelegate: GameSceneDelegate?
    
    
    override func didMove(to view: SKView) {
        
        #if DEBUG
            view.showsPhysics = true
        #endif
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        self.characterNode = self.createCharacterNode()
        self.addChild(self.characterNode)

        self.scoreLabelNode = self.createScoreLabelNode()
        self.scoreLabelNode.verticalAlignmentMode = .top
        self.scoreLabelNode.horizontalAlignmentMode = .right
        self.scoreLabelNode.position = CGPoint(x: self.frame.width/2 - 100, y: self.frame.height - 100)
        self.addChild(self.scoreLabelNode)
        
        self.deviceLabelNode = self.createDeviceLabelNode()
        self.deviceLabelNode.verticalAlignmentMode = .top
        self.deviceLabelNode.horizontalAlignmentMode = .right
        self.deviceLabelNode.position = CGPoint(x: self.frame.width/2 - 100, y: 100)
        self.addChild(self.deviceLabelNode)
        
        self.physicsWorld.contactDelegate = self
        self.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -self.frame.width/2, y: 0), to: CGPoint(x: +self.frame.width/2, y: 0))
        self.physicsBody!.categoryBitMask = self.gameoverPhysicsBodyCategoryBitMask
        
        self.loadHighscore()
        self.updateScoreLabel()
        
        self.updateDeviceLabel()
        
        self.resetGame()
        
        if self.MIDIDevice != nil {
            self.connectToMIDIDevice()
        } else {
            self.triggerDeviceSelection()
        }
    }
    
    
    func createCharacterNode() -> SKNode {
        
        let node = SKShapeNode(circleOfRadius: 10)
        
        node.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        node.physicsBody!.isDynamic = false

        node.physicsBody!.collisionBitMask = self.gameoverPhysicsBodyCategoryBitMask
        node.physicsBody!.contactTestBitMask = self.gameoverPhysicsBodyCategoryBitMask | self.successPhysicsBodyCategoryBitMask
        
        return node
    }
    
    
    func createScoreLabelNode() -> SKLabelNode {
        
        let labelNode = SKLabelNode()
        
        labelNode.numberOfLines = 0
        labelNode.fontColor = .white
        
        return labelNode
    }
    
    
    func createDeviceLabelNode() -> SKLabelNode {
        
        let labelNode = SKLabelNode()
        
        labelNode.numberOfLines = 0
        labelNode.fontColor = .white
        
        return labelNode
    }
    
    
    func loadHighscore() {
        
        if let score = UserDefaults.standard.value(forKey: self.highscorePersistanceKey) as? Int {
            self.highscore = score
        }
    }
    
    
    func persistHighscore() {
        
        UserDefaults.standard.set(self.highscore, forKey: self.highscorePersistanceKey)
    }
    
    
    func updateScoreLabel() {
        
        self.scoreLabelNode.text = """
                    Score: \(self.currentScore)
                    Best: \(self.highscore)
                    """
    }
    
    
    func updateDeviceLabel() {
        
        self.deviceLabelNode.text = self.MIDIDevice?.displayName ?? ""
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if let touch = touches.first {
            if let node = nodes(at: touch.location(in: self)).first {
                if node == self.deviceLabelNode {
                    
                    self.triggerDeviceSelection()
                }
            }
        }
    }
    
    
    func triggerDeviceSelection() {
        
        self.isPaused = true
        self.customDelegate?.didTriggerDeviceSelection()
    }
    
    
    func didSelectDevice() {
        
        self.updateDeviceLabel()
        self.connectToMIDIDevice()
        self.isPaused = false
    }
    
    
    func connectToMIDIDevice() {
        
        let device = self.MIDIDevice!
        
        try! MIKMIDIDeviceManager.shared.connect(device) { (_, commands) in
            commands.compactMap { $0 as? MIKMIDINoteOnCommand } .filter { $0.velocity > 0 } .forEach { command in
                self.onMIDIInput(command.velocity)
            }
        }
    }
    
    
    func onMIDIInput(_ velocity: UInt) {
        
        switch self.gameState {
            
        case .ready:
            
            self.startGame()
            
        case .started:
            
            self.resetCharacterVelocity()
            self.applyCharacterImpulse(with: velocity)
            
        default:
            
            return
        }
    }
    
    
    func spawnNewObstacle(xPositionOfPreviousObstacle: CGFloat?) {
        
        let numberOfObstaclesGenerated = self.numberOfObstaclesGenerated
        
        let reductionAtEachStep: Double = 1.05    // value the factor value is divided by at each step
        let reductionFactor = Percent(fraction: pow(reductionAtEachStep, -Double(numberOfObstaclesGenerated)))
        
        let obstacleOpeningSizeRange = 1%...30%
        let obstacleOpeningSize = reductionFactor * obstacleOpeningSizeRange.width + obstacleOpeningSizeRange.lowerBound
        
        let obstacleOpeningPositionCenter = 50%
        let obstacleOpeningPositionWindowRange = 0%...40%
        let obstacleOpeningPositionWindowWidth = (100% - reductionFactor) * obstacleOpeningPositionWindowRange.width + obstacleOpeningPositionWindowRange.lowerBound
        let obstacleOpeningPosition = Percent.random(in: Percent.range(ofWidth: obstacleOpeningPositionWindowWidth, centeredOn: obstacleOpeningPositionCenter))
        
        let obstacleStandardSpacing: CGFloat = 400
        let obstacleDistanceFromPreviousObstacle = obstacleStandardSpacing
        
        let obstacleXPosition = xPositionOfPreviousObstacle == nil ? (self.sceneViewPortHorizon.upperBound + self.obstacleWidth) : (xPositionOfPreviousObstacle! + obstacleDistanceFromPreviousObstacle)
        let obstacle = Obstacle(openingSize: obstacleOpeningSize, openingPosition: obstacleOpeningPosition)
        
        let node = self.createNode(for: obstacle)
        node.position = CGPoint(x: obstacleXPosition, y: 0)
        node.run(SKAction.repeatForever(SKAction.moveBy(x: -scrollingSpeed, y: 0, duration: 1)))
        self.addChild(node)
        register(obstacleNode: node)
        
        self.numberOfObstaclesGenerated += 1
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
    
    
    func register(obstacleNode node: SKNode) {
        
        self.obstacleNodesFromRightToLeft.insert(node, at: 0)
    }
    
    
    func removeLeftMostObstacleNode() {
        
        self.obstacleNodesFromRightToLeft.popLast()?.removeFromParent()
    }
    
    
    func clearObstacleNodes() {
        
        self.removeChildren(in: self.obstacleNodesFromRightToLeft)
        self.obstacleNodesFromRightToLeft.removeAll()
    }
    
    
    func startGame() {
        
        self.enableCharacterGravity(true)
        self.gameState = .started
    }
    
    
    func resetGame() {
        
        self.clearObstacleNodes()
        
        self.resetCharacterPositionToDefaultPosition()
        self.resetCharacterVelocity()
        self.enableCharacterGravity(false)
        
        self.gameState = .ready
        
        self.numberOfObstaclesGenerated = 0
        self.currentScore = 0
        
        self.updateScoreLabel()
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
    
    
    func applyCharacterImpulse(with velocity: UInt) {
        
        self.characterNode.physicsBody!.applyImpulse(CGVector(dx: 0, dy: CGFloat(velocity) * inputSensibility))
    }
    
    
    func didCollideWithObstacleOrGround() {
        
        self.gameState = .gameover
    }
    
    
    func didPassObstacle() {
        
        self.currentScore += 1
        self.highscore = max(self.highscore, self.currentScore)
        
        self.updateScoreLabel()
        self.persistHighscore()
    }
    
    
    override func didFinishUpdate() {
        
        switch self.gameState {
        
        case .started:
         
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
}


extension GameScene: SKPhysicsContactDelegate {
    
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        let categoryBitMasks = [contact.bodyA, contact.bodyB].map { $0.categoryBitMask }
        
        switch self.gameState {
            
        case .started:
         
            if categoryBitMasks.contains(self.successPhysicsBodyCategoryBitMask) {
                
                self.didPassObstacle()
                
            } else if categoryBitMasks.contains(self.gameoverPhysicsBodyCategoryBitMask) {

                self.didCollideWithObstacleOrGround()
            }
            
        default:
            
            return
        }
    }
}



protocol GameSceneDelegate {
    
    
    func didTriggerDeviceSelection()
}


extension Percent {
    
    
    static func range(ofWidth width: Percent, centeredOn centerValue: Percent) -> ClosedRange<Percent> {
        
        return (centerValue - width/2)...(centerValue + width/2)
    }
    
    
    static func random(in range: ClosedRange<Percent>) -> Percent {
        
        return Percent(fraction: Double.random(in: range.lowerBound.fraction...range.upperBound.fraction))
    }
    
    
    public static func * (lhs: Self, rhs: Self) -> Self {
        
        self.init(fraction: lhs.fraction * rhs.fraction)
    }
}



extension ClosedRange where Bound == CGFloat {

    
    func extended(by value: CGFloat) -> ClosedRange<CGFloat> {
        
        return (self.lowerBound - value)...(self.upperBound + value)
    }
}



extension ClosedRange where Bound == Percent {
    
    
    var width: Percent {
        
        return self.upperBound - self.lowerBound
    }
}
