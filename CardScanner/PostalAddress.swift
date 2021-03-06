//
//  Location.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/03/28.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import Contacts

private let entityName = "PostalAddress"

extension PostalAddress: Actionable {
    
    var actionsTitle: String? {
        return "Postal Address"
    }
    
    var actionsDescription: String? {
        return String(describing: self)
    }
    
    var actions: [Action] {
        return [
            ShowAddressAction(address: self.address, coordinate: self.location),
            CopyTextAction(text: description),
            ShareAction(items: [description])
//            DeleteAction(object: self, context: self.managedObjectContext!)
        ]
    }
}

extension PostalAddress {
    public override var description: String {
        return CNPostalAddressFormatter.string(from: self.address, style: .mailingAddress)
    }
}

extension PostalAddress {
    
    var address: CNPostalAddress {
        get {
            let output = CNMutablePostalAddress()
            output.street = street ?? ""
            output.city = city ?? ""
            output.postalCode = postalCode ?? ""
            output.country = country ?? ""
            return output
        }
        set {
            street = newValue.street
            city = newValue.city
            postalCode = newValue.postalCode
            country = newValue.country
        }
    }
    
    var location: CLLocationCoordinate2D? {
        get {
            guard hasCoordinate else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            guard let value = newValue else {
                hasCoordinate = false
                return
            }
            hasCoordinate = true
            latitude = value.latitude
            longitude = value.longitude
        }
    }
    
    convenience init(address: CNPostalAddress? = nil, location: CLLocationCoordinate2D? = nil, context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            fatalError("Cannot initialize entity \(entityName)")
        }
        self.init(entity: entity, insertInto: context)
        if let address = address {
            self.address = address
        }
        self.location = location
    }
}
