//
//  SPTableViewController.m
//  StackOverflowClient
//
//  Created by Rex St. John on 11/15/13.
//  Copyright (c) 2013 Rex St. John. All rights reserved.
//

#import "SPQuestionTableViewController.h"
#import "SPStackOverflowNetworkingEngine.h"
#import "SPStackOverflowQuestion.h"
#import "SPAnswerTableViewController.h"
#import <CoreText/CoreText.h>
#import "UITableViewCell+StackOverflowQuestionBinding.h"

@interface SPQuestionTableViewController ()
@property(nonatomic,strong) SPStackOverflowNetworkingEngine *networkingEngine;
@property(nonatomic,strong) NSMutableArray *questions;
@property(nonatomic,assign) NSUInteger currentPageIndex;
@property(nonatomic,assign) NSUInteger rowCount;
@property(nonatomic,strong) UIActivityIndicatorView *indicatorView;
@property(nonatomic,strong) UIView *activityView;
@end

@implementation SPQuestionTableViewController

NSInteger const kPageSize = 3;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Networking.
    self.networkingEngine = [[SPStackOverflowNetworkingEngine alloc] initWithHostName:@"api.stackexchange.com"];
    [self.networkingEngine useCache];
    self.currentPageIndex = 1;
    [self getQuestionsByPageIndex:self.currentPageIndex];
    
    // Loading view.
    self.activityView = [[UIView alloc]initWithFrame:CGRectMake(0,0,200,200)];
    [self.activityView setBackgroundColor:[UIColor lightGrayColor]];
    self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorView setHidesWhenStopped:NO];
    [self.activityView addSubview:self.indicatorView];
    self.indicatorView.center = self.activityView.center;
    self.activityView.center=self.view.center;
    [self.view addSubview:self.activityView];
    [self.activityView setHidden:YES];
    
    // Get more footer button.
    UIView *aView = [[UIView alloc]initWithFrame:CGRectMake(0,0,self.tableView.frame.size.width,44.0f)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setTitle:@"Get More Questions" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(didTapGetMoreButton:) forControlEvents:UIControlEventTouchUpInside];
    [aView addSubview:button];
    [button setFrame:aView.frame];
    [[SPThemeResolver theme] themeQuestionFooterButton:button];
    self.tableView.tableFooterView = aView;
    
    // Content size changes
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(preferredContentSizeChanged:)
     name:UIContentSizeCategoryDidChangeNotification
     object:nil];
}

#pragma mark - Content Size Changes

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    [self.tableView reloadData];
}

#pragma mark - Question fetching and loading

-(void)getQuestionsByPageIndex:(NSUInteger)pageIndex{
    
    [self toggleLoadingState:YES];
    NSDictionary *parameters = @{@"tagged":@"objective-c",
                                 @"site":@"stackoverflow",
                                 @"order":@"desc",
                                 @"sort":@"activity",
                                 @"filter":@"!-.CabyPaznWF",
                                 @"page":[[NSNumber numberWithInteger:pageIndex] stringValue],
                                 @"pagesize":[[NSNumber numberWithInteger:kPageSize] stringValue]};
    
    StackOverflowQuestionsResponseBlock response = ^(NSArray *questions){
        [self toggleLoadingState:NO];
        self.rowCount = self.questions.count + questions.count;
        if(self.questions.count > 0){
            [self.questions addObjectsFromArray:questions];
        } else {
            self.questions = [NSMutableArray arrayWithArray:questions];
        }
        // Force the questions data to reload itself.
        self.questions = _questions;
    };
    
    MKNKErrorBlock errorBlock = ^(NSError *error) {
        [self toggleLoadingState:NO];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to get results"
                                                        message:@"Check your internet connection and try again"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Try Again", nil];
        [alert show];
    };
    
    [self.networkingEngine questionsWithParameters:parameters
                                 completionHandler:response
                                      errorHandler:errorBlock];
}

-(void)toggleLoadingState:(BOOL)isLoading{
    if(isLoading == NO){
        [self.activityView setHidden:YES];
        [self.tableView.tableFooterView setHidden:NO];
        [self.tableView setUserInteractionEnabled:YES];
    } else {
        [self.activityView setHidden:NO];
        [self.tableView.tableFooterView setHidden:YES];
        self.activityView.center= CGPointMake(self.activityView.center.x,self.tableView.contentOffset.y + self.activityView.frame.size.height);
        [self.tableView setUserInteractionEnabled:NO];
    }
}


-(void)didTapGetMoreButton:(id)sender{
    self.currentPageIndex++;
    [self getQuestionsByPageIndex:self.currentPageIndex];
}

#pragma mark - AlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == [alertView cancelButtonIndex]){
        // Cancel button.
    }else{
        // Try again.
        [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
        [self getQuestionsByPageIndex:self.currentPageIndex];
    }
}

#pragma mark - Setters

- (void) setQuestions:(NSArray *)questions{
    
    _questions = [questions mutableCopy];
    __weak SPQuestionTableViewController *weakSelf= self;
    
    __weak NSMutableArray *bodyTexts = [NSMutableArray arrayWithCapacity:self.questions.count];
    __weak NSMutableArray *titleTexts = [NSMutableArray arrayWithCapacity:self.questions.count];
    
    [self.questions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isMemberOfClass:[SPStackOverflowQuestion class]]) {
            [bodyTexts addObject:[obj body]];
            [titleTexts addObject:[obj title]];
        }
        if(idx == questions.count-1){
            weakSelf.titleArray = [NSArray arrayWithArray:titleTexts];
            weakSelf.bodyTextArray = [NSArray arrayWithArray:bodyTexts];
            [weakSelf.tableView performSelectorOnMainThread:@selector(reloadData)
                                                 withObject:nil
                                              waitUntilDone:YES];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Example application of how a category binding method is used to seperate concerns.
    // We don't want view controllers depending directly on a given model.
    SPStackOverflowQuestion *question = [self.questions objectAtIndex:indexPath.row];
    [cell bind:question atIndexPath:indexPath];
    
    return cell;
}

 #pragma mark - Navigation

 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
     if([[segue identifier] isEqualToString:@"AnswerSegue"]){
         
         UITableViewCell *cell = (UITableViewCell*)sender;
         NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
         SPStackOverflowQuestion *question = (SPStackOverflowQuestion*)self.questions[indexPath.row];
         
         SPAnswerTableViewController *answerTable = (SPAnswerTableViewController*)[segue destinationViewController];
         answerTable.question = question;
         answerTable.title = @"Answer";
     }
 }
 

@end