/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: RecvMessage.h
 *	Module		: 受信メッセージクラス
 *============================================================================*/

#import <Foundation/Foundation.h>
#import <netinet/in.h>

@class UserInfo;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface RecvMessage : NSObject <NSCopying>


@property(nonatomic, strong) UserInfo*            fromUser;        // 送信元ユーザ
@property(nonatomic, readwrite) BOOL                unknownUser;    // 未知のユーザフラグ
@property(nonatomic, strong) NSString*            logOnUser;        // ログイン名
@property(nonatomic, strong) NSString*            hostName;        // ホスト名
@property(nonatomic, readwrite) unsigned long        command;        // コマンド番号
@property(nonatomic, strong) NSString*            appendix;        // 追加部
@property(nonatomic, strong) NSString*            appendixOption;    // 追加部オプション
@property(nonatomic, strong) NSMutableArray*        attachments;    // 添付ファイル
@property(nonatomic, strong) NSMutableArray*        hostList;        // ホストリスト
@property(nonatomic, readwrite) int                    continueCount;    // ホストリスト継続ユーザ番号
@property(nonatomic, readwrite) BOOL                needLog;        // ログ出力フラグ

//@property(nonatomic, strong) NSDate*                date;
//@property(nonatomic, readwrite) struct sockaddr_in    address;


@property(readonly)	NSInteger			packetNo;		// パケット番号
@property(readonly)	NSDate*				receiveDate;	// 受信日時
//@property(readonly)	struct sockaddr_in	fromAddress;	// 送信元アドレス

// ファクトリ
+ (RecvMessage*)messageWithBuffer:(const void*)buf
						   length:(NSUInteger)len
							 from:(struct sockaddr_in)addr;

// 初期化／解放
- (id)initWithBuffer:(const void*)buf
			  length:(NSUInteger)len
				from:(struct sockaddr_in)addr;

// getter（相手情報）
- (UserInfo*)fromUser;
- (BOOL)isUnknownUser;

// getter（共通）
//- (NSString*)logOnUser;
//- (NSString*)hostName;
- (unsigned long)command;
- (NSString*)appendix;
//- (NSString*)appendixOption;

// getter（IPMSG_SENDMSGのみ）
- (BOOL)sealed;
- (BOOL)locked;
- (BOOL)multicast;
- (BOOL)broadcast;
- (BOOL)absence;
- (NSMutableArray*)attachments;

// getter（IPMSG_ANSLISTのみ）
- (NSMutableArray*)hostList;
- (int)hostListContinueCount;

// その他
- (void)removeDownloadedAttachments;
- (BOOL)needLog;
- (void)setNeedLog:(BOOL)flag;

@end
