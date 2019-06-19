//
//  BFRImageViewController.h
//  Buffer
//
//  Created by Jordan Morgan on 11/13/15.
//
//

#import <UIKit/UIKit.h>
#import "BFRHighResImageChanged.h"

@interface BFRImageViewController : UIViewController

- (instancetype _Nullable)init NS_UNAVAILABLE;

/*! Initializes an instance of @C BFRImageViewController from the image source provided. The array can contain a mix of @c NSURL, @c UIImage, @c PHAsset, @c BFRBackLoadedImageSource or @c NSStrings of URLS. This can be a mix of all these types, or just one. */
- (instancetype _Nullable)initWithImageSource:(NSArray * _Nonnull)images;

/*! Initializes an instance of @C BFRImageViewController from the image source provided. The array can contain a mix of @c NSURL, @c UIImage, @c PHAsset, or @c NSStrings of URLS. This can be a mix of all these types, or just one. Additionally, this customizes the user interface to defer showing some of its user interface elements, such as the close button, until it's been fully popped.*/
- (instancetype _Nullable)initForPeekWithImageSource:(NSArray * _Nonnull)images;

/*! Assigning YES to this property will make the background transparent. */
@property (nonatomic, getter=isUsingTransparentBackground) BOOL useTransparentBackground;

/*! Flag property that toggles the doneButton. Defaults to YES */
@property (nonatomic) BOOL enableDoneButton;

/*! Flag property that sets the doneButton position (left or right side). Defaults to YES */
@property (nonatomic) BOOL showDoneButtonOnLeft;

/*! Allows you to assign an index which to show first when opening multiple images. */
@property (nonatomic, assign) NSInteger startingIndex;

/*! Show photo counter */
@property (nonatomic, assign, getter=isCounterEnabled) BOOL counterEnabled;

@property (nonatomic, weak, nullable) id<BFRHighResImageChangedDelegate> imageChangedDelegate;

@end
