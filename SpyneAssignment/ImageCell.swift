//
//  ImageCell.swift
//  SpyneAssignment
//
//  Created by Arav Khandelwal on 04/12/24.
//

import UIKit

class ImageCell: UICollectionViewCell {
    static let identifier = "ImageCell"

    private let imageView = UIImageView()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let retryButton = UIButton()

    private var retryAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup
    private func setupUI() {
        // ImageView
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        // ProgressBar
        progressBar.progress = 0
        progressBar.tintColor = .systemBlue
        contentView.addSubview(progressBar)

        // Status Label
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .black
        contentView.addSubview(statusLabel)

        // Retry Button
        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(.systemRed, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 12)
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        retryButton.isHidden = true
        contentView.addSubview(retryButton)

        // Layout
        imageView.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),

            progressBar.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 5),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),

            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 5),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            retryButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 5),
            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    // MARK: - Configuration
    func configure(with image: ImageModel, retryHandler: @escaping () -> Void) {
        imageView.image = UIImage(contentsOfFile: image.imagePath)
        statusLabel.text = image.uploadStatus
        retryButton.isHidden = image.uploadStatus != "Failed"
        retryAction = retryHandler
        if image.uploadStatus == "Uploading" {
            progressBar.isHidden = false
        } else {
            progressBar.isHidden = true
        }
    }

    func updateProgress(_ progress: Float) {
        progressBar.isHidden = false
        progressBar.progress = progress
    }

    @objc private func didTapRetry() {
        retryAction?()
    }
}

