//
//  ViewController.swift
//  LightSymbolsRecognition
//
//  Created by Jéssica Araujo on 22/10/21.
//

import UIKit
import AVKit
import CoreML
import Vision
import ImageIO

public protocol LigthsDetectionDelegate {
    func sendLigthDetected(named: String)
}

class LigthsDetectionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let contentView = CameraView()
    var delegate: LigthsDetectionDelegate?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        contentView.startCaptureSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.contentView.detections?.first == nil {
                self.contentView.showErrorLabel()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view = contentView
        contentView.delegate = self
        setupBackButtonTarget()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        contentView.hideErrorLabel()
        contentView.stopCaptureSession()

    }
    
    private func setupBackButtonTarget() {
        contentView.backButton.addTarget(self, action: #selector(dismissLigthsDetectionViewController), for: .touchUpInside)
    }
        
    @objc
    public func dismissLigthsDetectionViewController() {
        self.dismiss(animated: true)
    }
}

extension LigthsDetectionViewController: CameraViewDelegate {
    func detectionSucceededWithSymbol(_ str: String) {
        delegate?.sendLigthDetected(named: str)
    }
    
    func detectionDidFail() {
        presentAlert(withTitle: "Error", message: "Detection Failed. Please try again.")
    }
    
    func setErrorLabelColorAndFont(backgroudColor:UIColor, font:UIFont, textColor:UIColor) {
        contentView.errorLabel.backgroundColor = backgroudColor
        contentView.errorLabel.textColor = textColor
        contentView.errorLabel.font = font
    }
    
    func changeBackButtonColor(color: UIColor) {
        contentView.backButton.tintColor = color
    }
}

extension LigthsDetectionViewController {
    func presentAlert(withTitle title: String, message : String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            print("You've pressed OK Button")
        }
        alertController.addAction(OKAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showToast(message : String, seconds: Double = 2.0) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.view.backgroundColor = UIColor.black
        alert.view.alpha = 0.6
        alert.view.layer.cornerRadius = 15
        
        self.present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            alert.dismiss(animated: true)
        }
    }
}
