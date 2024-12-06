//
//  ViewController.swift
//  SpyneAssignment
//
//  Created by Arav Khandelwal on 03/12/24.
//

import UIKit

class ImageCaptureVC: UIViewController {
    private lazy var captureManager: ImageCaptureManager = {
        return ImageCaptureManager(viewController: self)
    }()
    private let databaseManager = RealmDatabaseManager.shared
    private var images: [ImageModel] = []

    // UI Components
    private var previewView: UIView!
    private var collectionView: UICollectionView!
    private var captureButton: UIButton!
    private var uploadButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureManager()
        fetchImages()
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .white

           // Camera Preview
           previewView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height / 2))
           view.addSubview(previewView)

           // Capture Button
           captureButton = UIButton(type: .system)
           captureButton.setTitle("Capture", for: .normal)
           captureButton.backgroundColor = .systemBlue
           captureButton.tintColor = .white
           captureButton.layer.cornerRadius = 25
           captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
           captureButton.frame = CGRect(x: (view.frame.width - 100) / 2, y: previewView.frame.maxY + 10, width: 100, height: 50)
           view.addSubview(captureButton)

           // Upload Button
           uploadButton = UIButton(type: .system)
           uploadButton.setTitle("Upload", for: .normal)
           uploadButton.backgroundColor = .systemGreen
           uploadButton.tintColor = .white
           uploadButton.layer.cornerRadius = 25
           uploadButton.addTarget(self, action: #selector(startUploadingPendingImages), for: .touchUpInside)
           uploadButton.frame = CGRect(x: (view.frame.width - 100) / 2, y: captureButton.frame.maxY + 10, width: 100, height: 50)
           view.addSubview(uploadButton)

           // CollectionView for Images
           let layout = UICollectionViewFlowLayout()
           layout.itemSize = CGSize(width: (view.frame.width - 40) / 3, height: 180)
           layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

           collectionView = UICollectionView(frame: CGRect(x: 0, y: uploadButton.frame.maxY + 10, width: view.frame.width, height: view.frame.height - uploadButton.frame.maxY - 20), collectionViewLayout: layout)
           collectionView.delegate = self
           collectionView.dataSource = self
           collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
           collectionView.backgroundColor = .white
           view.addSubview(collectionView)
    }

    private func setupCaptureManager() {
        captureManager.setupCameraPreview(in: previewView)
        captureManager.onImageCaptured = { [weak self] image in
            self?.handleImageCaptured(image)
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUploadProgress(_:)), name: NSNotification.Name("UploadProgress"), object: nil)
    }

    // MARK: - Data Handling
    private func fetchImages() {
        images = databaseManager.fetchImages()
        images.forEach { image in
          if !FileManager.default.fileExists(atPath: image.imagePath) {
              // Update status in Realm if the file is missing
              databaseManager.updateUploadStatus(for: image.id, to: "File Missing")
          }
        }
        collectionView.reloadData()
    }

    private func handleImageCaptured(_ image: UIImage) {
        // Save image to file system and Realm
        let fileName = UUID().uuidString + ".jpg"
        let filePath = saveImageToDocumentsDirectory(image: image, withName: fileName)
        let captureDate = Date()
        databaseManager.saveImage(imagePath: filePath, imageName: fileName, captureDate: captureDate, uploadStatus: "Pending")
        fetchImages()
    }

    private func saveImageToDocumentsDirectory(image: UIImage, withName name: String) -> String {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = directory.appendingPathComponent(name)

        if let data = image.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: filePath)
                print("Image saved at path: \(filePath.path)")
            } catch {
                print("Error saving image: \(error.localizedDescription)")
            }
        }

        return filePath.path
    }

    // MARK: - Upload Progress Handling
    @objc private func handleUploadProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let id = userInfo["id"] as? String,
              let progress = userInfo["progress"] as? Float,
              let index = images.firstIndex(where: { $0.id == id }) else { return }

        let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ImageCell
        cell?.updateProgress(progress)
    }
    
    @objc private func startUploadingPendingImages() {
        let pendingImages = images.filter { $0.uploadStatus == "Pending" }
        images.forEach{ model in print(model.uploadStatus)}
        for image in pendingImages {
           UploadManager.shared.uploadImage(image: image)
        }
    }

    // MARK: - Actions
    @objc private func captureImage() {
        captureManager.captureImage()
    }

    @objc private func retryAllFailedUploads() {
        UploadManager.shared.retryFailedUploads()
    }
}

// MARK: - UICollectionViewDataSource
extension ImageCaptureVC: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as? ImageCell else {
            return UICollectionViewCell()
        }
        let image = images[indexPath.row]
        cell.configure(with: image) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.retryUpload(for: image)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ImageCaptureVC: UICollectionViewDelegate {}

// MARK: - Retry Handling
extension ImageCaptureVC {
    private func retryUpload(for image: ImageModel) {
        print("Retrying upload for image: \(image.imageName)")
        UploadManager.shared.uploadImage(image: image)
    }
}
