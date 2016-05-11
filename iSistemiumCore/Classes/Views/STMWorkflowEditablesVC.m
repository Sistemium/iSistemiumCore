//
//  STMWorkflowEditablesVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/09/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMWorkflowEditablesVC.h"
#import "STMWorkflowController.h"

#define H_SPACE 20
#define V_SPACE 20
//#define TEXT_VIEW_WIDTH 350
#define TEXT_VIEW_HEIGHT 50


@interface STMWorkflowEditablesVC ()

@property (nonatomic) CGFloat h_edge;
@property (nonatomic) CGFloat v_edge;

//@property (nonatomic) CGFloat textView_h_start;

@property (nonatomic, strong) NSMutableDictionary *fields;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic) CGFloat shiftDistance;
@property (nonatomic) BOOL viewFrameWasChanged;


@end


@implementation STMWorkflowEditablesVC

- (NSMutableDictionary *)fields {
    
    if (!_fields) {
        _fields = [NSMutableDictionary dictionary];
    }
    return _fields;
    
}


- (void)setupHeader {
    
    CGSize size;
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat h_edge = 0;
    CGFloat v_edge = 0;
    NSString *text;
    NSDictionary *attributes;
    
    UILabel *toLabel = [[UILabel alloc] init];
    attributes = @{NSFontAttributeName:toLabel.font};
    text = [STMWorkflowController labelForProcessing:self.toProcessing inWorkflow:self.workflow];
    size = [text sizeWithAttributes:attributes];
    width = ceil(size.width);
    height = ceil(size.height);
    
    toLabel.frame = CGRectMake(h_edge + H_SPACE, V_SPACE, width, height);
    toLabel.text = text;
    toLabel.textColor = [STMWorkflowController colorForProcessing:self.toProcessing inWorkflow:self.workflow];
    
    [self.scrollView addSubview:toLabel];
    
    h_edge += H_SPACE + width;
    v_edge = MAX((V_SPACE + height), v_edge);
    
    self.h_edge = MAX(self.h_edge, h_edge);
    self.v_edge = MAX(self.v_edge, v_edge);
    
}

- (void)setupFields {
    
    if (self.editableFields.count > 0) {
        
        self.fields[@"fields"] = self.editableFields;
        
        NSArray *labels = @[];
        
        for (NSString *field in self.editableFields) {
            
            labels = [labels arrayByAddingObjectsFromArray:@[[STMWorkflowController labelForEditableProperty:field]]];
            
        }
        
        self.fields[@"labels"] = labels;
        
//        self.textView_h_start = [self maxWidthForLabels:labels] + H_SPACE;
//        self.textView_h_start = H_SPACE;
        
        NSArray *textViews = @[];
        
        for (NSString *name in labels) {
            
            textViews = [textViews arrayByAddingObjectsFromArray:@[[self setupEditableFieldWithName:name]]];
            
        }
        
        self.fields[@"textViews"] = textViews;
        
        if (textViews.count > 0) {
            [textViews[0] becomeFirstResponder];
        }
        
    }
    
}

- (CGFloat)maxWidthForLabels:(NSArray *)labels {
    
    CGFloat width = 0;
    NSDictionary *attributes = @{NSFontAttributeName:[self labelFont]};
    
    for (NSString *name in labels) {
        
        CGSize size = [name sizeWithAttributes:attributes];
        width = MAX(ceil(size.width), width);
        
    }
    
    return width;
    
}

- (UIFont *)labelFont {
    
    UILabel *label = [[UILabel alloc] init];
    return label.font;
    
}

- (UITextView *)setupEditableFieldWithName:(NSString *)name {
    
    CGSize size;
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat h_edge = 0;
    CGFloat v_edge = 0;
    NSString *text;
    NSDictionary *attributes;
    
    // Setup label:
    
    UILabel *nameLabel = [[UILabel alloc] init];
    attributes = @{NSFontAttributeName:nameLabel.font};
    text = name;
    size = [text sizeWithAttributes:attributes];
    width = ceil(size.width);
    height = ceil(size.height);
    
    nameLabel.frame = CGRectMake(H_SPACE, self.v_edge + V_SPACE, width, height);
    nameLabel.text = text;
    nameLabel.textColor = [UIColor grayColor];
    
    [self.scrollView addSubview:nameLabel];
    
    // Setup textview:
    
    UITextView *tv = [[UITextView alloc] init];
//    width = TEXT_VIEW_WIDTH;
    width = self.scrollView.frame.size.width - 2 * H_SPACE;
    height = TEXT_VIEW_HEIGHT;
    
    tv.frame = CGRectMake(H_SPACE, self.v_edge + V_SPACE + nameLabel.frame.size.height, width, height);
    tv.layer.borderColor = [[UIColor grayColor] CGColor];
    tv.layer.borderWidth = 1.0f;
    
    [self.scrollView addSubview:tv];
    
    h_edge = H_SPACE + width;
    v_edge = MAX((self.v_edge + V_SPACE + nameLabel.frame.size.height + height), v_edge);
    
    
    self.h_edge = MAX(self.h_edge, h_edge);
    self.v_edge = MAX(self.v_edge, v_edge);
    
    return tv;
    
}

- (void)setupButtons {
    
    CGFloat height = TOOLBAR_HEIGHT;
    
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.frame = CGRectMake(0, self.view.frame.size.height - height, self.view.frame.size.width, height);
    
    STMBarButtonItemCancel *cancelButton = [[STMBarButtonItemCancel alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                target:self
                                                                                                action:@selector(cancelButtonPressed)];
    
    STMBarButtonItem *flexibleSpace = [STMBarButtonItem flexibleSpace];
    
    STMBarButtonItemDone *doneButton = [[STMBarButtonItemDone alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneButtonPressed)];
    
    [self.toolbar setItems:@[cancelButton, flexibleSpace, doneButton]];
    
    [self.view addSubview:self.toolbar];
    
    self.v_edge += height + V_SPACE;
    
}


#pragma mark - buttons

- (void)cancelButtonPressed {
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];

}

- (void)doneButtonPressed {
    
    NSMutableDictionary *editableValues = [NSMutableDictionary dictionary];
    
    NSArray *textViews = self.fields[@"textViews"];
    
    for (UITextView *tv in textViews) {
        
        NSString *normalizeString = [tv.text stringByReplacingOccurrencesOfString:@" " withString:@""];
        normalizeString = [normalizeString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        
        if (tv.text && ![normalizeString isEqualToString:@""]) {
            
            NSUInteger index = [textViews indexOfObject:tv];
            NSString *editableField = self.fields[@"fields"][index];
            
            editableValues[editableField] = tv.text;
            
        }
        
    }
    
    [self.parent takeEditableValues:editableValues];
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
    
}


#pragma mark - keyboard show / hide

- (void)keyboardWillShow:(NSNotification *)notification {
    
    CGFloat keyboardHeight = [self keyboardHeightFrom:[notification userInfo]];

    self.shiftDistance = keyboardHeight;
    
    if (!self.viewFrameWasChanged) {
        
        [self changeViewFrameByDistance:self.shiftDistance];
        self.viewFrameWasChanged = YES;
        
    }
    
}

- (void)keyboardWillBeHidden:(NSNotification *)notification {
    
    if (self.viewFrameWasChanged) {
        
        [self changeViewFrameByDistance:-self.shiftDistance];
        self.viewFrameWasChanged = NO;
        
    }
    
}

- (CGFloat)keyboardHeightFrom:(NSDictionary *)info {
    
    CGRect keyboardRect = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    keyboardRect = [[[UIApplication sharedApplication].delegate window] convertRect:keyboardRect fromView:self.view];
    
    return keyboardRect.size.height;
    
}

- (void)changeViewFrameByDistance:(CGFloat)distance {
    
    const float movementDuration = 0.0f;
    
    [UIView beginAnimations:@"animation" context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:movementDuration];
    
    CGFloat x = self.scrollView.frame.origin.x;
    CGFloat y = self.scrollView.frame.origin.y;
    CGFloat width = self.scrollView.frame.size.width;
    CGFloat height = self.scrollView.frame.size.height;
    
    self.scrollView.frame = CGRectMake(x, y, width, height - distance);

    x = self.toolbar.frame.origin.x;
    y = self.toolbar.frame.origin.y;
    width = self.toolbar.frame.size.width;
    height = self.toolbar.frame.size.height;
    
    self.toolbar.frame = CGRectMake(x, y - distance, width, height);
    
    [UIView commitAnimations];
    
}


#pragma mark - view lifecycle

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(keyboardWillShow:)
               name:UIKeyboardWillShowNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(keyboardWillBeHidden:)
               name:UIKeyboardWillHideNotification
             object:nil];

}

- (void)customInit {
    
    self.h_edge = 0;
    self.v_edge = 0;
    
    CGRect frame = self.view.bounds;
    
    UIApplication *app = [UIApplication sharedApplication];
    
    if(!app.statusBarHidden) {
        
        CGFloat statusBarHeight = app.statusBarFrame.size.height;
        CGFloat toolbarHeight = TOOLBAR_HEIGHT;
        
        frame = CGRectMake(0, statusBarHeight, frame.size.width, frame.size.height - statusBarHeight - toolbarHeight);
        
    }

    self.scrollView = [[UIScrollView alloc] initWithFrame:frame];
    
    [self.view addSubview:self.scrollView];

    [self setupHeader];
    [self setupFields];
    [self setupButtons];
    
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, self.v_edge);
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self addObservers];

}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
