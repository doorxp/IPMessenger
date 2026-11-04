#import "AttachmentCallbackRelay.h"

@interface AttachmentCallbackRelay ()
@property(nonatomic, strong) id<AttachmentClientListener> target;
@end

@implementation AttachmentCallbackRelay

- (instancetype)initWithTarget:(id<AttachmentClientListener>)target {
	if ((self = [super init])) {
		_target = target;
	}
	return self;
}

#define FORWARD_ATTACHMENT_CALLBACK(call) \
	do { if ([NSThread isMainThread]) { [self.target call]; } \
	else { dispatch_sync(dispatch_get_main_queue(), ^{ [self.target call]; }); } } while (0)
- (void)downloadWillStart { FORWARD_ATTACHMENT_CALLBACK(downloadWillStart); }
- (void)downloadDidFinished:(DownloadResult)result { FORWARD_ATTACHMENT_CALLBACK(downloadDidFinished:result); }
- (void)downloadIndexOfTargetChanged { FORWARD_ATTACHMENT_CALLBACK(downloadIndexOfTargetChanged); }
- (void)downloadFileChanged { FORWARD_ATTACHMENT_CALLBACK(downloadFileChanged); }
- (void)downloadNumberOfFileChanged { FORWARD_ATTACHMENT_CALLBACK(downloadNumberOfFileChanged); }
- (void)downloadNumberOfDirectoryChanged { FORWARD_ATTACHMENT_CALLBACK(downloadNumberOfDirectoryChanged); }
- (void)downloadTotalSizeChanged { FORWARD_ATTACHMENT_CALLBACK(downloadTotalSizeChanged); }
- (void)downloadDownloadedSizeChanged { FORWARD_ATTACHMENT_CALLBACK(downloadDownloadedSizeChanged); }
- (void)downloadPercentageChanged { FORWARD_ATTACHMENT_CALLBACK(downloadPercentageChanged); }
#undef FORWARD_ATTACHMENT_CALLBACK

@end
