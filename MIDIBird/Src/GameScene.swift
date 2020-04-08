
import SpriteKit
import MIKMIDI
import Percent


struct Obstacle {
    
    let openingSize: Percent
    let openingPosition: Percent
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
    var obstacleNodes: [SKNode] = []
    
    var gameStarted = false
    
    let mainContactTestBitMask: UInt32 = 1
    
    var shouldResetGameOnNextUpdate = false
    
    
    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        initCharacter()
        connectToMIDIDevice()
        
        view.showsPhysics = true
        
        physicsWorld.contactDelegate = self
        
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            
            if self.gameStarted {
                
                self.spawnNewObstacle()
            }
        }
    }
    
    func createObstacle() -> Obstacle {
        
        let openingSizeFraction = Double.random(in: minObstacleSize.fraction...maxObstacleSize.fraction)
        let openingPositionFraction = Double.random(in: 25%.fraction...75%.fraction)
        
        let obstacle = Obstacle(openingSize: Percent(fraction: openingSizeFraction),
                                openingPosition: Percent(fraction: openingPositionFraction))
        
        return obstacle
    }
    
    
    func clearObstacleNodes() {
        
        self.removeChildren(in: obstacleNodes)
        obstacleNodes.removeAll()
    }
    
    
    func spawnNewObstacle() {
        
        let obstacleXPosition = self.frame.width/2 + obstacleSpacing
        
        let obstacle = self.createObstacle()
        let node = self.createNode(for: obstacle)
        
        node.position = CGPoint(x: obstacleXPosition, y: 0)
        node.run(SKAction.repeatForever(SKAction.moveBy(x: -scrollingSpeed, y: 0, duration: 1)))
        
        self.addChild(node)
        self.obstacleNodes.append(node)
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
            clearObstacleNodes()
            characterNode.physicsBody?.isDynamic = false
            shouldResetGameOnNextUpdate = false
            gameStarted = false
        }
    }
    
    
    func createNode(for obstacle: Obstacle) -> SKNode {
        
        let relativeBottomHeight = obstacle.openingPosition.fraction - obstacle.openingSize.fraction/2.0
        let relativeTopHeight = (1 - obstacle.openingPosition.fraction) - obstacle.openingSize.fraction/2.0
        
        let bottomNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                           y: 0,
                                                           width: obstacleWidth,
                                                           height: self.frame.height * CGFloat(relativeBottomHeight)))
        bottomNode.position = CGPoint(x: 0, y: 0)
        
        let topNode = createObstaclePartWithRect(CGRect(x: -obstacleWidth/2,
                                                        y: 0,
                                                        width: obstacleWidth,
                                                        height: -self.frame.height * CGFloat(relativeTopHeight)))
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
            
        shouldResetGameOnNextUpdate = true
    }
}
