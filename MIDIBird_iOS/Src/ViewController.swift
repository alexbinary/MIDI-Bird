
import UIKit
import SpriteKit


class ViewController: UIViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        
        (view as! SKView).presentScene(scene)
    }
}
