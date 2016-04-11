//
//  STMAuthPhoneVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMAuthPhoneVC.h"

@interface STMAuthPhoneVC () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *phoneNumberLabel;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberTextField;
@property (weak, nonatomic) IBOutlet UIButton *sendPhoneNumberButton;


@end


@implementation STMAuthPhoneVC

- (BOOL)isCorrectValue:(NSString *)textFieldValue {
    return [STMFunctions isCorrectPhoneNumber:textFieldValue];
}

- (BOOL)sendTextFieldValue {
    return [[STMAuthController authController] sendPhoneNumber:self.textField.text];
}


#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
        
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    self.navigationItem.title = NSLocalizedString(@"ENTER TO SISTEMIUM", nil);
    self.phoneNumberLabel.text = NSLocalizedString(@"ENTER PHONE NUMBER", nil);
    self.phoneNumberTextField.text = [STMAuthController authController].phoneNumber;
    [self.sendPhoneNumberButton setTitle:NSLocalizedString(@"SEND", nil) forState:UIControlStateNormal];
    
    self.phoneNumberTextField.delegate = self;
    
    self.textField = self.phoneNumberTextField;
    self.button = self.sendPhoneNumberButton;
    
    [super customInit];
 
    self.navigationItem.leftBarButtonItem = nil;

}

- (void)viewDidLoad {
    
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
