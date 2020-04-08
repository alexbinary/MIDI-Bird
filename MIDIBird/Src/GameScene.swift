
import SpriteKit
import MIKMIDI
import Percent


struct Obstacle {
    
    let position: CGPoint
    let opening: CGFloat
    let id: UUID = UUID()
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let scrollingSpeed: CGFloat = 200 // points per second
    let obstacleWidth: CGFloat = 20
    let obstacleSpacing: CGFloat = 400
    
    let minObstacleSize = 10%
    let maxObstacleSize = 50%
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var characterNode: SKShapeNode!
    var obstacleNodesByObstacleId: [UUID: SKNode] = [:]
    
    var gameStarted = false
    var obstacles: [Obstacle] = []
    
    let mainContactTestBitMask: UInt32 = 1
    
    var shouldResetGameOnNextUpdate = false
    
    
    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        initCharacter()
        connectToMIDIDevice()
        
        view.showsPhysics = true
        
        physicsWorld.contactDelegate = self
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            
            if self.gameStarted {
                
                let newObstacle = self.generateNewObstacle()
                self.createNode(for: newObstacle)
            }
        }
    }
    
    func generateNewObstacle() -> Obstacle {
        
        let xPosition = self.frame.width/2 + obstacleSpacing
        
        let openingFraction = Double.random(in: minObstacleSize.fraction...maxObstacleSize.fraction)
        let positionFraction = Double.random(in: (-25%.fraction)...25%.fraction)
        
        let yPosition = self.frame.height * CGFloat(positionFraction)
        let openingSize = self.frame.height * CGFloat(openingFraction)
        
        let newObstacle = Obstacle(position: CGPoint(x: xPosition, y: yPosition), opening: openingSize)
        
        obstacles.insert(newObstacle, at: 0)
        
        return newObstacle
    }
    
    
    func updateEdgeLoop() {
        
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
    }
    
    
    func clearObstacles() {
        
        self.removeChildren(in: [SKNode](obstacleNodesByObstacleId.values))
        obstacleNodesByObstacleId.removeAll()
        
        obstacles.removeAll()
    }
    
    
    func ensureAllObstaclesHaveNodes() {
        
        obstacles.forEach { obstacle in
            if obstacleNodesByObstacleId[obstacle.id] == nil {
                createNode(for: obstacle)
            }
        }
    }
    
    
    func createNode(for obstacle: Obstacle) {
        obstacleNodesByObstacleId[obstacle.id] = addObstacleNode(position: obstacle.position, opening: obstacle.opening)
    }
    
    
    func initCharacter() {
        
        characterNode = SKShapeNode(circleOfRadius: 10)
        characterNode.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        characterNode.physicsBody?.isDynamic = false
        characterNode.physicsBody?.contactTestBitMask = mainContactTestBitMask
        characterNode.position = CGPoint(x: 0, y: self.frame.height/2)
        self.addChild(characterNode)
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
        
        if characterNode.physicsBody?.isDynamic == false {
            characterNode.physicsBody?.isDynamic = true
            gameStarted = true
            return
        }
        
        characterNode.physicsBody!.velocity = CGVector(dx: characterNode.physicsBody!.velocity.dx, dy: 0)
        characterNode.physicsBody!.applyImpulse(CGVector(dx: 0, dy: CGFloat(velocity) * inputSensibility))
    }
    
    
    override func didFinishUpdate() {
        
        if shouldResetGameOnNextUpdate {
            characterNode.position = CGPoint(x: 0, y: self.frame.height/2)
            characterNode.physicsBody?.velocity = CGVector(dx: characterNode.physicsBody!.velocity.dx, dy: 0)
            clearObstacles()
            characterNode.physicsBody?.isDynamic = false
            shouldResetGameOnNextUpdate = false
            gameStarted = false
        }
        
        updateEdgeLoop()
        
        if gameStarted {
            ensureAllObstaclesHaveNodes()
        }
    }
    
    
    func addObstacleNode(position: CGPoint, opening: CGFloat) -> SKNode {
        
        let rootNode = SKNode()
        
        let height = self.frame.height/2 - opening/2 + position.y
        
        let bottomNode = createPhysicsRectangleWithRect(CGRect(x: -obstacleWidth/2, y: -opening/2 - height, width: obstacleWidth, height: self.frame.height/2 - opening/2 + position.y))
        bottomNode.physicsBody!.isDynamic = false
        bottomNode.physicsBody?.contactTestBitMask = mainContactTestBitMask
        bottomNode.position = position
        rootNode.addChild(bottomNode)
        
        let topNode = createPhysicsRectangleWithRect(CGRect(x: -obstacleWidth/2, y: opening/2, width: obstacleWidth, height: self.frame.height/2 - opening/2 - position.y))
        topNode.physicsBody!.isDynamic = false
        topNode.physicsBody?.contactTestBitMask = mainContactTestBitMask
        topNode.position = position
        rootNode.addChild(topNode)
        
        self.addChild(rootNode)
        
        rootNode.position = CGPoint(x: rootNode.position.x, y: rootNode.position.y + self.frame.height/2)
        
        rootNode.run(SKAction.repeatForever(SKAction.moveBy(x: -scrollingSpeed, y: 0, duration: 1)))
        
        return rootNode
    }
    
    
    func createPhysicsRectangleWithRect(_ rect: CGRect) -> SKNode {
        
        let path = CGPath(rect: rect, transform: nil)
        let node = SKShapeNode(path: path)
        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.midX, y: rect.midY))
        
        return node
    }
}

extension GameScene: SKPhysicsContactDelegate {
    
    
    func didBegin(_ contact: SKPhysicsContact) {
            
        shouldResetGameOnNextUpdate = true
    }
}
