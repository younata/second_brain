//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "TargetConditionals.h"

#if TARGET_OS_SIMULATOR
    #import "UIViewController+SpecHelper.h"
#endif
#import "WKWebView+SpecHelper.h"
#import "NSUserActivity+SpecHelper.h"
