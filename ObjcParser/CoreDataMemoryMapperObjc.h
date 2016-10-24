//
//  CoreDataMemoryMapperObjc.h
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreDataMemoryMapperObjc : NSObject

@property (nonatomic, strong) NSManagedObjectContext* context;

- (instancetype)init:(NSManagedObjectContext*)context;

- (__kindof NSManagedObject*)object:(NSString*)objectType id:(NSNumber*)id uuid:(NSString*)uuid;

- (void)reset;

@end
