//
//  Mapper.m
//  ObjcParser
//
//  Created by Darren Ferguson on 10/12/16.
//  Copyright © 2016 M.C. Dean, Inc. All rights reserved.
//

#import "Mapper.h"
#import "CoreDataMemoryMapperObjc.h"
#import "NSManagedObject+ObjcMapper.h"
#import <CoreData/CoreData.h>

@interface Mapper()

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, assign) BOOL deleteNotProvided;
@property (nonatomic, strong) CoreDataMemoryMapperObjc *mapper;

@end

@implementation Mapper

# pragma mark - Initializers

- (instancetype)init:(NSManagedObjectContext*)context deleteNotProvided:(BOOL)deleteNotProvided mapper:(CoreDataMemoryMapperObjc*)mapper
{
    if ((self = [super init])) {
        self.context = context;
        self.deleteNotProvided = deleteNotProvided;
        self.mapper = mapper;
    }
    return self;
}

# pragma mark - Public

/**
 Processes an individual record that holds information about an object type in the system

 @param type       datatype of the object being processed
 @param objectType string version of the datatype for the object being processed
 @param records    array of string keyed dictionary holding the data for the object to be processed
*/
- (void)processRecords:(Class)type objectType:(NSString*)objectType records:(NSArray*)records
{
    [self.context performBlockAndWait:^{
        [self process:type objectType:objectType data:records];
    }];
}

/**
 Process the server data received verifying it exists and making sure it can be
 converted into the expected type before beginning to process each entity in turn

 @param type       datatype of the object being processed
 @param serverData Data received from the server for StaticData
 */
- (void)processData:(Class)type serverData:(id)serverData
{
    if ([serverData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *data = (NSDictionary*)serverData;
        id entities = [data valueForKey:@"data"];
        if ([entities isKindOfClass:[NSArray class]]) {
            NSArray *objectData = (NSArray*)entities;
            [self.context performBlockAndWait:^{
                [self process:type objectType:NSStringFromClass(type) data:objectData];
            }];
        }
    }
}

/**
 Helper method for the static data processing since the static data does not come as regular data out of the server but has its own special format

 @param type       datatype of the object being processed
 @param serverData static data for the type object received by the server
 */
- (void)processStaticData:(Class)type serverData:(NSArray*)serverData
{
    [self.context performBlockAndWait:^{
        [self process:type objectType:NSStringFromClass(type) data:serverData];
    }];
}

/**
 Reset the mapper implementing **CoreDataMemoryMapper**
 */
- (void)resetMapper
{
    [self.mapper reset];
}

# pragma mark - Private

/**
 Process the returned JSON information from the server and add / update the entities into the persistence layer

 @param type       type of NSManagedObject being processed
 @param objectType string version of the datatype for the object being processed
 @param data       server response holding the relevant deviceData to be processed
 */
- (void)process:(Class)type objectType:(NSString*)objectType data:(NSArray*)data
{
    NSLog(@"Start processing %@ into persistence", objectType);

    NSMutableArray *ids = [[NSMutableArray alloc] init];
    for (NSDictionary *object in data) {
        if ([object valueForKey:@"disabled"]) {
            continue;
        }

        [ids addObject:[object valueForKey:@"id"]];
        __kindof NSManagedObject *managedObject = [self.mapper object:objectType id:[object valueForKey:@"id"] uuid:[object valueForKey:@"uuid"]];
        [managedObject processValues:object parentRelationship:nil processToMany:YES mapper:self.mapper];
    }

    NSLog(@"Finished adding to the persistence layer for object type: %@", objectType);

    if (!self.deleteNotProvided) {
        NSLog(@"Finished adding to the persistence layer for object type: %@. No deletion", objectType);
        return;
    }
}


@end
