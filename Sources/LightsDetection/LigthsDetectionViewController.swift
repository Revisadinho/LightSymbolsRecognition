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
    func getSymbolDetected(symbolName: String)
}

class LigthsDetectionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    typealias VNConfidence = Float
    
    var delegate: SymbolDetection?
    let session = AVCaptureSession()
    
    var detections:[VNRecognizedObjectObservation]? {
        didSet {
            guard let firstObservation = self.detections?.first else {return}
            self.updateDetections(with: firstObservation)
        }
    }
    
    let backButton: UIButton = {
        let button = UIButton()
        let largeConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .bold, scale: .medium)
        let chevronSFSymbol = UIImage(systemName: "chevron.backward", withConfiguration: largeConfiguration)
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        button.setImage(chevronSFSymbol, for: .normal)
        return button
    }()
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            
            let modelURL = Bundle.module.url(forResource: "LightsDetector_v2",withExtension: "mlmodelc")!
            //let compileModel = try MLModel.compileModel(at: modelURL)
            //saveCompiledModelURL(compileModel)
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            
            let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        session.startRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupBackButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        session.stopRunning()
    }
    
    private func saveCompiledModelURL(_ compiledModelURL: URL) {
        do {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
            let compileModelName = compiledModelURL.lastPathComponent
            let permanentURL = appSupportURL.appendingPathComponent(compileModelName)
            _ = try fileManager.replaceItemAt(permanentURL, withItemAt: compiledModelURL)
        
        } catch {}
    }
    
    private func setupBackButton() {
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(dismissLigthsDetectionViewController), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            backButton.heightAnchor.constraint(equalToConstant: 35),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
        ])
    }
    
    
    private func setupCaptureSession() {
        session.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        session.addInput(input)
        session.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(dataOutput)
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                //print("Unable to detect anything.\n\(error!.localizedDescription)")
                print("Unable to detect anything")
                
                return
            }
            self.detections = results as? [VNRecognizedObjectObservation]
        }
    }
    
    private func updateDetections(with detection:VNRecognizedObjectObservation)  {
        guard let detectionIdentifier = detection.labels.first?.identifier else { return }
        guard let detectionConfidence = detection.labels.first?.confidence else { return }
        
        if (detectionConfidence > 0.90) {
            delegate?.getSymbolDetected(symbolName: detectionIdentifier)
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
    
    @objc
    public func dismissLigthsDetectionViewController() {
        self.dismiss(animated: true)
    }
}
