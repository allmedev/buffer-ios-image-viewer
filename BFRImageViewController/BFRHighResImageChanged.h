//
//  BFRHighResImageChanged.h
//  BFRImageViewer
//
//  Created by Nikolay Kropachev on 19/06/2019.
//  Copyright © 2019 Andrew Yates. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BFRHighResImageChangedDelegate <NSObject>

- (void)highResImageChanged:(UIImage * _Nullable)image NS_SWIFT_NAME(highResImageChanged(image:));

@end

@protocol BFRHighResImageLoadedDelegate <NSObject>

- (void)highResImageLoaded;

@end
