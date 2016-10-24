//
//  ViewController.swift
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

import CoreDataStack
import UIKit

final class ViewController: UIViewController {

    var coreDataStack: CoreDataStack!

    let requestEntities = ["Organization",
                           "Contract",
                           "User",
                           "Symptom",
                           "AttributeGroup",
                           "Priority",
                           "DeviceState",
                           "DeviceStateMachine",
                           "DeviceType",
                           "DeviceAttribute",
                           "DeviceTypeAttribute",
                           "DeviceTypeAttributeStateBehavior",
                           "SRState",
                           "SRStateMachine",
                           "SRCategory",
                           "SRAttribute",
                           "SRCategoryAttribute",
                           "SRCategoryAttributeStateBehavior",
                           "WorkForm"]

    override func viewDidLoad() {
        super.viewDidLoad()

        DispatchQueue.main.async { [unowned self] in
            let data = self.readDataFile()
            self.processData(serverData: data)
        }
    }

    func readDataFile() -> Any {
        // Make sure we have the JMC configuration file and that the file has valid data inside it
        guard let jsonFile = Bundle.main.path(forResource: "data", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: jsonFile)) else {
                fatalError("Could not read the data file from disk")
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: [])
        } catch let error as NSError {
            fatalError("Data serialization error: \(error)")
        }
    }
    
    func processData(serverData: Any) {
        guard let data = serverData as? [String: Any],
            let entities = data["entities"] as? [String: Any] else {
                return
        }
        
        let context = coreDataStack.childContext
        let mapper = CoreDataMemoryMapperObjc(context)!
        let objectMapper = Mapper(context, deleteNotProvided: true, mapper: mapper)!

        for entity in requestEntities {
            guard let objects = entities[entity] as? [[String: Any]] else { continue }

            objectMapper.resetMapper()
            objectMapper.processStaticData(NSClassFromString(entity), serverData: objects)
        }
        coreDataStack.saveChildContext(context)
    }
}
