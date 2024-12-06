//
//  RealmDBManager.swift
//  SpyneAssignment
//
//  Created by Arav Khandelwal on 03/12/24.
//

import RealmSwift
import Foundation

class ImageModel: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var imagePath: String
    @Persisted var imageName: String
    @Persisted var captureDate: Date
    @Persisted var uploadStatus: String // "Pending", "Uploading", "Completed"
}

class RealmDatabaseManager {
    static let shared = RealmDatabaseManager()

    private init() {
        let realmConfig = Realm.Configuration(
            fileURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("default.realm"),
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 1 {
                    // Perform any necessary migrations
                }
            }
        )

        do {
            let realm = try Realm(configuration: realmConfig)
            Realm.Configuration.defaultConfiguration = realmConfig
            print("Realm is set up at: \(realm.configuration.fileURL?.path ?? "Unknown Path")")
        } catch {
            print("Error initializing Realm: \(error)")
        }
    }

    func saveImage(imagePath: String, imageName: String, captureDate: Date, uploadStatus: String) {
        DispatchQueue.main.async {
            let image = ImageModel()
            image.imagePath = imagePath
            image.imageName = imageName
            image.captureDate = captureDate
            image.uploadStatus = uploadStatus
            
            do {
                let realm = try Realm()
                try realm.write {
                    realm.add(image)
                }
            } catch {
                print("Error saving image to Realm: \(error.localizedDescription)")
            }
        }
    }

    func fetchImages() -> [ImageModel] {
 
            do {
                let realm = try Realm()
                let images = realm.objects(ImageModel.self)
                return Array(images)
            } catch {
                print("Error fetching images from Realm: \(error.localizedDescription)")
                return []
            }
        
    }

    func updateUploadStatus(for id: String, to status: String) {
        DispatchQueue.main.async {
              do {
                  let realm = try Realm()
                  if let image = realm.object(ofType: ImageModel.self, forPrimaryKey: id) {
                      try realm.write {
                          image.uploadStatus = status
                      }
                  }
              } catch {
                  print("Error accessing Realm: \(error.localizedDescription)")
              }
          }
    }
}
