#import <CustomHeaderSearchPaths/PublicHeader.h>
#import "Internal/InternalHeader.h"
#import <libxml/parser.h>

@interface PublicClass () <InternalProtocol>
@end

@implementation PublicClass
@end
