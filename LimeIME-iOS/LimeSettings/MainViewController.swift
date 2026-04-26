import UIKit
import SwiftUI

// Phase 4: Hosts the SwiftUI LimeSettingsView via UIHostingController.

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        embedSettings()
    }

    private func embedSettings() {
        let host = UIHostingController(rootView: LimeSettingsView())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
