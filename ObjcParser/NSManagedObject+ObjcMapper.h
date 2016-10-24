//
//  NSManagedObject+ObjcMapper.h
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class CoreDataMemoryMapperObjc;

@interface NSManagedObject (ObjcMapper)

/**
 Processes both attribute and relationships for the current managed object in the application

 @param values             string keyed NSDictionary holding the values to be set for the managed objects attributes and relationships
 @param parentRelationship relationship that originally brought the application to process this managed object
 @param processToMany      **YES** will try and process **ToMany** relationships **NO** will not process **ToMany** relationships
 @param mapper             memory mapper to retrieve objects in memory as much as possible versus going to persistence
 */
- (void)processValues:(NSDictionary*)values parentRelationship:(NSRelationshipDescription*)parentRelationship processToMany:(BOOL)processToMany mapper:(CoreDataMemoryMapperObjc*)mapper;

@end
