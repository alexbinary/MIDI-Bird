
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
        
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFit
        scene.customDelegate = self
        
        return scene
    }()
    
    
    lazy var deviceSelectionView: UIView = {
        
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        
        return tableView
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sceneView = SKView()
        self.view.addSubview(sceneView)
        
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        sceneView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        sceneView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        if let name = self.lastUsedMIDIDeviceDisplayName,
            let device = MIKMIDIDeviceManager.shared.availableDevices.first(where: { $0.displayName == name }) {
            
            self.setDevice(device)
        }
        
        sceneView.presentScene(self.gameScene)
    }
    
    
    func presentDeviceSelectionView() {
        
        self.view.addSubview(self.deviceSelectionView)
        
        self.deviceSelectionView.translatesAutoresizingMaskIntoConstraints = false
        self.deviceSelectionView.topAnchor.constraint(equalTo: self.view.readableContentGuide.topAnchor).isActive = true
        self.deviceSelectionView.bottomAnchor.constraint(equalTo: self.view.readableContentGuide.bottomAnchor).isActive = true
        self.deviceSelectionView.leftAnchor.constraint(equalTo: self.view.readableContentGuide.leftAnchor).isActive = true
        self.deviceSelectionView.rightAnchor.constraint(equalTo: self.view.readableContentGuide.rightAnchor).isActive = true
    }
    

    func dismissDeviceSelectionView() {
        
        self.deviceSelectionView.removeFromSuperview()
    }

    
    func setDevice(_ device: MIKMIDIDevice) {
        
        self.gameScene.MIDIDevice = device
        self.gameScene.didSetMIDIDevice()
        
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
        
        self.dismissDeviceSelectionView()
    }
}


extension ViewController: GameSceneDelegate {
    
    
    func didTriggerMIDIDeviceSelection() {
        
        self.presentDeviceSelectionView()
    }
    
    
    func showError(_ error: Error) {
        
        let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }
}
