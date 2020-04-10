
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let name = self.lastUsedMIDIDeviceDisplayName,
            let device = MIKMIDIDeviceManager.shared.availableDevices.first(where: { $0.displayName == name }) {
            
            self.presentGameView(with: device)
            
        } else {
            
            self.presentDeviceSelectionView()
        }
    }
    
    
    func presentDeviceSelectionView() {
        
        let deviceSelectionTableView = UITableView()
        deviceSelectionTableView.dataSource = self
        deviceSelectionTableView.delegate = self
        deviceSelectionTableView.frame = self.view.bounds
        self.view.addSubview(deviceSelectionTableView)
    }
    
    
    func presentGameView(with device: MIKMIDIDevice) {
        
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.MIDIDevice = device
        
        let sceneView = SKView()
        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        
        sceneView.presentScene(scene)
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
        
        self.presentGameView(with: device)
        
        self.lastUsedMIDIDeviceDisplayName = device.displayName
    }
}
