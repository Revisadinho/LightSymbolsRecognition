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
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    
    var detections:[VNRecognizedObjectObservation]? {
        didSet {
            guard let firstObservation = self.detections?.first else {return}
            self.updateDetections(with: firstObservation)
        }
    }
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    private var detectionOverlay: CALayer! = nil
    
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
        rootLayer = view.layer
        setupCaptureSession()
        setupLayers()
        updateLayers()
        setupBackButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        session.stopRunning()
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
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = rootLayer.bounds
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(dataOutput)
        
        let captureConnection = dataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        do {
            try captureDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((captureDevice.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            captureDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
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
            self.drawDetectionResquestResults(detection)
            delegate?.getSymbolDetected(symbolName: detectionIdentifier)
        } else {
            delegate?.getSymbolDetected(symbolName: "Erro ao identificar o objeto")
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
    
    private func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        view.layer.addSublayer(detectionOverlay)
    }
    
    private func drawDetectionResquestResults(_ detection: VNRecognizedObjectObservation) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        
        let detectionBounds = VNImageRectForNormalizedRect(detection.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
    
        let layer = self.createRectLayer(bounds: detectionBounds)
        detectionOverlay.addSublayer(layer)

        self.updateLayers()
        CATransaction.commit()
    }
    
    private func updateLayers() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    func teardownLayer() {
        print("Removing sublayers")
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    private func createRectLayer(bounds: CGRect) -> CALayer {
        let layer = CALayer()
        layer.bounds.size.width = bounds.height
        layer.bounds.size.height = bounds.width
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.name = "Found Object"
        layer.borderWidth = 8
        layer.borderColor = UIColor.yellow.cgColor
        layer.cornerRadius = 2
        return layer
    }
    
    @objc
    public func dismissLigthsDetectionViewController() {
        teardownLayer()
        self.dismiss(animated: true)
    }
}
