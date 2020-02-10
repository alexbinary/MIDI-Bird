
import SpriteKit
import MIKMIDI


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // Newton.seconds per input velocity unit
    let initialHorizontalImpulseMagnitude: CGFloat = 5 // Newton.seconds
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    
    var defaultCamera: SKCameraNode!
    var characterNode: SKShapeNode!
    

    override func didMove(to view: SKView) {
        
        defaultCamera = SKCameraNode()
        self.addChild(defaultCamera)
        self.camera = defaultCamera
        
        self.isPaused = true
        
        initCharacter()
        connectToMIDIDevice()
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
}
