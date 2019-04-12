#import "NSUserActivity+SpecHelper.h"
#import "PCKMethodRedirector.h"
#import <objc/runtime.h>

static char * kCurrentKey;
static char * kInvalidKey;

@interface NSUserActivity (rNewsTestsPrivate)
- (void)original_becomeCurrent;
- (void)original_resignCurrent;
- (void)original_invalidate;
@end

@implementation NSUserActivity (rNewsTests)

+ (void)load {
    [PCKMethodRedirector redirectSelector:@selector(becomeCurrent)
                                 forClass:[self class]
                                       to:@selector(_becomeCurrent)
                            andRenameItTo:@selector(original_becomeCurrent)];

    [PCKMethodRedirector redirectSelector:@selector(resignCurrent)
                                 forClass:[self class]
                                       to:@selector(_resignCurrent)
                            andRenameItTo:@selector(original_resignCurrent)];

    [PCKMethodRedirector redirectSelector:@selector(invalidate)
                                 forClass:[self class]
                                       to:@selector(_invalidate)
                            andRenameItTo:@selector(original_invalidate)];
}

- (BOOL)isActive {
    return [objc_getAssociatedObject(self, &kCurrentKey) boolValue];
}

- (BOOL)isValid {
    return ![objc_getAssociatedObject(self, &kInvalidKey) boolValue];
}

- (void)_becomeCurrent {
    objc_setAssociatedObject(self, &kCurrentKey, @YES, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)_resignCurrent {
    objc_setAssociatedObject(self, &kCurrentKey, @NO, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)_invalidate {
    objc_setAssociatedObject(self, &kCurrentKey, @NO, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &kInvalidKey, @YES, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
