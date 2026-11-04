#import "AttachmentClient.h"

@interface AttachmentCallbackRelay : NSObject <AttachmentClientListener>

- (instancetype)initWithTarget:(id<AttachmentClientListener>)target;

@end
