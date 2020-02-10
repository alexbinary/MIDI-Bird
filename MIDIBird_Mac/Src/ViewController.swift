
import Cocoa
import SpriteKit


class ViewController: NSViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        
        (view as! SKView).presentScene(scene)
    }
}
