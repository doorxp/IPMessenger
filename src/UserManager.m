/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: UserManager.m
 *	Module		: ユーザ一覧管理クラス
 *============================================================================*/

#import <Foundation/Foundation.h>
#import "UserManager.h"
#import "UserInfo.h"
#import "DebugLog.h"

#import <netinet/in.h>

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation UserManager

/*----------------------------------------------------------------------------*
 * ファクトリ
 *----------------------------------------------------------------------------*/

// 共有インスタンスを返す
+ (UserManager*)sharedManager {
	static UserManager* sharedManager = nil;
	if (!sharedManager) {
		sharedManager = [[UserManager alloc] init];
	}
	return sharedManager;
}

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init {
	self		= [super init];
	self.userList	= [[NSMutableArray alloc] init];
	self.dialupSet	= [[NSMutableSet alloc] init];
	self.lock		= [[NSRecursiveLock alloc] init];
	[self.lock setName:@"UserManagerLock"];
	return self;
}

// 解放
- (void)dealloc {
    self.userList = nil;
    self.dialupSet = nil;
    self.lock = nil;
//	[userList release];
//	[dialupSet release];
//	[lock release];
//	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * ユーザ情報取得
 *----------------------------------------------------------------------------*/

// ユーザリストを返す
- (NSArray*)users {
	[self.lock lock];
	NSArray* array = [NSArray arrayWithArray:self.userList];
	[self.lock unlock];
	return array;
}

// ユーザ数を返す
- (int)numberOfUsers {
	[self.lock lock];
	int count = (int)[self.userList count];
	[self.lock unlock];
	return count;
}

// 指定インデックスのユーザ情報を返す（見つからない場合nil）
- (UserInfo*)userAtIndex:(int)index {
	[self.lock lock];
	UserInfo* info = [self.userList objectAtIndex:index];
	[self.lock unlock];
	return info;
}

// 指定キーのユーザ情報を返す（見つからない場合nil）
- (UserInfo*)userForLogOnUser:(NSString*)logOn address:(UInt32)addr port:(UInt16)port {
	UserInfo*	info = nil;
	int			i;
	[self.lock lock];
	for (i = 0; i < [self.userList count]; i++) {
		UserInfo* u = [self.userList objectAtIndex:i];
		if ([u.logOnName isEqualToString:logOn] &&
			(u.ipAddressNumber == addr) &&
			(u.portNo == port)) {
			info = u;
			break;
		}
	}
	[self.lock unlock];
	return info;
}

/*----------------------------------------------------------------------------*
 * ユーザ情報追加／削除
 *----------------------------------------------------------------------------*/

// ユーザ一覧変更通知発行
- (void)fireUserListChangeNotice {
	[[NSNotificationCenter defaultCenter] postNotificationName:NOTICE_USER_LIST_CHANGED object:nil];
}

// ユーザ追加
- (void)appendUser:(UserInfo*)info {
	if (info) {
		[self.lock lock];
		NSUInteger index = [self.userList indexOfObject:info];
		if (index == NSNotFound) {
			// なければ追加
			[self.userList addObject:info];
		} else {
			// あれば置き換え
			[self.userList replaceObjectAtIndex:index withObject:info];
		}
		// ダイアルアップユーザであればアドレス一覧を更新
		if (info.dialupConnect) {
			[self.dialupSet addObject:[info.ipAddress copy]];
		}
		[self.lock unlock];
		[self fireUserListChangeNotice];
	}
}

// バージョン情報設定
- (void)setVersion:(NSString*)version ofUser:(UserInfo*)user {
	if (user) {
		[self.lock lock];
		NSUInteger index = [self.userList indexOfObject:user];
		if (index != NSNotFound) {
			// あれば設定
			user.version = version;
			[self fireUserListChangeNotice];
		}
		[self.lock unlock];
	}
}

// ユーザ削除
- (void)removeUser:(UserInfo*)info {
	if (info) {
		[self.lock lock];
		NSUInteger index = [self.userList indexOfObject:info];
		if (index != NSNotFound) {
			// あれば削除
			[self.userList removeObjectAtIndex:index];
			if ([self.dialupSet containsObject:info.ipAddress]) {
				[self.dialupSet removeObject:info.ipAddress];
			}
			[self fireUserListChangeNotice];
		}
		[self.lock unlock];
	}
}

// ずべてのユーザを削除
- (void)removeAllUsers {
	[self.lock lock];
	[self.userList removeAllObjects];
	[self.dialupSet removeAllObjects];
	[self.lock unlock];
	[self fireUserListChangeNotice];
}

// ダイアルアップアドレス一覧
- (NSArray*)dialupAddresses {
	[self.lock lock];
	NSArray* array = [self.dialupSet allObjects];
	[self.lock unlock];
	return array;
}

@end
