
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
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        
        let headerView = UIView()
        headerView.backgroundColor = .white
        
        let label = UILabel()
        label.text = "Select a device"
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        
        headerView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: headerView.layoutMarginsGuide.topAnchor, constant: 36).isActive = true
        label.bottomAnchor.constraint(equalTo: headerView.layoutMarginsGuide.bottomAnchor, constant: -36).isActive = true
        label.leftAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: headerView.layoutMarginsGuide.rightAnchor).isActive = true
        
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        
        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(collectionView)
        
        return stackView
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


extension ViewController: UICollectionViewDataSource {
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.availableMIDIDevices.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let device = self.availableMIDIDevices[indexPath.row]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .white
        
        let label = UILabel()
        label.text = device.displayName
        label.sizeToFit()
        
        cell.contentView.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor).isActive = true
        label.leftAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor).isActive = true
        
        return cell
    }
}


extension ViewController: UICollectionViewDelegateFlowLayout {
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        return CGSize(width: 200, height: 200)
    }
}


extension ViewController: UICollectionViewDelegate {
    
    
    
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
