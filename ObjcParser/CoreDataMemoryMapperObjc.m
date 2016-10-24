//
//  CoreDataMemoryMapperObjc.m
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import "CoreDataMemoryMapperObjc.h"
#import <CoreData/CoreData.h>

@interface CoreDataMemoryMapperObjc()

@property (nonatomic, strong) NSMutableDictionary *objectIdMap;

@end

@implementation CoreDataMemoryMapperObjc

- (instancetype)init:(NSManagedObjectContext*)context
{
    if ((self = [super init])) {
        self.context = context;
        self.objectIdMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (__kindof NSManagedObject*)object:(NSString*)objectType id:(NSNumber*)id uuid:(NSString*)uuid
{
    if (self.objectIdMap[objectType] == nil) {
        [self loadMemoryObjects:objectType];
    }

    NSMutableDictionary *mapping = [self.objectIdMap[objectType] mutableCopy];
    __kindof NSManagedObject* object = mapping[id];
    if (object) {
        return object;
    }

    object = [self createMemoryObject:objectType id:id uuid:uuid];
    mapping[id] = object;
    return object;
}

- (void)reset
{
    [self.objectIdMap removeAllObjects];
}

- (__kindof NSManagedObject*)createMemoryObject:(NSString*)objectType id:(NSNumber*)id uuid:(NSString*)uuid
{
    __kindof NSManagedObject* object =  [NSEntityDescription insertNewObjectForEntityForName:objectType inManagedObjectContext:self.context];
    [object setValue:id forKey:@"id"];
    [object setValue:uuid forKey:@"uuid"];
    return object;
}

- (void)loadMemoryObjects:(NSString*)objectType
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:objectType];
    [request setReturnsObjectsAsFaults:NO];
    [request setPredicate:[NSPredicate predicateWithFormat:@"id <> 0"]];
    
    NSArray *objects = [self.context executeFetchRequest:request error:nil];
    NSMutableDictionary *map = [[NSMutableDictionary alloc] init];
    for (NSManagedObject *object in objects) {
        map[[object valueForKey:@"id"]] = object;
    }
    self.objectIdMap[objectType] = map;
}

@end
