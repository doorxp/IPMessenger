/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: RetryInfo.m
 *	Module		: メッセージ再送情報クラス
 *============================================================================*/

#import "RetryInfo.h"
#import "UserInfo.h"

@interface RetryInfo()
@property(assign,readwrite)	UInt32		command;
@property(nonatomic,strong)	UserInfo*	toUser;
@property(nonatomic,strong)	NSString*	message;
@property(nonatomic,strong)	NSString*	option;
@end

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation RetryInfo

@synthesize	command		= _command;
@synthesize toUser		= _toUser;
@synthesize message		= _message;
@synthesize option		= _option;
@synthesize retryCount	= _retry;

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

+ (RetryInfo*)infoWithCommand:(UInt32)cmd
						   to:(UserInfo*)to
					  message:(NSString*)msg
					   option:(NSString*)opt
{
	return [[RetryInfo alloc] initWithCommand:cmd to:to message:msg option:opt];
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithCommand:(UInt32)cmd
				   to:(UserInfo*)to
			  message:(NSString*)msg
			   option:(NSString*)opt
{
	self = [super init];
	if (self) {
		self.command	= cmd;
		self.toUser		= to;
		self.message	= msg;
		self.option		= opt;
		self.retryCount	= 0;
	}
	return self;
}

// 解放
- (void)dealloc
{
//	[_toUser release];
//	[_message release];
//	[_option release];
//	[super dealloc];
    
    self.command    = nil;
    self.toUser        = nil;
    self.message    = nil;
}

@end
