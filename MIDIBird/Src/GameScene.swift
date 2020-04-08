
import SpriteKit
import MIKMIDI
import Percent



struct Obstacle {
    
    let openingSize: Percent
    let openingPosition: Percent
}


enum GameState {
    
    case ready
    case started
    case gameover
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let scrollingSpeed: CGFloat = 200 // points per second
    
    let obstacleWidth: CGFloat = 20
    let obstacleSpacing: CGFloat = 400
    
    let obstacleSizeRange = 40%...80%
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var characterNode: SKNode!
    var obstacleNodesFromRightToLeft: [SKNode] = []
    
    var leftMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.last }
    var rightMostObstacleNode: SKNode? { self.obstacleNodesFromRightToLeft.first }
    
    let mainContactTestBitMask: UInt32 = 1
    
    var gameState: GameState! = nil
    
    var characterDefaultPosition: CGPoint { CGPoint(x: 0, y: self.frame.height/2) }
    
    var sceneViewPortHorizon: ClosedRange<CGFloat> { (-self.frame.width/2)...(+self.frame.width/2) }
    var obstacleLivingRegion: ClosedRange<CGFloat> { self.sceneViewPortHorizon.extended(by: 100) }
    
    
    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        self.characterNode = self.createCharacterNode()
        self.addChild(self.characterNode)
        
        self.resetGame()
        
        connectToMIDIDevice()
        
        view.showsPhysics = true
        
        physicsWorld.contactDelegate = self
        
        self.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -self.frame.width/2, y: 0),
                                               to: CGPoint(x: +self.frame.width/2, y: 0))
    }
    
    
    func createObstacle() -> Obstacle {
    
        let obstacle = Obstacle(openingSize: .random(in: self.obstacleSizeRange),
                                openingPosition: .random(in: 25%...75%))
        
        return obstacle
    }
    
    
    func clearObstacleNodes() {
        
        self.removeChildren(in: self.obstacleNodesFromRightToLeft)
        self.obstacleNodesFromRightToLeft.removeAll()
    }
    
    
    func spawnNewObstacle(xPositionOfPreviousObstacle: CGFloat?) {
        
        let obstacleXPosition = xPositionOfPreviousObstacle == nil ? (self.sceneViewPortHorizon.upperBound + self.obstacleWidth) : (xPositionOfPreviousObstacle! + self.obstacleSpacing)
        
        let obstacle = self.createObstacle()
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
        node.physicsBody?.contactTestBitMask = mainContactTestBitMask
        
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
        
        if self.gameState == .ready {
            
            self.enableCharacterGravity(true)
            self.gameState = .started
            
        } else if self.gameState == .started {
            
            self.resetCharacterVelocity()
            self.applyCharacterImpulse(with: velocity)
        }
    }
    
    
    func resetGame() {
        
        self.clearObstacleNodes()
        
        self.resetCharacterPositionToDefaultPosition()
        self.resetCharacterVelocity()
        self.enableCharacterGravity(false)
        
        self.gameState = .ready
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
        
        if self.gameState == .gameover {
            
            self.resetGame()
            
        } else if self.gameState == .started {
            
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
        }
    }
    
    
    func createNode(for obstacle: Obstacle) -> SKNode {
        
        let relativeBottomHeight = obstacle.openingPosition.fraction - obstacle.openingSize.fraction/2.0
        let relativeTopHeight = (1 - obstacle.openingPosition.fraction) - obstacle.openingSize.fraction/2.0
        
        let absoluteBottomHeight = self.frame.height * CGFloat(relativeBottomHeight)
        let absoluteTopHeight = self.frame.height * CGFloat(relativeTopHeight)
        
        let bottomNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                           y: 0,
                                                           width: obstacleWidth,
                                                           height: absoluteBottomHeight))
        bottomNode.position = CGPoint(x: 0, y: 0)
        
        let topNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                        y: -absoluteTopHeight,
                                                        width: obstacleWidth,
                                                        height: absoluteTopHeight))
        topNode.position = CGPoint(x: 0, y: self.frame.height)
        
        let rootNode = SKNode()
        rootNode.addChild(bottomNode)
        rootNode.addChild(topNode)
        
        return rootNode
    }
    
    
    func createObstaclePartWithRect(_ rect: CGRect) -> SKNode {
        
        let path = CGPath(rect: rect, transform: nil)
        
        let node = SKShapeNode(path: path)
        
        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.midX, y: rect.midY))
        node.physicsBody!.isDynamic = false
        node.physicsBody!.contactTestBitMask = mainContactTestBitMask
        
        return node
    }
}

extension GameScene: SKPhysicsContactDelegate {
    
    
    func didBegin(_ contact: SKPhysicsContact) {
            
        self.gameState = .gameover
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
