//
//  CAPTripRealtime.m
//  CapMetro
//
//  Created by Luq on 2/13/14.
//  Copyright (c) 2014 Luq. All rights reserved.
//

#import "CAPTripRealtime.h"

@implementation CAPTripRealtime

@synthesize coordinate;  // Why this is needed, I don't know :(

- (void)updateWithNextBusAPI:(NSDictionary *)data
{
    self.valid = [data[@"Valid"] boolValue];
    self.adherence = data[@"Adherence"];
    self.estimatedTime = data[@"Estimatedtime"];
    self.estimatedMinutes = data[@"Estimatedminutes"];
    self.polltime = data[@"Polltime"];
    self.trend = data[@"Trend"];
    self.speed = data[@"Speed"];
    self.reliable = data[@"Reliable"];
    self.stopped = data[@"Stopped"];
    self.vehicleId = data[@"Vehicleid"];
    if (data[@"Lat"]) self.lat = [data[@"Lat"] floatValue];
    if (data[@"Long"]) self.lon = [data[@"Long"] floatValue];
    if (self.lat && self.lon) {
        coordinate = CLLocationCoordinate2DMake(self.lat, self.lon);
    }
    self.title = [NSString stringWithFormat:@"%@ Minutes Away - Vehicle %@", self.estimatedMinutes, self.vehicleId];
    self.subtitle = [NSString stringWithFormat:@"Location Updated %@", self.polltime];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CAPTripRealtime: coordinate = %f %f; >", (float)coordinate.latitude, (float)coordinate.longitude];
}

@end