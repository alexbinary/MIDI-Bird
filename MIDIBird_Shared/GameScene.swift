
import SpriteKit
import MIKMIDI


class GameScene: SKScene {
    

    override func didMove(to view: SKView) {
        
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        self.isPaused = true
        
        initCharacter()
    }
    
    
    func initCharacter() {
        
        let characterNode = SKShapeNode(circleOfRadius: 10)
        
        characterNode.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        
        self.addChild(characterNode)
    }
}
