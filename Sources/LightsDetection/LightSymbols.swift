//
//  Model.swift
//  LightSymbolsRecognition
//  Created by Jéssica Araujo on 06/10/21.
//

import UIKit

public class LightSymbols {
    let cameraViewController = ViewController()
    var rootViewController: UIViewController?
    
    public init(controller: UIViewController) {
        self.rootViewController = controller
    }
    
    public func showViewController() {
        guard let currentViewController = self.rootViewController else {return}
        self.cameraViewController.delegate = currentViewController as? SymbolDetection
        self.rootViewController?.present(cameraViewController, animated: true, completion: nil)
    }
}

