#import "EGClass.h"
#import "EGPrivate.h"
#import "EGFunctions.h"
#import "EGInternal.h"

@implementation EGClass
- (void)dealloc {
    DoThing(self);
    DoPrivateThing(self);
}
@end
