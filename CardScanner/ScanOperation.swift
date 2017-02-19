//
//  ScanOperation.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/17.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreLocation
import Contacts
import CoreData

class ScanOperation: AsyncOperation {
    
    typealias ProcessEntity<T> = (Entity<T>, NSManagedObjectContext) throws -> Void
    
    private let identifier: String
    private let service: ScannerService
    private let coreData: CoreDataStack
    private let progress: ScannerService.ProgressHandler
    private let queue: DispatchQueue
    private let group: DispatchGroup
    
    private var state: ScannerService.State = .pending {
        didSet {
            self.progress(state)
        }
    }
    
    init(document identifier: String, service: ScannerService, coreData: CoreDataStack, progress: @escaping ScannerService.ProgressHandler) {
        self.identifier = identifier
        self.service = service
        self.coreData = coreData
        self.progress = progress
        self.queue = DispatchQueue(label: "ScannerServiceOperation")
        self.group = DispatchGroup()
    }
    
    override func cancel() {
        // FIXME: Cancel pending operations
        super.cancel()
    }
    
    override func execute(completion: @escaping () -> Void) {
        state = .active
        annotate()
        group.notify(queue: queue) { [coreData] in
            DispatchQueue.main.async {
                coreData.saveNow() {
                    self.state = .completed
                }
            }
        }
    }
    
    private func annotate() {
        group.enter()
        coreData.performBackgroundChanges() { [identifier, group] context in
            if let data = try context.documents(withIdentifier: identifier).first?.imageData {
                self.annotateImage(data as Data)
            }
            group.leave()
        }
    }
    
    private func annotateImage(_ image: Data) {
        group.enter()
        service.annotateImage(image: image) { response in
            if let response = response {
                self.handleImageAnnotationsResponse(response)
            }
            self.group.leave()
        }
    }
    
    private func handleImageAnnotationsResponse(_ response: ImageAnnotationResponse) {
        processAnnotations(response.faceAnnotations, process: imageAnnotationProcessor(.face))
        processAnnotations(response.logoAnnotations, process: imageAnnotationProcessor(.logo))
        processAnnotations(response.codeAnnotations, process: processCodeAnnotation)
        processTextAnnotations(response.textAnnotations)
    }
    
    private func processAnnotations(_ annotations: [Annotation], process: (Annotation) -> Void) {
        for annotation in annotations {
            process(annotation)
        }
    }
    
    private func imageAnnotationProcessor(_ type: ImageFragmentType) -> (Annotation) -> Void {
        return { annotation in
            // FIXME: Clip logo from source image according to bounding polygon. Import clipped image as image fragment.
        }
    }
    
    private func processCodeAnnotation(_ annotation: Annotation) {
        // FIXME: Import URLs, vCard and text from machine codes.
    }
    
    private func processTextAnnotations(_ annotations: [Annotation]) {
        guard let annotation = annotations.first else {
            return
        }
        let text = annotation.content
        group.enter()
        service.annotateText(text: text) { response in
            if let response = response {
                self.handleTextAnnotationsResponse(response)
            }
            self.group.leave()
        }
    }
    
    private func handleTextAnnotationsResponse(_ response: TextAnnotationResponse) {
        processEntities(response.personEntities, process: stringEntityProcessor(.person))
        processEntities(response.organizationEntities, process: stringEntityProcessor(.organization))
        processEntities(response.phoneEntities, process: stringEntityProcessor(.phoneNumber))
        processEntities(response.urlEntities, process: urlEntityProcessor(.url))
        processEntities(response.emailEntities, process: urlEntityProcessor(.email))
        processEntities(response.addressEntities, process: addressEntityProcessor())
    }
    
    // MARK: Generic entities
    
    private func stringEntityProcessor(_ type: TextFragmentType) -> ProcessEntity<String> {
        return { [identifier] entity, context in
            let fragment = TextFragment(
                type: type,
                value: entity.content,
                context: context
            )
            fragment.document = try context.documents(withIdentifier: identifier).first
        }
    }
    
    private func urlEntityProcessor(_ type: TextFragmentType) -> ProcessEntity<URL> {
        return { [identifier] entity, context in
            let fragment = TextFragment(
                type: type,
                value: entity.content.description,
                context: context
            )
            fragment.document = try context.documents(withIdentifier: identifier).first
        }
    }
    
    private func addressEntityProcessor() -> ProcessEntity<CLPlacemark> {
        return { [identifier] entity, context in
            let fragment = LocationFragment(
                placemark: entity.content,
                context: context
            )
            fragment.document = try context.documents(withIdentifier: identifier).first
        }
    }

    
    // MARK: Common
    
    private func processEntities<T>(_ entities: [Entity<T>], process: @escaping ProcessEntity<T>) {
        for entity in entities {
            group.enter()
            coreData.performBackgroundChanges() { [group] context in
                do {
                    try process(entity, context)
                    try context.save()
                }
                catch {
                    print("Cannot import entity \(error)")
                }
                group.leave()
            }
        }
    }
}