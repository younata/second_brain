#import "WKWebView+SpecHelper.h"
#import <Foundation_PivotalCore/Foundation+PivotalCore.h>
#import <objc/runtime.h>

static char * kUrlKey;
static char * kRequestKey;
static char * kHtmlKey;

@interface WKWebView (SpecHelperPrivate)

- (nullable WKNavigation *)original_loadRequest:(nonnull NSURLRequest *)request;
- (nullable WKNavigation *)original_loadHTMLString:(nonnull NSString *)string baseURL:(nullable NSURL *)baseURL;

@end

@implementation WKWebView (SpecHelper)

+ (void)load {
    [[self class] redirectSelector:@selector(loadRequest:)
                                to:@selector(_loadRequest:)
                     andRenameItTo:@selector(original_loadRequest:)];

    [[self class] redirectSelector:@selector(loadHTMLString:baseURL:)
                                to:@selector(_loadHTMLString:baseURL:)
                     andRenameItTo:@selector(original_loadHTMLString:baseURL:)];
}

- (void)setCurrentURL:(NSURL * __nullable)currentURL {
    objc_setAssociatedObject(self, &kUrlKey, currentURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL * __nullable)currentURL {
    return objc_getAssociatedObject(self, &kUrlKey);
}

- (NSURL * __nullable)URL {
    return self.currentURL;
}

- (NSURLRequest * __nullable)lastRequestLoaded {
    return objc_getAssociatedObject(self, &kRequestKey);
}

- (nullable WKNavigation *)_loadRequest:(nonnull NSURLRequest *)request {
    objc_setAssociatedObject(self, &kRequestKey, request, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return nil;
}

- (NSString * __nullable)lastHTMLStringLoaded {
    return objc_getAssociatedObject(self, &kHtmlKey);
}

- (nullable WKNavigation *)_loadHTMLString:(nonnull NSString *)string baseURL:(nullable NSURL *)baseURL {
    objc_setAssociatedObject(self, &kHtmlKey, string, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return nil;
}

@end
