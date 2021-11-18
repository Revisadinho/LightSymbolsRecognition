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
    
    lazy var scanAreaView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()
    
    lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "Não foi possível identificar o símbolo"
        label.textColor = UIColor(red: 215/255, green: 219/255, blue: 249/255, alpha: 1)
        label.isHidden = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor(red: 41/255, green: 48/255, blue: 98/255, alpha: 1)
        label.lineBreakMode = .byWordWrapping
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        label.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        label.font = UIFont(name: "Quicksand-Bold", size: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.detections?.first == nil {
                self.errorLabel.isHidden = false
            }
        }
        session.startRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //rootLayer = view.layer
        setupCaptureSession()
        setupBackButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        if !errorLabel.isHidden {
            errorLabel.isHidden = true
        }
        session.stopRunning()
    }
    
    private func setupScanArea() {
        let overlay = createBlurViewOverlay(frame: view.frame)
        view.addSubview(overlay)
        
        view.addSubview(scanAreaView)
        scanAreaView.frame = CGRect(x: 0, y: 0, width: 286, height: 274)
        
        NSLayoutConstraint.activate([
            scanAreaView.heightAnchor.constraint(equalToConstant: 274),
            scanAreaView.widthAnchor.constraint(equalToConstant: 286),
            scanAreaView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 5),
            scanAreaView.topAnchor.constraint(equalTo: view.topAnchor, constant: 248)
        ])
        
        createCorners()
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
        previewLayer.frame = view.frame
        setupScanArea()
        setupConstraints()
        
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
            //self.teardownLayer()
            self.detections = results as? [VNRecognizedObjectObservation]
        }
    }
    
    private func updateDetections(with detection:VNRecognizedObjectObservation)  {
        DispatchQueue.main.async {
            guard let detectionIdentifier = detection.labels.first?.identifier else { return }
            guard let detectionConfidence = detection.labels.first?.confidence else { return }
            
            if (detectionConfidence > 0.97) {
                self.delegate?.getSymbolDetected(symbolName: detectionIdentifier)
                self.errorLabel.isHidden = true
            } else {
                self.errorLabel.isHidden = false
            }
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
    
    private func createBlurViewOverlay(frame: CGRect) -> UIView {
        let overlayView = UIView(frame: view.frame)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        let path = CGMutablePath()
        
        let width:CGFloat = 284
        let height:CGFloat = 270
        let scaledX = width * 0.48
        let scaledY = height * 0.73
        let pointX:CGFloat = view.bounds.midX - scaledX
        let pointY:CGFloat = view.bounds.midY - scaledY
        
        path.addRect(CGRect(x: pointX, y: pointY, width: width, height: height))
        path.addRect(CGRect(origin: .zero, size: overlayView.frame.size))
    
        
        let maskLayer = CAShapeLayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.path = path
        
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        
        return overlayView
    }
    
    private func createCorners() {
        let cornerLengthToShow = scanAreaView.bounds.size.height * 0.16

        let topLeftCorner = UIBezierPath()
        topLeftCorner.move(to: CGPoint(x: scanAreaView.bounds.minX, y: scanAreaView.bounds.minY + cornerLengthToShow))
        topLeftCorner.addLine(to: CGPoint(x: scanAreaView.bounds.minX, y: scanAreaView.bounds.minY))
        topLeftCorner.addLine(to: CGPoint(x: scanAreaView.bounds.minX + cornerLengthToShow, y:scanAreaView.bounds.minY))

        let topRightCorner = UIBezierPath()
        topRightCorner.move(to: CGPoint(x: scanAreaView.bounds.maxX - cornerLengthToShow, y:scanAreaView.bounds.minY))
        topRightCorner.addLine(to: CGPoint(x: scanAreaView.bounds.maxX, y:scanAreaView.bounds.minY))
        topRightCorner.addLine(to: CGPoint(x: scanAreaView.bounds.maxX, y: scanAreaView.bounds.minY + cornerLengthToShow))

        let bottomRightCorner = UIBezierPath()
        bottomRightCorner.move(to: CGPoint(x: scanAreaView.bounds.maxX, y: scanAreaView.bounds.maxY - cornerLengthToShow))
        bottomRightCorner.addLine(to: CGPoint(x: scanAreaView.bounds.maxX, y:scanAreaView.bounds.maxY))
        bottomRightCorner.addLine(to: CGPoint(x: scanAreaView.bounds.maxX - cornerLengthToShow, y: scanAreaView.bounds.maxY))

        let bottomLeftCorner = UIBezierPath()
        bottomLeftCorner.move(to: CGPoint(x: scanAreaView.bounds.minX, y: scanAreaView.bounds.maxY - cornerLengthToShow))
        bottomLeftCorner.addLine(to: CGPoint(x: scanAreaView.bounds.minX, y:scanAreaView.bounds.maxY))
        bottomLeftCorner.addLine(to: CGPoint(x: scanAreaView.bounds.minX + cornerLengthToShow, y:scanAreaView.bounds.maxY))

        let combinedPath = CGMutablePath()
        combinedPath.addPath(topLeftCorner.cgPath)
        combinedPath.addPath(topRightCorner.cgPath)
        combinedPath.addPath(bottomRightCorner.cgPath)
        combinedPath.addPath(bottomLeftCorner.cgPath)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = combinedPath
        shapeLayer.strokeColor = UIColor(red: 150/255, green: 121/255, blue: 247/255, alpha: 1).cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 12
            
        scanAreaView.layer.addSublayer(shapeLayer)
    }
    
    
    func teardownLayer() {
        previewLayer.sublayers?.removeSubrange(1...)
    }
    
    @objc
    public func dismissLigthsDetectionViewController() {
        self.dismiss(animated: true)
    }
    
    private func setupConstraints() {
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.heightAnchor.constraint(equalToConstant: 70),
            errorLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5)
        ])
    }
}
