//
//  STMAuthVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMAuthVC.h"

@interface STMAuthVC () <UITextFieldDelegate>

@end

@implementation STMAuthVC

- (STMSpinnerView *)spinnerView {
    
    if (!_spinnerView) {
        _spinnerView = [STMSpinnerView spinnerViewWithFrame:self.view.frame];
    }
    return _spinnerView;
    
}

- (void)buttonPressed {
    
    [self.view addSubview:self.spinnerView];
    
    BOOL success = [self sendTextFieldValue];
    if (!success) [self.spinnerView removeFromSuperview];
    
}

- (void)dismissSpinner {
    [self.spinnerView removeFromSuperview];
}

- (BOOL)isCorrectValue:(NSString *)textFieldValue {
    return YES;
}

- (void)backButtonPressed {
    
}

- (BOOL)sendTextFieldValue {
    return NO;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if ([self isCorrectValue:textField.text]) {
        [self buttonPressed];
    }
    return NO;
    
}

- (void)textFieldDidChange:(UITextField *)textField {
    
    self.button.enabled = [self isCorrectValue:textField.text];
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    self.textField.delegate = self;
    self.textField.borderStyle = UITextBorderStyleNone;
    [self.textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.textField becomeFirstResponder];
    [self textFieldDidChange:self.textField];

    [self.button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];

    UIImage *image = [STMFunctions resizeImage:[UIImage imageNamed:@"exit-128.png"] toSize:CGSizeMake(22, 22)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(backButtonPressed)];
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];

//    NSLog(@"%@ viewDidLoad", self);

}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [self.navigationItem setHidesBackButton:YES animated:NO];
    [self textFieldDidChange:self.textField];

}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    [self.spinnerView removeFromSuperview];
    
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
