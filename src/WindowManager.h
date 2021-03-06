/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: WindowManager.h
 *	Module		: 送受信ウィンドウ管理クラス
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class ReceiveControl;
@class SendControl;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface WindowManager : NSObject

@property(nonatomic, strong) NSMutableDictionary* receiveDic;    // 受信ウィンドウ一覧
@property(nonatomic, strong) NSMutableDictionary* replyDic;        // 返信ウィンドウ一覧

// ファクトリ
+ (WindowManager*)sharedManager;

// 受信ウィンドウ管理
- (NSInteger)numberOfReceiveWindows;
- (ReceiveControl*)receiveWindowForKey:(id)aKey;
- (void)setReceiveWindow:(ReceiveControl*)aWindow forKey:(id)aKey;
- (void)removeReceiveWindowForKey:(id)aKey;

// 返信ウィンドウ管理
- (NSInteger)numberOfReplyWindows;
- (SendControl*)replyWindowForKey:(id)aKey;
- (void)setReplyWindow:(SendControl*)aWindow forKey:(id)aKey;
- (void)removeReplyWindowForKey:(id)aKey;

@end
