
import SpriteKit
import MIKMIDI


class GameScene: SKScene {
    
    
    let MIDIDeviceName = "Alesis Recital Pro "  // trailing space intentional
    

    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        self.isPaused = true
        
        initCharacter()
        
        connectToMIDIDevice()
    }
    
    
    func initCharacter() {
        
        let characterNode = SKShapeNode(circleOfRadius: 10)
        
        characterNode.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        
        self.addChild(characterNode)
    }
    
    
    func connectToMIDIDevice() {
        
        let device = MIKMIDIDeviceManager.shared.availableDevices.first(where: { $0.displayName == MIDIDeviceName })!
        
        try! MIKMIDIDeviceManager.shared.connect(device) { (_, commands) in
            commands.compactMap { $0 as? MIKMIDINoteOnCommand } .forEach { command in
                self.processInput(command.velocity)
            }
        }
    }
    
    
    func processInput(_ value: UInt) {
        
    }
}
