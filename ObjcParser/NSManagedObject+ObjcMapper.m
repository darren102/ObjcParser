//
//  NSManagedObject+ObjcMapper.m
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import "NSManagedObject+ObjcMapper.h"
#import "CoreDataMemoryMapperObjc.h"

@implementation NSManagedObject (ObjcMapper)

# pragma mark - Public
/**
 Processes both attribute and relationships for the current managed object in the application

 @param values             string keyed NSDictionary holding the values to be set for the managed objects attributes and relationships
 @param parentRelationship relationship that originally brought the application to process this managed object
 @param processToMany      **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper             memory mapper to retrieve objects in memory as much as possible versus going to persistence
 */
- (void)processValues:(NSDictionary*)values parentRelationship:(NSRelationshipDescription*)parentRelationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper
{
    // Do not process if just a reference object
    if ([self isReferenceObject:values]) {
        return;
    }

    // Process the attributes of the entity first
    [self processPropertyValues:values];

    // Process the relationships of the entity
    [self processRelationshipValues:values parentRelationship:parentRelationship processToMany:processToMany mapper:mapper];

}

# pragma mark - Private

/**
 Determines whether the object is a reference object (id only) or a fully instantiated object

 @param values object data received from the server

 @return **YES** object is a reference object **NO** object is a fully instantiated object
 */
- (BOOL)isReferenceObject:(NSDictionary*)values
{
    if (values[@"referenceOnly"] && [values[@"referenceOnly"] boolValue]) {
        return YES;
    }
    return NO;
}

/**
 Resolve the property value key for the current property determining whether there is a valid value or not

 @note this method is used to check the external name associated with the property since some information from
       the server can be coming in as reserved fields in **iOS** such as **description** where we cannot overwrite
       these in our models hence this way the key name can be different than the name from the external data yet
       still the correct value can be resolved from the data by using this method
 
 @param key               original key inside the core data model
 @param entityDescription all relevant information about the current attribute property of the core data model
 @param attributeValues   list of key value pairs received from the external datasource

 @return key to process the values for or **nil** if the value should not be processed
 */
- (NSString*)resolvePropertyValueKey:(NSString*)key entityDescription:(NSAttributeDescription*)entityDescription attributeValues:(NSDictionary*)attributeValues
{
    NSString *propertyValueKey = entityDescription.userInfo[@"externalName"];
    if (!propertyValueKey) propertyValueKey = key;

    if (attributeValues[propertyValueKey] == nil) {
        return nil;
    }

    return propertyValueKey;
}

/**
 Determine whether the relationship should be ignored or whether it should be processed by the application

 @note the reason for this method is that in Core Data you always have to have an inverse relationship for the
       relationships you set up. Now sometimes that is done purely to satisfy Core Data and the endpoints the
       application is pulling data from do not return the data for the inverse. (Sometimes they do if there is
       a link back but this is to handle the time it does not have the return link). Since this **relationship**
       has been added to satisfy Core Data if we do not ignore it, the application will always reset the value to
       **nil** since no value comes from the endpoint hence it has to be treated that there is no longer a value in
       that **field** from the endpoint data hence the relationship should be reset to **nil** in the object

 @param relationship relationship to check if processing should be ignored on it or not

 @return **YES** relationship **SHOULD BE** processed by the application **NO** relationship **SHOULD NOT BE** processed by the application
 */
- (BOOL)shouldIgnoreRelationship:(NSPropertyDescription*)relationship
{
    return relationship.userInfo[@"processingIgnore"] != nil;
}


/**
 Will process the entities **attribute values only** trying to set the appropriate value
 for the entities attribute based on information provided in the String keyed Dictionary

 @note This method only deals with the attributes and will not try and do anything with the relationship
       properties. A seperate method will handle going through the relationships. This method bypasses
       setting the **IdField** of the attribute since this is already set and should not be overwritten

 @param attributeValues String keyed Dictionary holding the values to be set for the entities attributes and relationships
 */
- (void)processPropertyValues:(NSDictionary*)attributeValues
{
    [[[self entity] attributesByName] enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSAttributeDescription* entityDescription, BOOL *stop) {
        if (![key isEqualToString:@"id"]) {
            NSString *propertyKeyValue = [self resolvePropertyValueKey:key entityDescription:entityDescription attributeValues:attributeValues];
            if (propertyKeyValue) {
                id value = [self valueFromAttributeDescription:attributeValues[propertyKeyValue] entityDescription:entityDescription];
                [self setValue:value forKey:key];
            }
        }
    }];
}

/**
 Will process the entities **relationship values only** trying to set the appropriate values

 @note This method will check the **inverseRelationship** or the **parentRelationship** to determine
       whether it is the same as the relationship currently being processed. If it is this will skip
       that relationship since otherwise you will get into an endless loop

 @param values             String keyed Dictionary holding the values to be set for the entities attributes and relationships
 @param parentRelationship relationship that originally brought the user to process this entity
 @param processToMany      **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper             Object conforming to the protocol for CoreDataMemoryMapperObjc so retrieving objects can be done in memory as much as possible versus going to persistence everytime
 */
- (void)processRelationshipValues:(NSDictionary*)values parentRelationship:(NSRelationshipDescription*)parentRelationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper
{
    [[[self entity] relationshipsByName] enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSRelationshipDescription* relationship, BOOL *stop) {
        if (![self shouldIgnoreRelationship:relationship]) {
            if (!parentRelationship || parentRelationship.inverseRelationship || ![parentRelationship.inverseRelationship isEqual:relationship]) {
                if (![relationship isToMany]) {
                    if (values[key] == nil) {
                        [self setValue:nil forKey:key];
                    } else {
                        [self processToOneRelationship:key values:values[key] relationship:relationship processToMany:processToMany mapper:mapper];
                    }
                } else if (processToMany && values[key] != nil) {
                    [self processToManyRelationship:key valuesArray:values[key] relationship:relationship processToMany:processToMany mapper:mapper];
                }
            }
        }
    }];
}

/**
 Processing To-One relationships for the current nsmanagedobject

 @note There might be objects which do not have an id property. Those relations are marked and proccessed differently.

 @param key           maps this entity to the relationship entity
 @param values        **String** keyed **Dictionary** holding the values for the relationship entity
 @param relationship  description information on the **ToOne** relationship being processed
 @param processToMany **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper        object conforming to the protocol for **CoreDataMemoryMapperObjc** so retrieving objects can be done in memory as much as possible versus going to persistence everytime
 */
- (void)processToOneRelationship:(NSString*)key values:(NSDictionary*)values relationship:(NSRelationshipDescription*)relationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper
{
    NSNumber* idValue = (NSNumber*)values[@"id"];
    if (!idValue) {
        NSString *noId = relationship.userInfo[@"noId"];
        if (noId && [noId isEqualToString:@"true"]) {
            [self processToOneRelationshipNoId:key values:values relationship:relationship processToMany:processToMany mapper:mapper];
            return;
        }
        [self setValue:nil forKey:key];
        return;
    }
    
    __kindof NSManagedObject *object = [self persistenceObjectFor:idValue uuid:values[@"uuid"] relationship:relationship mapper:mapper];
    if (!object) {
        [self setValue:nil forKey:key];
        return;
    }

    [object processValues:values parentRelationship:relationship processToMany:processToMany mapper:mapper];
    [self setValue:object forKey:key];
}

/**
 Processing To-One relationships for the current entity if relationships do not have an id

 @note For relations to the objects which do not have an id we don't lookup by id.
       Instead we use either existing object or create a new one.

 @param key           maps this entity to the relationship entity
 @param values        **String** keyed **Dictionary** holding the values for the relationship entity
 @param relationship  description information on the **ToOne** relationship being processed
 @param processToMany **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper        object conforming to the protocol for **CoreDataMemoryMapperObjc** so retrieving objects can be done in memory as much as possible versus going to persistence everytime
 */
- (void)processToOneRelationshipNoId:(NSString*)key values:(NSDictionary*)values relationship:(NSRelationshipDescription*)relationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper
{
    __kindof NSManagedObject* object = [self valueForKey:key];
    if (!object) {
        object = [self persistenceObjectFor:nil uuid:nil relationship:relationship mapper:mapper];
        if (!object) {
            [self setValue:nil forKey:key];
            return;
        }
    }

    [object processValues:values parentRelationship:relationship processToMany:processToMany mapper:mapper];
    [self setValue:object forKey:key];
}

/**
 Processing To-Many relationships for the current entity

 @param key           maps the entity to the relationship entity
 @param valuesArray   the array of attributes to be processed for each relationship object
 @param relationship  description information on the **ToMany** relationship being processed
 @param processToMany **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper        object conforming to the protocol for **CoreDataMemoryMapperObjc** so retrieving objects can be done in memory as much as possible versus going to persistence everytime
 */
- (void)processToManyRelationship:(NSString*)key valuesArray:(NSArray*)valuesArray relationship:(NSRelationshipDescription*)relationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper
{
    NSMutableSet* objects = [self mutableSetValueForKey:key];
    [objects removeAllObjects];

    for (NSDictionary* values in valuesArray) {
        __kindof NSManagedObject* object = [self persistenceObjectFor:values[@"id"] uuid:values[@"uuid"] relationship:relationship mapper:mapper];
        if (object) {
            [object processValues:values parentRelationship:relationship processToMany:processToMany mapper:mapper];
            [objects addObject:object];
        }
    }
}

/**
 Tries to provide an entity from the persistence layer matching the unique identifier and the entity type
 information that is stored inside the **NSRelationshipDescription** that is provided

 @note When saying uniquely identified for the **value** parameter this means the combination of this **id** plus
       the type of entity stroed in the **relationship** description will be enough to pull the object from the
       persistence layer or have the correct object created in the persistence layer

 @param id           id provided by the server for the object **can be nil if a many to many relationship**
 @param uuid         unique uuid for the object if provided by the server or the applicatin
 @param relationship provides information on the relationship between the current entity and the other entities associated with it
 @param mapper       object conforming to the protocol for **CoreDataMemoryMapperObjc** so retrieving objects can be done in memory as much as possible versus going to persistence everytime

 @return NSManagedObject subclass if successful otherwise **nil** will be returned
 */
- (__kindof NSManagedObject*)persistenceObjectFor:(NSNumber*)id uuid:(NSString*)uuid relationship:(NSRelationshipDescription*)relationship mapper:(CoreDataMemoryMapperObjc*)mapper
{
    NSString *managedObjectClassName = [[relationship destinationEntity] managedObjectClassName];

    if (!id) {
        return [NSEntityDescription insertNewObjectForEntityForName:managedObjectClassName inManagedObjectContext:[mapper context]];
    }

    return [mapper object:managedObjectClassName id:id uuid:uuid];
}

/// Will make sure the value to be set in the **CoreData** attribute is of the correct type based on the attribute type
///
/// - note: This method uses the internal **NSAttributeType** information provided for the entity property via the
///         **entityDescription**
///
/// - parameter value: Raw value that was received from the caller (could be server or application generated data)
/// - parameter entityDescription: Description held inside **CoreData** regarding the property on the entity
///
/// - returns: Value transformed into the appropriate datatype or **nil** if an error occurs in the processing

/**
 Do any special processing depending on the type of attribute before returning the correct value

 @note This method uses the internal **NSAttributeType** information provided for the entity property via the **entityDescription**

 @param value             Raw value that was received from the caller (could be server or application generated data)
 @param entityDescription Description held inside **CoreData** regarding the property on the entity

 @return Value transformed into the appropriate datatype or **nil** if an error occurs in the processing
 */
- (id)valueFromAttributeDescription:(id)value entityDescription:(NSAttributeDescription*)entityDescription
{
    if ([entityDescription attributeType] == NSDateAttributeType) {
        return [self processDateAttribute:value];
    }
    return value;
}

/**
 Processes the value provided and returns an **NSDate** representation

 @note If a **nil** value is passed to this method nothing will occur and the method
       will exit immediately returning a **nil** value as the result

 @param value Object containing a representation of the date from the system

 @return Valid **NSDate** representation or **nil** the attribute could not be processed
 */
- (NSDate*)processDateAttribute:(id)value
{
    if (value == nil) return nil;

    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *numberValue = (NSNumber*)value;
        return [NSDate dateWithTimeIntervalSince1970:([numberValue doubleValue] / 1000)];
    }

    return nil;
}

@end
