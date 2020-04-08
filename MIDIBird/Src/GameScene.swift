
import SpriteKit
import MIKMIDI
import Percent



struct Obstacle {
    
    let openingSize: Percent
    let openingPosition: Percent
}


enum GameState: Equatable {
    
    case ready
    case started(numberOfObstaclesPassed: Int)
    case gameover
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
    
    var scoreLabelNode: SKLabelNode! = nil
    var currentScore: Int = 0 {
        didSet {
            print(self.currentScore)
            DispatchQueue.main.async {
                guard let label = self.scoreLabelNode else { return }
                label.text = "\(self.currentScore)"
            }
        }
    }
    
    
    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        self.characterNode = self.createCharacterNode()
        self.addChild(self.characterNode)

        self.scoreLabelNode = SKLabelNode()
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
    }
    
    
    func clearObstacleNodes() {
        
        self.removeChildren(in: self.obstacleNodesFromRightToLeft)
        self.obstacleNodesFromRightToLeft.removeAll()
    }
    
    
    func spawnNewObstacle(xPositionOfPreviousObstacle: CGFloat?) {
        
        guard case .started(let numberOfObstaclesPassed) = self.gameState else { return }
        
        let obstacleStandardSpacing: CGFloat = 400
        
        let obstacleOpeningSize = Percent.random(in: 40%...80%)
        let obstacleOpeningPosition = Percent.random(in: 25%...75%)
        let obstacleDistanceFromPreviousObstacle = obstacleStandardSpacing
        
        let obstacleXPosition = xPositionOfPreviousObstacle == nil ? (self.sceneViewPortHorizon.upperBound + self.obstacleWidth) : (xPositionOfPreviousObstacle! + obstacleDistanceFromPreviousObstacle)
        let obstacle = Obstacle(openingSize: obstacleOpeningSize, openingPosition: obstacleOpeningPosition)
        
        let node = self.createNode(for: obstacle)
        node.position = CGPoint(x: obstacleXPosition, y: 0)
        node.run(SKAction.repeatForever(SKAction.moveBy(x: -scrollingSpeed, y: 0, duration: 1)))
        self.addChild(node)
        register(obstacleNode: node)
    }
    
    
    func updateScore() {
        
        guard case .started(let numberOfObstaclesPassed) = self.gameState else { return }
        
        self.currentScore = numberOfObstaclesPassed
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
                
                self.gameState = .started(numberOfObstaclesPassed: numberOfObstaclesPassed + 1)
                
                self.updateScore()
                
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
