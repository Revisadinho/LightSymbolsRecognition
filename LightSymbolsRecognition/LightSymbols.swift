//
//  Model.swift
//  LightSymbolsRecognition
//  Created by Jéssica Araujo on 06/10/21.
//

import UIKit

public class LightSymbols {
    var rootViewController: UIViewController?
    
    public init(controller: UIViewController) {
        self.rootViewController = controller
    }
    
    public func showViewController() {
        self.rootViewController?.present(ViewController(), animated: true, completion: nil)
    }
}

