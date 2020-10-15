/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: SendMessage.m
 *	Module		: 送信メッセージ情報クラス
 *============================================================================*/

#import "SendMessage.h"
#import "MessageCenter.h"
#import "DebugLog.h"

@interface SendMessage()
@property(assign,readwrite)	NSInteger	packetNo;
@property(copy,readwrite)	NSString*	message;
@property(strong, nonatomic)NSArray*	attachments;
@property(assign,readwrite)	BOOL		sealed;
@property(assign,readwrite)	BOOL		locked;
@end

// クラス実装
@implementation SendMessage

@synthesize	packetNo	= _packetNo;
@synthesize message		= _message;
@synthesize attachments	= _attach;
@synthesize sealed		= _sealed;
@synthesize locked		= _locked;

/*============================================================================*
 * ファクトリ
 *============================================================================*/

// インスタンス生成
+ (id)messageWithMessage:(NSString*)msg
			 attachments:(NSArray*)attach
					seal:(BOOL)seal
					lock:(BOOL)lock
{
	return [[SendMessage alloc] initWithMessage:msg
									 attachments:attach
											seal:seal
											lock:lock];
}

/*============================================================================*
 * 初期化／解放
 *============================================================================*/

// 初期化
- (id)initWithMessage:(NSString*)msg
		  attachments:(NSArray*)attach
				 seal:(BOOL)seal
				 lock:(BOOL)lock
{
	self = [super init];
	if (self) {
		self.packetNo		= [MessageCenter nextMessageID];
		self.message		= msg;
		self.attachments	= attach;
		self.sealed			= seal;
		self.locked			= lock;
	}

	return self;
}

// 解放
- (void)dealloc
{
    self.message = nil;
    self.attachments = nil;
//	[_message release];
//	[_attach release];
//	[super dealloc];
}

/*============================================================================*
 * その他
 *============================================================================*/

// オブジェクト文字列表現
- (NSString*)description
{
	return [NSString stringWithFormat:@"SendMessage:PacketNo=%ld", self.packetNo];
}

// オブジェクトコピー
- (id)copyWithZone:(NSZone*)zone
{
	SendMessage* newObj	= [[SendMessage allocWithZone:zone] init];
	if (newObj) {
		newObj.packetNo	= self.packetNo;
		newObj.message	= self.message;
		newObj.attachments		= self.attachments;
		newObj.sealed		= self.sealed;
		newObj.locked		= self.locked;
	} else {
		ERR(@"copy error(%@)", self);
	}

	return newObj;
}

@end
