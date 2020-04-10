
import UIKit
import SpriteKit
import MIKMIDI


class ViewController: UIViewController {

    
    var availableMIDIDevices: [MIKMIDIDevice] { MIKMIDIDeviceManager.shared.availableDevices }
    
    
    var lastUsedMIDIDeviceDisplayName: String? {
        
        get { UserDefaults.standard.value(forKey: self.lastUsedMIDIDeviceDisplayNamePersistanceKey) as? String }
        set { UserDefaults.standard.set(newValue, forKey: self.lastUsedMIDIDeviceDisplayNamePersistanceKey) }
    }
    
    let lastUsedMIDIDeviceDisplayNamePersistanceKey = "lastUsedMIDIDeviceDisplayName"
    
    
    lazy var gameScene: GameScene = {
        
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.customDelegate = self
        
        return scene
    }()
    
    
    lazy var deviceSelectionView: UIView = {
        
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.frame = self.view.bounds
        
        return tableView
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sceneView = SKView()
        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        
        if let name = self.lastUsedMIDIDeviceDisplayName,
            let device = MIKMIDIDeviceManager.shared.availableDevices.first(where: { $0.displayName == name }) {
            
            self.setDevice(device)
        }
        
        sceneView.presentScene(self.gameScene)
    }
    
    
    func presentDeviceSelectionView() {
        
        self.view.addSubview(self.deviceSelectionView)
    }
    

    func dismissDeviceSelectionView() {
        
        self.deviceSelectionView.removeFromSuperview()
    }

    
    func setDevice(_ device: MIKMIDIDevice) {
        
        self.gameScene.MIDIDevice = device
        
        self.lastUsedMIDIDeviceDisplayName = device.displayName
    }
}


extension ViewController: UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.availableMIDIDevices.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let device = self.availableMIDIDevices[indexPath.row]
        
        let cell = UITableViewCell()
        
        cell.textLabel?.text = device.displayName
        
        return cell
    }
}


extension ViewController: UITableViewDelegate {
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let device = self.availableMIDIDevices[indexPath.row]
        
        self.setDevice(device)
        
        self.gameScene.didSelectDevice()
        
        self.dismissDeviceSelectionView()
    }
}


extension ViewController: GameSceneDelegate {
    
    
    func didTriggerDeviceSelection() {
        
        self.presentDeviceSelectionView()
    }
}
