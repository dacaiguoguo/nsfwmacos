//
//  ViewController.swift
//  nsfwmacos
//
//  Created by yanguo sun on 2024/4/22.
//

import Cocoa

struct NSFWCheckResult {
    let filename: String
    let confidence: Float
}

import Cocoa
import Vision

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    var nsfwLabel: NSTextField!
    var tableView: NSTableView!
    var results: [NSFWCheckResult] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNSFWLabel()
        setupTableView()
        loadAndCheckImages()
    }

    private func setupNSFWLabel() {
        nsfwLabel = NSTextField(labelWithString: "NSFW Detection Results")
        nsfwLabel.alignment = .center
        nsfwLabel.font = NSFont.systemFont(ofSize: 18)
        nsfwLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nsfwLabel)
        
        // Constraints for the label
        NSLayoutConstraint.activate([
            nsfwLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            nsfwLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupTableView() {
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "ResultColumn"))
        column.title = "NSFW Check Results"
        tableView.addTableColumn(column)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: nsfwLabel.bottomAnchor, constant: 20),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let nib = NSNib(nibNamed: NSNib.Name("CustomTableCellView"), bundle: nil)
        tableView.register(nib, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CustomCell"))

    }

    private func loadAndCheckImages() {
        let fileManager = FileManager.default
        let path = "/Users/yanguosun/Sites/localhost/aiheadshot-report/testaaqaa"
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            for item in items where item.hasSuffix("png") {
                let fullPath = "\(path)/\(item)"
                if let image = NSImage(contentsOfFile: fullPath) {
                    NSFWDetector.shared.check(image: image) { [weak self] result in
                        DispatchQueue.main.async {
                            switch result {
                            case .error(let error):
                                print("Detection failed for \(item): \(error.localizedDescription)")
                            case let .success(nsfwConfidence: confidence):
                                let result = NSFWCheckResult(filename: item, confidence: confidence)
                                print("result:\(item), confidence:\(confidence)")
                                self?.results.append(result)
                                self?.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to read contents of directory: \(error)")
        }
    }

    // MARK: - NSTableViewDataSource & NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        100
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = results[row]
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CustomCell"), owner: nil) as? CustomTableCellView else {
            return nil
        }
        let name = "\(result.filename)"
        cell.confidenceLabel.stringValue = "Confidence: \(result.confidence * 100.0)%"
        let path = "/Users/yanguosun/Sites/localhost/aiheadshot-report/testaaqaa"
        let imagepaht = "\(path)/\(name)";
        cell.imageV.image = NSImage(contentsOfFile:  imagepaht)
//        cell.progressBar.doubleValue = Double(result.confidence) * 100.0

        return cell
    }
}




import Foundation
import CoreML
import Vision
import AppKit // Import AppKit for NSImage

@available(macOS 10.14, *) // Make sure to specify the correct macOS version
public class NSFWDetector {
    
    public static let shared = NSFWDetector()
    
    private let model: VNCoreMLModel
    
    public required init() {
        guard let model = try? VNCoreMLModel(for: NSFW(configuration: MLModelConfiguration()).model) else {
            fatalError("NSFW should always be a valid model")
        }
        self.model = model
    }
    
    public enum DetectionResult {
        case error(Error)
        case success(nsfwConfidence: Float)
    }
    
    public func check(image: NSImage, completion: @escaping (_ result: DetectionResult) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.error(NSError(domain: "Could not convert NSImage to CGImage", code: 0, userInfo: nil)))
            return
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        self.check(requestHandler, completion: completion)
    }
    
    public func check(cvPixelbuffer: CVPixelBuffer, completion: @escaping (_ result: DetectionResult) -> Void) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: cvPixelbuffer, options: [:])
        self.check(requestHandler, completion: completion)
    }
}

@available(macOS 10.14, *)
private extension NSFWDetector {
    
    func check(_ requestHandler: VNImageRequestHandler?, completion: @escaping (_ result: DetectionResult) -> Void) {
        guard let requestHandler = requestHandler else {
            completion(.error(NSError(domain: "Request handler could not be initialized", code: 0, userInfo: nil)))
            return
        }
        
        let request = VNCoreMLRequest(model: self.model, completionHandler: { (request, error) in
            if let error = error {
                completion(.error(error))
                return
            }
            guard let observations = request.results as? [VNClassificationObservation],
                  let observation = observations.first(where: { $0.identifier == "NSFW" }) else {
                completion(.error(NSError(domain: "Detection failed: No NSFW Observation found", code: 0, userInfo: nil)))
                return
            }
            
            completion(.success(nsfwConfidence: observation.confidence))
        })
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(.error(error))
        }
    }
}

import Cocoa

class CustomTableCellView: NSTableCellView {
    @IBOutlet var confidenceLabel: NSTextField!

    @IBOutlet var imageV: NSImageView!
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
