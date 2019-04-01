#import <UIKit/UIKit.h>

@interface UIViewController (SpecHelper)

@property (nonatomic, strong, readonly) UIViewController * _Nullable shownViewController;
@property (nonatomic, strong, readonly) UIViewController * _Nullable detailViewController;

@end
