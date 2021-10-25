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

public protocol SymbolDetection {
    func getSymbolDetected(named: String)
}



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    typealias VNConfidence = Float
    
    var delegate: SymbolDetection?
    
    var detections:[VNRecognizedObjectObservation]? {
        didSet {
            guard let firstObservation = self.detections?.first else {return}
            self.updateDetections(with: firstObservation)
        }
    }

    let identifierLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: LightsDetector_v2().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupIdentifierConfidenceLabel()
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        session.addInput(input)
        session.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(dataOutput)
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to detect anything.\n\(error!.localizedDescription)")
                return
            }
            self.detections = results as? [VNRecognizedObjectObservation]
        }
    }
    
    private func updateDetections(with detection:VNRecognizedObjectObservation)  {
        guard let detectionIdentifier = detection.labels.first?.identifier else { return }
        guard let detectionConfidence = detection.labels.first?.confidence else { return }
        
        if (detectionConfidence > 0.90) {
            delegate?.getSymbolDetected(named: detectionIdentifier)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print("Failed to perform detection.\n\(error.localizedDescription)")
            }
        }
    }
    
    private func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        identifierLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
}
