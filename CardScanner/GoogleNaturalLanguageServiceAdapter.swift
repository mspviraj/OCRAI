//
//  GoogleNaturalLanguageServiceAdapter.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/18.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import GoogleNaturalLanguageAPI

struct GoogleNaturalLanguageServiceAdapter: TextAnnotationService {
    let service: GoogleNaturalLanguageAPI
    
    func annotate(request: TextAnnotationRequest, completion: @escaping TextAnnotationCompletion) {
        let text = request.text.lines.joined(separator: ", ")
        let serviceRequest = GoogleNaturalLanguageAPI.AnalyzeEntitiesRequest(
            encodingType: .utf8,
            document: GoogleNaturalLanguageAPI.Document(
                type: .plaintext,
                content: text
            ))
        service.analyzeEntities(request: serviceRequest) { (response, error) in
            let output = response?.textAnnotationResponse()
            completion(output, error)
        }
    }
}

extension GoogleNaturalLanguageAPI.AnalyzeEntitiesResponse {
    func textAnnotationResponse() -> TextAnnotationResponse {
        return TextAnnotationResponse(
            personEntities: textEntities(type: .person),
            organizationEntities: textEntities(type: .organization),
            addressEntities: [], // FIXME: Parse address to address components
            phoneEntities: [],
            urlEntities: [],
            emailEntities: []
        )
    }
    
    private func textEntities(type: GoogleNaturalLanguageAPI.EntityType) -> [Entity] {
        return self.entities.filter({ $0.type == type }).map {
            Entity(
                content: $0.name
            )
        }
    }
}
