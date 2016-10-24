//
//  Mapper.h
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CoreDataMemoryMapperObjc;

@interface Mapper : NSObject

- (instancetype)init:(NSManagedObjectContext*)context deleteNotProvided:(BOOL)deleteNotProvided mapper:(CoreDataMemoryMapperObjc*)mapper;

/**
 Processes an individual record that holds information about an object type in the system

 @param type       datatype of the object being processed
 @param objectType string version of the datatype for the object being processed
 @param records    array of string keyed dictionary holding the data for the object to be processed
 */
- (void)processRecords:(Class)type objectType:(NSString*)objectType records:(NSArray*)records;

/**
 Process the server data received verifying it exists and making sure it can be
 converted into the expected type before beginning to process each entity in turn

 @param type       datatype of the object being processed
 @param serverData Data received from the server for StaticData
 */
- (void)processData:(Class)type serverData:(id)serverData;

/**
 Helper method for the static data processing since the static data does not come as regular data out of the server but has its own special format

 @param type       datatype of the object being processed
 @param serverData static data for the type object received by the server
 */
- (void)processStaticData:(Class)type serverData:(NSArray*)serverData;

/**
 Reset the mapper implementing **CoreDataMemoryMapperObjc**
 */
- (void)resetMapper;

@end
