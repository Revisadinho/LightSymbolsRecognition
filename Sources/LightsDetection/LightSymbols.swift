//
//  Model.swift
//  LightSymbolsRecognition
//  Created by Jéssica Araujo on 06/10/21.
//

import UIKit

public class LightSymbols {
    let lightsDetectionViewController = LigthsDetectionViewController()
    var rootViewController: UIViewController?
    
    public init(controller: UIViewController) {
        self.rootViewController = controller
    }
    
    public func showViewController() {
        guard let currentViewController = self.rootViewController else {return}
        lightsDetectionViewController.delegate = currentViewController as? LigthsDetectionDelegate
        lightsDetectionViewController.modalPresentationStyle = .overFullScreen
        self.rootViewController?.present(lightsDetectionViewController, animated: true, completion: nil)
    }
    
    public func setBackButtonColor(with color: UIColor) {
        lightsDetectionViewController.changeBackButtonColor(color: color)
    }
    
    public func setErrorLabel(backgroundColor: UIColor, font: UIFont, textColor: UIColor) {
        lightsDetectionViewController.setErrorLabelColorAndFont(backgroudColor: backgroundColor, font: font, textColor: textColor)
    }
    
    public func dismissViewController() {
        lightsDetectionViewController.dismiss(animated: true, completion: nil)
    }
}

