
import SpriteKit
import MIKMIDI


struct Obstacle {
    
    let position: CGPoint
    let opening: CGFloat
    let id: UUID = UUID()
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let initialHorizontalImpulseMagnitude: CGFloat = 5 // Newton.seconds
    let obstacleWidth: CGFloat = 20
    let obstacleSpacing: CGFloat = 400
    let minObstacleSize: CGFloat = 40
    let maxObstacleSize: CGFloat = 200
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var defaultCamera: SKCameraNode!
    var characterNode: SKShapeNode!
    var obstacleNodesByObstacleId: [UUID: SKNode] = [:]
    
    var positionOfNextObstacle: CGFloat = 400
    var obstacles: [Obstacle] = []
    
    
    override func didMove(to view: SKView) {
        
        defaultCamera = SKCameraNode()
        self.addChild(defaultCamera)
        self.camera = defaultCamera
        
        self.isPaused = true
        
        initCharacter()
        connectToMIDIDevice()
    }
    
    func generateNewObstacle() -> Obstacle {
        
        let newObstacle = Obstacle(position: CGPoint(x: positionOfNextObstacle, y: CGFloat.random(in: -self.frame.height...self.frame.height)), opening: CGFloat(CGFloat.random(in: minObstacleSize...maxObstacleSize)))
        obstacles.insert(newObstacle, at: 0)
        positionOfNextObstacle += obstacleSpacing
        
        return newObstacle
    }
    
    
    override func didChangeSize(_ oldSize: CGSize) {
        
        redrawObstacles()
    }
    
    
    func redrawObstacles() {
        
        self.removeChildren(in: [SKNode](obstacleNodesByObstacleId.values))
        obstacleNodesByObstacleId.removeAll()
        
        ensureAllObstaclesHaveNodes()
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
        
        if self.isPaused {
            self.isPaused = false
            characterNode.physicsBody!.applyImpulse(CGVector(dx: initialHorizontalImpulseMagnitude, dy: 0))
            return
        }
        
        characterNode.physicsBody!.velocity = CGVector(dx: characterNode.physicsBody!.velocity.dx, dy: 0)
        characterNode.physicsBody!.applyImpulse(CGVector(dx: 0, dy: CGFloat(velocity) * inputSensibility))
    }
    
    
    override func didFinishUpdate() {
        
        defaultCamera.position = CGPoint(x: characterNode.position.x, y: 0)
        
        ensureAllObstaclesHaveNodes()
        while obstacles.isEmpty || obstacleNodesByObstacleId[obstacles.first!.id]!.isVisibleBy(defaultCamera) {
            let newObstacle = generateNewObstacle()
            createNode(for: newObstacle)
        }
    }
    
    
    func addObstacleNode(position: CGPoint, opening: CGFloat) -> SKNode {
        
        let rootNode = SKNode()
        
        let bottomNode = createPhysicsRectangleWithRect(CGRect(x: -obstacleWidth/2, y: -opening/2, width: obstacleWidth, height: -(self.frame.height/2 - opening/2 + position.y)))
        bottomNode.physicsBody!.isDynamic = false
        bottomNode.position = position
        rootNode.addChild(bottomNode)
        
        let topNode = createPhysicsRectangleWithRect(CGRect(x: -obstacleWidth/2, y: opening/2, width: obstacleWidth, height: self.frame.height/2 - opening/2 - position.y))
        topNode.physicsBody!.isDynamic = false
        topNode.position = position
        rootNode.addChild(topNode)
        
        self.addChild(rootNode)
        
        return rootNode
    }
    
    
    func createPhysicsRectangleWithRect(_ rect: CGRect) -> SKNode {
        
        let path = CGPath(rect: rect, transform: nil)
        let node = SKShapeNode(path: path)
//        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.width / 2.0, y: rect.height / 2.0))
        
        return node
    }
}


extension SKNode {
    
    
    func isVisibleBy(_ camera: SKCameraNode) -> Bool {
        
        return ([self]+self.children).contains(where: { camera.contains($0) })
    }
}
