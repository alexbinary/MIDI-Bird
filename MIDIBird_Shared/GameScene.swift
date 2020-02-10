
import SpriteKit
import MIKMIDI


struct Obstacle {
    
    let position: CGPoint
    let opening: CGFloat
}


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let initialHorizontalImpulseMagnitude: CGFloat = 5 // Newton.seconds
    let obstacleWidth: CGFloat = 20
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    var defaultCamera: SKCameraNode!
    var characterNode: SKShapeNode!
    var obstacleNodes: [SKNode] = []
    
    var obstacles: [Obstacle] = []
    
    
    override func didMove(to view: SKView) {
        
        defaultCamera = SKCameraNode()
        self.addChild(defaultCamera)
        self.camera = defaultCamera
        
        self.isPaused = true
        
        initCharacter()
        connectToMIDIDevice()
        
        obstacles = stride(from: 100, to: 1000, by: 100).map { x in
            Obstacle(position: CGPoint(x: x, y: Int.random(in: -Int(self.frame.height)...Int(self.frame.height))), opening: CGFloat(Int.random(in: 40...200)))
        }
        
        redrawObstacles()
    }
    
    
    override func didChangeSize(_ oldSize: CGSize) {
        
        print("didChangeSize")
        redrawObstacles()
    }
    
    
    func redrawObstacles() {
        
        self.removeChildren(in: obstacleNodes)
        obstacleNodes = obstacles.map { obstacle in
            addObstacleNode(position: obstacle.position, opening: obstacle.opening)
        }
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
        node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.width / 2.0, y: rect.height / 2.0))
        
        return node
    }
}
