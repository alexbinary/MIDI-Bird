
import SpriteKit
import MIKMIDI


class GameScene: SKScene {
    
    
    let inputSensibility: CGFloat = 0.2 // point per velocity unit
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    
    
    var characterNode: SKShapeNode!
    

    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
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
            commands.compactMap { $0 as? MIKMIDINoteOnCommand } .forEach { command in
                self.onMIDIInput(command.velocity)
            }
        }
    }
    
    
    func onMIDIInput(_ velocity: UInt) {
        
        if self.isPaused {
            self.isPaused = false
            return
        }
        
        characterNode.physicsBody!.applyImpulse(CGVector(dx: 0, dy: CGFloat(velocity) * inputSensibility))
    }
}
