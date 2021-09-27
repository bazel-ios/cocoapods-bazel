#import "EGPrivate.h"
#import "EGClass.h"

void DoPrivateThing(EGClass * foo) {
    (void)[foo description];
}
