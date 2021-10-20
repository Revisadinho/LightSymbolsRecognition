//
//  Model.swift
//  LightSymbolsRecognition
//
//  Created by Jéssica Araujo on 06/10/21.
//

import Foundation
import CoreML
import UIKit
import Vision
import ImageIO

public class LightSymbols {
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: LightsDetector_2().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    public init() {}
    
    private func processDetections(for request: VNRequest, error: Error?) {
        
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to detect anything.\n\(error!.localizedDescription)")
                return
            }
            
            //guard let firstObservation = results.first else {return}
            //print(firstObservation.confidence, firstObservation.uuid)
            
            let detections = results as! [VNRecognizedObjectObservation]
            self.drawDetectionsOnPreview(detections: detections)
        }
    }
    
    func drawDetectionsOnPreview(detections: [VNRecognizedObjectObservation]) {
            //guard let image = photoImageView.image else {
                //return
            //}
            
            //let imageSize = image.size
            //let scale: CGFloat = 0
            //UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

            //image.draw(at: CGPoint.zero)
            
        //guard let firstObservation = detections.first else {return}
        
        //guard let firstObservationIdentifier = firstObservation.labels.first?.identifier else {return}
        //guard let firstObservationConfidence = firstObservation.labels.first?.confidence else {return}
        
        //self.identifierLabel.text = "\(firstObservationIdentifier) confidence: \(firstObservationConfidence)"
            
            for detection in detections {
                
                print(detection.labels.map({"\($0.identifier) confidence: \($0.confidence)"}).joined(separator: "\n"))
                print("------------")
                
                //let boundingBox = detection.boundingBox
                //let rectangle = CGRect(x: boundingBox.minX*image.size.width, y: (1-boundingBox.minY-boundingBox.height)*image.size.height, width: boundingBox.width*image.size.width, height: boundingBox.height*image.size.height)
                //UIColor(red: 0, green: 1, blue: 0, alpha: 0.4).setFill()
                //UIRectFillUsingBlendMode(rectangle, CGBlendMode.normal)
            }
            
            //let newImage = UIGraphicsGetImageFromCurrentImageContext()
            //UIGraphicsEndImageContext()
            //photoImageView.image = newImage
        }
    
    private func updateDetections(for image: UIImage) {
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print("Failed to perform detection.\n\(error.localizedDescription)")
            }
        }
    }
}

