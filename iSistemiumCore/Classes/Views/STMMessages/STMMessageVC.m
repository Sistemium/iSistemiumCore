//
//  STMMessageVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMMessageVC.h"

#import "STMFunctions.h"

#import "STMMessageController.h"
#import "STMPicturesController.h"


@interface STMMessageVC ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic, strong) UIView *spinnerView;


@end


@implementation STMMessageVC

- (UIView *)spinnerView {
    
    if (!_spinnerView) {
        
        UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        view.backgroundColor = [UIColor whiteColor];
        view.alpha = 0.75;
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.center = view.center;
        spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [spinner startAnimating];
        [view addSubview:spinner];
        
        _spinnerView = view;
        
    }
    
    return _spinnerView;
    
}

- (void)tapView {
    
    [STMMessageController pictureDidShown:self.picture];
    
    [self removeObservers];
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)pictureDownloaded:(NSNotification *)notification {
    
    [self removeObservers];
    [self setupImage];
    
}

- (void)setupImage {
    
    UIImage *image = [UIImage imageWithContentsOfFile:[STMFunctions absolutePathForPath:self.picture.resizedImagePath]];
    
    if (image) {
        
        [self.spinnerView removeFromSuperview];
        self.spinnerView = nil;

        self.imageView.image = image;
//        [self.imageView setNeedsDisplay];
        
    } else {
        
        [self addObservers];
        [STMPicturesController hrefProcessingForObject:self.picture];
        
        [self.view addSubview:self.spinnerView];
        
    }

}

- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pictureDownloaded:) name:@"downloadPicture" object:self.picture];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - view lifecycle

- (void)customInit {
    
    self.modalPresentationStyle = UIModalPresentationFullScreen;

    [self setupImage];
    
    self.textView.text = self.text;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapView)];
    
    [self.view addGestureRecognizer:tap];
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
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
