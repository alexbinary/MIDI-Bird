
import SpriteKit
import MIKMIDI


struct Obstacle {
    
    let position: CGPoint
    let opening: CGFloat
    let id: UUID = UUID()
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let playerHorizontalSpeed: CGFloat = 200 // points per second
    let obstacleWidth: CGFloat = 20
    let obstacleSpacing: CGFloat = 400
    let minObstacleSize: CGFloat = 40
    let maxObstacleSize: CGFloat = 200
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var defaultCamera: SKCameraNode!
    var characterNode: SKShapeNode!
    var obstacleNodesByObstacleId: [UUID: SKNode] = [:]
    
    var gameStarted = false
    var obstacles: [Obstacle] = []
    
    
    override func didMove(to view: SKView) {
        
        defaultCamera = SKCameraNode()
        self.addChild(defaultCamera)
        self.camera = defaultCamera
        
        initCharacter()
        connectToMIDIDevice()
        
        view.showsPhysics = true
    }
    
    func generateNewObstacle() -> Obstacle {
        
        let newObstacle = Obstacle(position: CGPoint(x: defaultCamera.position.x + self.frame.width/2 + obstacleSpacing, y: CGFloat.random(in: -self.frame.height/4...self.frame.height/4)), opening: CGFloat(CGFloat.random(in: minObstacleSize...maxObstacleSize)))
        obstacles.insert(newObstacle, at: 0)
        
        return newObstacle
    }
    
    
    override func didChangeSize(_ oldSize: CGSize) {
        
        redrawObstacles()
        
        updateEdgeLoop()
    }
    
    
    func updateEdgeLoop() {
        
        if defaultCamera != nil {
            self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame.offsetBy(dx: -self.frame.width/2 + defaultCamera.position.x , dy: -self.frame.height/2))
        }
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
        characterNode.physicsBody?.isDynamic = false
        characterNode.run(SKAction.repeatForever(SKAction.moveBy(x: playerHorizontalSpeed, y: 0, duration: 1)))
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
        
        defaultCamera.position = CGPoint(x: characterNode.position.x, y: 0)
        updateEdgeLoop()
        
        if gameStarted {
            ensureAllObstaclesHaveNodes()
            while obstacles.isEmpty || obstacleNodesByObstacleId[obstacles.first!.id]!.isVisibleBy(defaultCamera) {
                let newObstacle = generateNewObstacle()
                createNode(for: newObstacle)
            }
        }
    }
    
    
    func addObstacleNode(position: CGPoint, opening: CGFloat) -> SKNode {
        
        let rootNode = SKNode()
        
        let height = self.frame.height/2 - opening/2 + position.y
        
        let bottomNode = createPhysicsRectangleWithRect(CGRect(x: -obstacleWidth/2, y: -opening/2 - height, width: obstacleWidth, height: self.frame.height/2 - opening/2 + position.y))
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
        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.midX, y: rect.midY))
        
        return node
    }
}


extension SKNode {
    
    
    func isVisibleBy(_ camera: SKCameraNode) -> Bool {
        
        return ([self]+self.children).contains(where: { camera.contains($0) })
    }
}
