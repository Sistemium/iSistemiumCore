//
//  STMSettingControlsTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/10/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMSettingControlsTVC.h"
#import "STMSetting.h"

@interface STMSettingControlsTVC ()

@end

@implementation STMSettingControlsTVC

@synthesize resultsController = _resultsController;

- (NSFetchedResultsController *)resultsController {
    
    if (!_resultsController) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMSetting class])];
        
        NSSortDescriptor *groupSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"group" ascending:YES selector:@selector(caseInsensitiveCompare:)];
        NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];

        request.sortDescriptors = @[groupSortDescriptor, nameSortDescriptor];
        
        _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:self.document.managedObjectContext sectionNameKeyPath:@"group" cacheName:nil];
        _resultsController.delegate = self;
        
    }
    
    return _resultsController;

}



#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"settingCell" forIndexPath:indexPath];
    
    STMSetting *setting = [self.resultsController objectAtIndexPath:indexPath];
    
    cell.textLabel.text = setting.name;
    cell.detailTextLabel.text = setting.value;
    
    return cell;
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    NSError *error;
    
    if (![self.resultsController performFetch:&error]) {
        
        NSLog(@"performFetch error %@", error);
        
    } else {
        
//        for (STMSetting *setting in self.resultsController.fetchedObjects) {
//            NSLog(@"setting %@", setting);
//        }
        
    }

    [super customInit];

}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
//    [self customInit];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
