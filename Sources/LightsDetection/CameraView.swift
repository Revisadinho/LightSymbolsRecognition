//
//  File.swift
//  
//
//  Created by Jéssica Araujo on 28/11/21.
//

import AVFoundation
import UIKit
import Vision
import CoreML
import ImageIO

protocol CameraViewDelegate: AnyObject {
    func detectionSucceededWithSymbol(_ str: String)
    func detectionDidFail()
}

class CameraView: UIView {
    
    weak var delegate: CameraViewDelegate?
    
    var captureSession: AVCaptureSession?
    
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
    
    var detections:[VNRecognizedObjectObservation]? {
        didSet {
            guard let firstObservation = self.detections?.first else {return}
            self.updateDetections(with: firstObservation)
        }
    }
    
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
    
    lazy var overlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.alpha = 0.6
        return view
    }()
    
    lazy var cropReferenceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let shapeLayer = CAShapeLayer()
    
    override class var layerClass: AnyClass  {
        return AVCaptureVideoPreviewLayer.self
    }
    override var layer: AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }
    
    typealias VNConfidence = Float

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScanAndCropViews()
        initialSetup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CameraView {
    func startCaptureSession() {
        captureSession?.startRunning()
    }
    
    func stopCaptureSession() {
        captureSession?.stopRunning()
    }
    
    func cameraSessionDidFail() {
        delegate?.detectionDidFail()
        captureSession = nil
    }
    
    func showErrorLabel() {
        errorLabel.isHidden = false
    }
    
    func hideErrorLabel() {
        errorLabel.isHidden = true
    }
    
    func initialSetup() {
        clipsToBounds = true
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession?.addInput(input)
        
        let dataOutput = AVCaptureVideoDataOutput()
        
        if (captureSession?.canAddOutput(dataOutput) ?? false) {
            captureSession?.addOutput(dataOutput)
            dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        } else {
            cameraSessionDidFail()
            return
        }
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        setupErrorLabel()
        setupBackButton()
        self.layer.videoGravity = .resizeAspectFill
        self.layer.session = captureSession
        captureSession?.startRunning()
    }
}


extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
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
    
    private func updateDetections(with detection:VNRecognizedObjectObservation)  {
        DispatchQueue.main.async {
            guard let detectionIdentifier = detection.labels.first?.identifier else { return }
            guard let detectionConfidence = detection.labels.first?.confidence else { return }
            
            if (detectionConfidence > 0.97) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.delegate?.detectionSucceededWithSymbol(detectionIdentifier)
                    self.hideErrorLabel()
                }
            } else {
                self.showErrorLabel()
            }
        }
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to detect anything!")
                return
            }
            self.detections = results as? [VNRecognizedObjectObservation]
        }
    }
}


extension CameraView {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = overlayView.bounds
        shapeLayer.fillRule = .evenOdd
        
        let cropFrame = CGRect(x: bounds.midX-60, y: bounds.midY-60, width: cropReferenceView.bounds.width, height: cropReferenceView.bounds.height)
        
        let path = UIBezierPath(rect: overlayView.bounds)
        path.append(UIBezierPath(rect: cropFrame))
        shapeLayer.path = path.cgPath
        
        overlayView.layer.mask = shapeLayer
        createCorners()
    }
    
    
    private func createCorners() {
            //Calculate the length of corner to be shown
            let cornerLengthToShow = cropReferenceView.bounds.size.height * 0.16

            // Create Paths Using BeizerPath for all four corners
            let topLeftCorner = UIBezierPath()
            topLeftCorner.move(to: CGPoint(x: cropReferenceView.bounds.minX, y: cropReferenceView.bounds.minY + cornerLengthToShow))
            topLeftCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.minX, y: cropReferenceView.bounds.minY))
            topLeftCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.minX + cornerLengthToShow, y: cropReferenceView.bounds.minY))

            let topRightCorner = UIBezierPath()
            topRightCorner.move(to: CGPoint(x: cropReferenceView.bounds.maxX - cornerLengthToShow, y: cropReferenceView.bounds.minY))
            topRightCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.maxX, y: cropReferenceView.bounds.minY))
            topRightCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.maxX, y: cropReferenceView.bounds.minY + cornerLengthToShow))

            let bottomRightCorner = UIBezierPath()
            bottomRightCorner.move(to: CGPoint(x: cropReferenceView.bounds.maxX, y: cropReferenceView.bounds.maxY - cornerLengthToShow))
            bottomRightCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.maxX, y: cropReferenceView.bounds.maxY))
            bottomRightCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.maxX - cornerLengthToShow, y: cropReferenceView.bounds.maxY ))

            let bottomLeftCorner = UIBezierPath()
            bottomLeftCorner.move(to: CGPoint(x: cropReferenceView.bounds.minX, y: cropReferenceView.bounds.maxY - cornerLengthToShow))
            bottomLeftCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.minX, y: cropReferenceView.bounds.maxY))
            bottomLeftCorner.addLine(to: CGPoint(x: cropReferenceView.bounds.minX + cornerLengthToShow, y: cropReferenceView.bounds.maxY))

            let combinedPath = CGMutablePath()
            combinedPath.addPath(topLeftCorner.cgPath)
            combinedPath.addPath(topRightCorner.cgPath)
            combinedPath.addPath(bottomRightCorner.cgPath)
            combinedPath.addPath(bottomLeftCorner.cgPath)

            let shapeLayer = CAShapeLayer()
            shapeLayer.path = combinedPath
        shapeLayer.strokeColor = UIColor(red: 150/255, green: 121/255, blue: 247/255, alpha: 1).cgColor
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = 5
    
            cropReferenceView.layer.addSublayer(shapeLayer)
    }
}

extension CameraView {
    
    private func setupErrorLabel() {
        addSubview(errorLabel)
        bringSubviewToFront(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.heightAnchor.constraint(equalToConstant: 70),
            errorLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5)
        ])
    }
    
    private func setupBackButton() {
        addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.heightAnchor.constraint(equalToConstant: 35),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 25),
            backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
        ])
    }
    
    private func setupScanAndCropViews() {
        addSubview(overlayView)
        addSubview(cropReferenceView)
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            cropReferenceView.heightAnchor.constraint(equalToConstant: 120),
            cropReferenceView.widthAnchor.constraint(equalToConstant: 120),
            cropReferenceView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cropReferenceView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
