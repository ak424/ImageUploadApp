//
//  UploadManager.swift
//  SpyneAssignment
//
//  Created by Arav Khandelwal on 04/12/24.
//

import UIKit
import Foundation

class UploadManager: NSObject {
    static let shared = UploadManager()

    private var backgroundSession: URLSession!
    private let databaseManager = RealmDatabaseManager.shared

    override init() {
        super.init()

        // Configure background session
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.imageUploader")
        configuration.isDiscretionary = true
        configuration.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Upload a single image
    func uploadImage(image: ImageModel) {
        guard let fileURL = URL(string: "file://\(image.imagePath)") else {
            print("Invalid file path.")
            return
        }

        var request = URLRequest(url: URL(string: "https://www.clippr.ai/api/upload")!)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(image.imageName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)

        if let imageData = try? Data(contentsOf: fileURL) {
            body.append(imageData) // Append the actual image data
        }

        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Create an upload task with completion handler
        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                print("Upload failed for \(image.id): \(error.localizedDescription)")
                self.databaseManager.updateUploadStatus(for: image.id, to: "Failed")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("No response received for upload task.")
                self.databaseManager.updateUploadStatus(for: image.id, to: "Failed")
                return
            }

            if httpResponse.statusCode == 200 {
                print("Upload successful for \(image.id)")
                self.databaseManager.updateUploadStatus(for: image.id, to: "Completed")
            } else {
                print("Upload failed with status code: \(httpResponse.statusCode)")
                self.databaseManager.updateUploadStatus(for: image.id, to: "Failed")
            }
        }

        task.resume()

        // Update Realm status immediately to "Uploading"
        databaseManager.updateUploadStatus(for: image.id, to: "Uploading")
    }


    /// Retry uploading failed images
    func retryFailedUploads() {
        let failedImages = databaseManager.fetchImages().filter { $0.uploadStatus == "Failed" }
        for image in failedImages {
            uploadImage(image: image)
        }
    }
}

extension UploadManager: URLSessionDelegate, URLSessionTaskDelegate {
    // Handle upload completion
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let imageID = task.taskDescription else { return }

        if let error = error {
            print("Upload failed for \(imageID): \(error.localizedDescription)")
            databaseManager.updateUploadStatus(for: imageID, to: "Failed")
        } else {
            print("Upload successful for \(imageID)")
            databaseManager.updateUploadStatus(for: imageID, to: "Completed")
        }

        // Cleanup temporary file
        let tempFilePath = FileManager.default.temporaryDirectory.appendingPathComponent(imageID)
        try? FileManager.default.removeItem(at: tempFilePath)
    }

    // Track upload progress
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let imageID = task.taskDescription else { return }
        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        print("Upload progress for \(imageID): \(progress * 100)%")

        // Notify observers to update UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("UploadProgress"), object: nil, userInfo: ["id": imageID, "progress": progress])
        }
    }

    // Handle all background session events
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let completionHandler = appDelegate.backgroundSessionCompletionHandler else { return }
            completionHandler()
            appDelegate.backgroundSessionCompletionHandler = nil
        }
    }
}
