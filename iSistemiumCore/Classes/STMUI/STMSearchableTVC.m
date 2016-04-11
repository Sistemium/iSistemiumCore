//
//  STMSearchableTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/06/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMSearchableTVC.h"

@interface STMSearchableTVC () <UISearchBarDelegate>

@end


@implementation STMSearchableTVC

- (NSPredicate *)textSearchPredicate {
    return [self textSearchPredicateForField:@"name"];
}

- (NSPredicate *)textSearchPredicateForField:(NSString *)field {
    
    if (!field) {
        return nil;
    }
    
    if (self.searchBar.text && ![self.searchBar.text isEqualToString:@""]) {
        
        NSString *trimmedSearchString = [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSArray *searchStringComponents = [trimmedSearchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        NSMutableArray *subpredicates = @[].mutableCopy;
        
        for (NSString *searchString in searchStringComponents) {
            
            NSString *predicateString = [field stringByAppendingString:@" CONTAINS[cd] %@"];
            
            [subpredicates addObject:[NSPredicate predicateWithFormat:predicateString, searchString]];
            
        }
        
        return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
        
    } else {
        
        return nil;
        
    }
    
}


#pragma mark - search & UISearchBarDelegate

- (void)searchButtonPressed {
    
    [self.searchBar becomeFirstResponder];
    
//    [self.tableView setContentOffset:CGPointZero animated:YES];
    
    [self.tableView scrollRectToVisible:self.tableView.tableHeaderView.frame animated:NO];
    
    [self hideSearchButton];
    
}

- (void)showSearchButton {
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch
                                                                                           target:self
                                                                                           action:@selector(searchButtonPressed)];
}

- (void)hideSearchButton {
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)setSearchFieldIsScrolledAway:(BOOL)searchFieldIsScrolledAway {
    
    if (_searchFieldIsScrolledAway != searchFieldIsScrolledAway) {
        
        _searchFieldIsScrolledAway = searchFieldIsScrolledAway;
        
        if (_searchFieldIsScrolledAway) {
            [self showSearchButton];
        } else {
            [self hideSearchButton];
        }
        
    }
    
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self performFetch];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    
    searchBar.showsCancelButton = YES;
    
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    
    searchBar.showsCancelButton = NO;
    searchBar.text = nil;
    
    [self hideKeyboard];
    [self performFetch];
    
    if (self.searchFieldIsScrolledAway) {
        [self showSearchButton];
    }
    
}


- (void)hideKeyboard {
    
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.searchFieldIsScrolledAway = (scrollView.contentOffset.y > self.searchBar.frame.size.height);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self hideKeyboard];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self hideKeyboard];
}


#pragma mark - table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self hideKeyboard];
}


#pragma mark - view lifecycle

- (void)customInit {
    
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 44)];
    self.tableView.tableHeaderView = self.searchBar;
    self.searchBar.delegate = self;

    [super customInit];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
