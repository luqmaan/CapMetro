//
//  NearbyViewController.m
//  CapMetro
//
//  Created by Luq on 2/10/14.
//  Copyright (c) 2014 Luq. All rights reserved.
//

#import "NearbyViewController.h"
#import "GTFSDB.h"
#import "StopAnnotation.h"
#import "CAPNextBus.h"

@interface NearbyViewController ()

@property GTFSDB* gtfs;
@property CLLocationManager *locationManager;
@property NSMutableArray *locations;

@end

@implementation NearbyViewController

- (void)baseInit {
    NSLog(@"table view did load");
    self.gtfs = [[GTFSDB alloc] init];
    self.locations = [[NSMutableArray alloc] init];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self baseInit];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self baseInit];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)loadArrivalsBtnPress:(id)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    if (indexPath)
    {
        CAPNextBus *nb = self.locations[indexPath.row];
        CAPStop *activeStop = nb.location.stops[nb.activeStopIndex];
        NSLog(@"Loading arrivals for %@", activeStop.name);
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        UIProgressView *progressView = (UIProgressView *)[cell viewWithTag:12];
        progressView.progress = 0.0f;
        progressView.hidden = NO;
        nb.progressCallback = ^void(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead)
        {
            progressView.progress = totalBytesExpectedToRead / totalBytesExpectedToRead;
        };
        
        nb.completedCallback = ^void(){
            NSLog(@"nextBus callback called");
            progressView.hidden = YES;
            [self.tableView reloadData];
        };
        [nb startUpdates];
    }
}

- (IBAction)nextStopPress:(id)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    if (indexPath)
    {
        NSLog(@"Next stop button pressed %@", indexPath);
        CAPNextBus *nb = self.locations[indexPath.row];
        [nb activateNextStop];
        [self.tableView reloadData];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (nil == self.locationManager)
        self.locationManager = [[CLLocationManager alloc] init];

    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    self.locationManager.distanceFilter = 500; // meters

    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *userLocation = [locations lastObject];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        NSMutableArray *data = [self.gtfs locationsForRoutes:@[@801] nearLocation:userLocation withinRadius:200.0f];
        [self.locations removeAllObjects];

        for (CAPLocation *location in data) {
            CAPNextBus *nb = [[CAPNextBus alloc] initWithLocation:location];
            [self.locations addObject:nb];
        }
        NSLog(@"Got %lu locations", (unsigned long)self.locations.count);

        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.tableView reloadData];
            
            // Scroll to the nearest stop
            NSIndexPath *nearestStopIndexPath;
            int i = 0;
            while (i < self.locations.count) {
                CAPNextBus *nb = self.locations[i];
                if (nb.location.distanceIndex == 0) {
                    nearestStopIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
                    break;
                }
                i++;
            }
            [self.tableView scrollToRowAtIndexPath:nearestStopIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        });
    });

    [self.locationManager stopUpdatingLocation];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.locations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier;

    CAPNextBus *nextBus = [self.locations objectAtIndex:indexPath.row];
    CAPLocation *location = nextBus.location;
    CAPStop *activeStop = location.stops[nextBus.activeStopIndex];
    
    if (activeStop.lastUpdated) {
        CellIdentifier = @"TripsCell";
    }
    else {
        CellIdentifier = @"Cell";
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    UILabel *routeNumber = (UILabel *)[cell viewWithTag:1];
    UILabel *stopName = (UILabel *)[cell viewWithTag:2];
    UILabel *loadError = (UILabel *)[cell viewWithTag:11];
    UIView *routeIndicator = (UIView *)[cell viewWithTag:21];
    UIView *proximityIndicator = (UIView *)[cell viewWithTag:22];
    
    routeNumber.text = location.name;
    stopName.text = activeStop.headsign;
    
    proximityIndicator.layer.cornerRadius = 6.0f;
    proximityIndicator.layer.backgroundColor = [[UIColor whiteColor] CGColor];
    proximityIndicator.layer.borderColor = [[UIColor grayColor] CGColor];
    proximityIndicator.layer.borderWidth = 3.0f;
    
    if ([CellIdentifier isEqualToString:@"TripsCell"]) {
        if (activeStop.trips.count == 0) {
            NSLog(@"No trips for %@", activeStop.trips);
            loadError.text = @"No upcoming arrivals";
            loadError.hidden = NO;
            return cell;
        }
        
        for (int i = 0; i < 5; i++) {
            if (i >= activeStop.trips.count) break;
            
            CAPTrip *trip = activeStop.trips[i];
            UILabel *mainTime, *oldTime;
            mainTime = (UILabel *)[cell viewWithTag:100 + i];
            oldTime = (UILabel *)[cell viewWithTag:101 + i];
            
            if (trip.realtime.valid) {
                oldTime.hidden = NO;
                oldTime.text = trip.tripTime;
            }
            mainTime.text = trip.estimatedTime;
            mainTime.hidden = NO;
        }

    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{

    CAPNextBus *nextBus = self.locations[indexPath.row];
    CAPLocation *location = nextBus.location;
    CAPStop *stop = location.stops[nextBus.activeStopIndex];
    
    NSLog(@"calculating height %@", stop.lastUpdated);
    if (stop.lastUpdated) {
        return 190.0f;
    }
    else return 120.0f;
}

@end
