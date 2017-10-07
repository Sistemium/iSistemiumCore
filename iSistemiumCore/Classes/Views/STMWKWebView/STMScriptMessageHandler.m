//
//  STMScriptMessageHandler.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler+Private.h"
#import "STMImagePickerController.h"
#import "STMCorePicturesController.h"
#import "STMCorePhotosController.h"
#import <Photos/Photos.h>
#import "STMLogger.h"

@implementation STMScriptMessagingSubscription

@end

@implementation STMScriptMessageHandler

- (instancetype)initWithOwner:(id <STMScriptMessagingOwner>)owner{
    id result = [self init];
    self.owner = (UIViewController<STMScriptMessagingOwner>*) owner;
    _subscriptions = [NSMutableDictionary dictionary];
    return result;
}

- (NSMutableArray *)subscribedObjects {
    
    if (!_subscribedObjects) {
        _subscribedObjects = @[].mutableCopy;
    }
    return _subscribedObjects;
    
}

- (void)setPersistenceDelegate:(id)persistenceDelegate {
    
    _persistenceDelegate = persistenceDelegate;
    
    if ([persistenceDelegate conformsToProtocol:@protocol(STMModelling)]) {
        _modellingDelegate = persistenceDelegate;
    }
    
}

- (STMSpinnerView *)spinnerView {
    
    if (!_spinnerView) {
        _spinnerView = [STMSpinnerView spinnerViewWithFrame:self.owner.view.frame];
    }
    return _spinnerView;
    
}

- (void)handleTakePhotoMessage:(WKScriptMessage *)message {
    
    if (self.waitingPhoto) return;
    
    NSDictionary *parameters = message.body;
    
    NSString *entityName = parameters[@"entityName"];
    self.photoEntityName = [STMFunctions addPrefixToEntityName:entityName];
    
    if (![self.persistenceDelegate isConcreteEntityName:entityName]) {
        NSString *error = [NSString stringWithFormat:@"local data model have not entity with name %@", entityName];
        return [self.owner callbackWithError:error parameters:parameters];
    }
    
    self.waitingPhoto = YES;
    
    self.takePhotoMessageParameters = parameters;
    self.takePhotoCallbackJSFunction = parameters[@"callback"];
    self.photoData = [parameters[@"data"] isKindOfClass:[NSDictionary class]] ? parameters[@"data"] : @{};
    
    UIImagePickerControllerSourceType imageSource = -1;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        
        imageSource = UIImagePickerControllerSourceTypeCamera;
        
    } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        
        imageSource = UIImagePickerControllerSourceTypePhotoLibrary;
        
    } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]) {
        
        imageSource = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        
    } else {
        
        self.waitingPhoto = NO;
        return [self.owner callbackWithError:@"have no one available source types"
                            parameters:self.takePhotoMessageParameters];
        
    }
    
    [self performSelector:@selector(checkImagePickerWithSourceTypeNumber:) withObject:@(imageSource) afterDelay:0];
    
}

- (void)handleCopyToClipboardMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *callback = parameters[@"callback"];
    NSString *text = parameters[@"text"];
    
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    [pb setString:text];
    
    [self.owner callbackWithData:@[]
                      parameters:parameters
              jsCallbackFunction:callback];
    
}

- (void)handleSendToCameraRollMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *callback = parameters[@"callback"];
    NSString *imageID = parameters[@"imageID"];
    
    [STMCorePicturesController.sharedController loadImageForPrimaryKey:imageID]
    .then(^ (NSDictionary *downloadedPicture){
        
        UIImage *image = [STMCorePicturesController.sharedController imageFileForPrimaryKey:downloadedPicture[STMPersistingKeyPrimary]];
        
        if (!image){

            return [self.owner callbackWithData:@""
                                     parameters:parameters
                             jsCallbackFunction:callback];
            
        }
        
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            
            if (status == PHAuthorizationStatusAuthorized) {
                
                [self.owner callbackWithData:@[]
                                  parameters:parameters
                          jsCallbackFunction:callback];
                
            }
            
            else {
                
                [self.owner callbackWithData:NSLocalizedString(@"GIVE PERMISSIONS", nil)
                                  parameters:parameters
                          jsCallbackFunction:callback];
                
            }
            
        }];
        
    })
    .catch(^ (NSError *error) {
       
        return [self.owner callbackWithData:@""
                                 parameters:parameters
                         jsCallbackFunction:callback];
        
    });
    
}

- (void)handleLoadImageMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    NSString *callback = parameters[@"callback"];
    NSString *identifier = parameters[@"imageID"];
    
    [STMCorePicturesController.sharedController loadImageForPrimaryKey:identifier]
    .then(^ (NSDictionary *downloadedPicture){
        [self.owner callbackWithData:@[downloadedPicture]
                          parameters:parameters
                  jsCallbackFunction:callback];
    })
    .catch(^ (NSError *error) {
        [self.owner callbackWithData:@""
                          parameters:parameters
                  jsCallbackFunction:callback];
    });
    
}

- (void)handleGetPictureMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    [self handleGetPictureParameters:parameters];
    
}

- (void)handleSaveImageMessage:(WKScriptMessage *)message {
    
    self.takePhotoMessageParameters = message.body;
    self.takePhotoCallbackJSFunction = self.takePhotoMessageParameters[@"callback"];
    
    self.photoEntityName = self.takePhotoMessageParameters[@"entityName"];
    self.photoData = self.takePhotoMessageParameters[@"data"];
    
    NSString *base64String = self.takePhotoMessageParameters[@"imageData"];
    NSURL *url = [NSURL URLWithString:base64String];
    NSData *imageData = [NSData dataWithContentsOfURL:url];
    UIImage *image = [UIImage imageWithData:imageData];
    
    [self saveImage:image];
    
}

- (void)receiveFindMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self arrayOfObjectsRequestedByScriptMessage:message].then(^(NSArray *result){
        
        [self.owner callbackWithData:result
                          parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    });
    
}

- (void)receiveUpdateMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self updateObjectsFromScriptMessage:message
                   withCompletionHandler:^(BOOL success, NSArray *updatedObjects, NSError *error) {
        
        if (success) {
            [self.owner callbackWithData:updatedObjects
                              parameters:parameters];
        } else {
            [self.owner callbackWithError:error.localizedDescription
                               parameters:parameters];
        }
        
    }];
    
}

- (void)receiveSubscribeMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSLog(@"receiveSubscribeMessage: %@", parameters);
    
    NSArray *entities = parameters[@"entities"];
    
    if (![entities isKindOfClass:NSArray.class]) {
        [self.owner callbackWithError:@"message.parameters.entities is not a NSArray class"
                           parameters:parameters];
    }
    
    NSString *errorMessage;

    NSString *dataCallback = parameters[@"dataCallback"];
    NSString *callback = parameters[@"callback"];
    
    if (!dataCallback) {
        errorMessage = @"No dataCallback specified";
    } else if (!callback) {
        errorMessage = @"No callback specified";
    }
    
    if (errorMessage) {
        return [self.owner callbackWithError:errorMessage parameters:parameters];
    }
    
    NSError *error = nil;
    
    if ([self subscribeToEntities:entities callbackName:dataCallback error:&error]) {
        
        [self.owner callbackWithData:@[@"subscribe to entities success"]
                          parameters:parameters
                  jsCallbackFunction:callback];
        
    } else {
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    }
    
}

- (void)receiveDestroyMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    [self destroyObjectFromScriptMessage:message].then(^(NSArray *result){
        
        [self.owner callbackWithData:result
                          parameters:parameters];
        
    }).catch(^(NSError *error){
        
        [self.owner callbackWithError:error.localizedDescription
                           parameters:parameters];
        
    });
    
}

- (void)cancelSubscriptions {
    
    NSLog(@"unsubscribeViewController: %@", self.owner);
    [self flushSubscribedViewController];
    
}

#pragma mark - STMImagePickerOwnerProtocol

- (void)checkImagePickerWithSourceTypeNumber:(NSNumber *)sourceTypeNumber {
    
    NSUInteger imageSourceType = sourceTypeNumber.integerValue;
    
    if ([UIImagePickerController isSourceTypeAvailable:imageSourceType]) {
        
        [self showImagePickerForSourceType:imageSourceType];
        
    } else {
        
        NSString *imageSourceTypeString = [self stringValueForImageSourceType:imageSourceType];
        
        self.waitingPhoto = NO;
        
        NSString *message = [NSString stringWithFormat:@"%@ source type is not available", imageSourceTypeString];
        
        [self.owner callbackWithError:message parameters:self.takePhotoMessageParameters];
        
    }
    
}

- (NSString *)stringValueForImageSourceType:(UIImagePickerControllerSourceType)imageSourceType {
    
    return @{
             @(UIImagePickerControllerSourceTypePhotoLibrary): @"PhotoLibrary",
             @(UIImagePickerControllerSourceTypeCamera): @"Camera",
             @(UIImagePickerControllerSourceTypeSavedPhotosAlbum): @"PhotosAlbum"
             }[@(imageSourceType)];
    
}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)imageSourceType {
    
    STMImagePickerController *imagePickerController = [[STMImagePickerController alloc] initWithSourceType:imageSourceType];
    imagePickerController.ownerVC = self;
    
    [self.owner.tabBarController presentViewController:imagePickerController animated:YES completion:^{
//        [self.owner.view addSubview:self.spinnerView];
    }];
    
}

- (BOOL)shouldWaitForLocation {
    return NO;
}

- (void)saveImage:(UIImage *)image withLocation:(CLLocation *)location {
    [self saveImage:image];
}

- (void)saveImage:(UIImage *)image andWaitForLocation:(BOOL)waitForLocation {
    [self saveImage:image];
}

- (void)imagePickerWasDissmised:(UIImagePickerController *)picker {
    
//    [self.spinnerView removeFromSuperview];
//    self.spinnerView = nil;
    
    self.waitingPhoto = NO;
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    [self imagePickerWasDissmised:picker];
    
    //    [self callbackWithData:@[@"imagePickerControllerDidCancel"]
    //                parameters:self.takePhotoMessageParameters
    //        jsCallbackFunction:self.takePhotoCallbackJSFunction];
    
    [self.owner callbackWithError:@"imagePickerControllerDidCancel"
                 parameters:self.takePhotoMessageParameters];
    
}

- (void)saveImage:(UIImage *)image {
    
    CGFloat jpgQuality = [STMCorePicturesController.sharedController jpgQuality];
    
    NSData *jpgData = UIImageJPEGRepresentation(image, jpgQuality);
    
    NSMutableDictionary *attributes = [STMCorePhotosController newPhotoObjectEntityName:self.photoEntityName photoData:jpgData].mutableCopy;
    
    if (!attributes) {
        self.waitingPhoto = NO;
        return [self.owner callbackWithError:@"no photo object" parameters:self.takePhotoMessageParameters];
    }
    
    [attributes addEntriesFromDictionary:self.photoData];
    
    [self.persistenceDelegate merge:self.photoEntityName attributes:attributes.copy options:nil]
    .then(^(NSDictionary *result) {
        
        [self.owner callbackWithData:@[result]
                    parameters:self.takePhotoMessageParameters
            jsCallbackFunction:self.takePhotoCallbackJSFunction];
        
        [STMCorePhotosController uploadPhotoEntityName:self.photoEntityName antributes:result photoData:jpgData];
        
    })
    .catch(^(NSError *error) {
        
        NSLog(error.localizedDescription);
        
        NSString *logMessage = [NSString stringWithFormat:@"Error on merge during saveImage: %@", error.localizedDescription];
        
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
        
        [self.owner callbackWithError:error.localizedDescription parameters:self.takePhotoMessageParameters];
        
    })
    .always(^(){
        self.waitingPhoto = NO;
    });
    
    
}

@end
