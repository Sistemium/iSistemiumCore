//
//  STMCustomCells.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/06/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol STMTDCell <NSObject>

@property (weak, nonatomic) UILabel *titleLabel;
@property (weak, nonatomic) UILabel *detailLabel;


@end


@protocol STMTDICell <NSObject, STMTDCell>

@property (weak, nonatomic) UILabel *infoLabel;


@end


@protocol STMTDMCell <NSObject, STMTDCell>

@property (weak, nonatomic) UILabel *messageLabel;


@end


@protocol STMTDPCell <NSObject, STMTDCell>

@property (weak, nonatomic) UIImageView *pictureView;


@end
