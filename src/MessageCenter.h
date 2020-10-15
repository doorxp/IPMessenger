/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: MessageCenter.h
 *	Module		: メッセージ送受信管理クラス
 *============================================================================*/

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SCDynamicStore.h>

@class RecvMessage;
@class SendMessage;

/*============================================================================*
 * Notification キー
 *============================================================================*/

// ホスト名変更
#define NOTICE_HOSTNAME_CHANGED		@"IPMsgHostNameChanged"
// ネットワーク検出/喪失
#define NOTICE_NETWORK_GAINED		@"IPMsgNetworkGained"
#define NOTICE_NETWORK_LOST			@"IPMsgNetworkLost"

/*============================================================================*
 * 構造体定義
 *============================================================================*/

// IPMsg受信パケット解析構造体
typedef struct
{
	unsigned	version;			// バージョン番号
	unsigned	packetNo;			// パケット番号
	char		userName[256];		// ログインユーザ名
	char		hostName[256];		// ホスト名
	unsigned	command;			// コマンド番号
	char		extension[4096];	// 拡張部

} IPMsgData;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface MessageCenter : NSObject
{
	// 送受信関連
	int						sockUDP;			// ソケットディスクリプタ
	
	BOOL					serverShutdown;		// サーバ停止フラグ
	
	unsigned long			myIPAddress;		// ローカルホストアドレス
//	NSInteger				myPortNo;			// ソケットポート番号
	
	// DynamicStore関連
	CFRunLoopSourceRef		runLoopSource;		// Run Loop Source Obj for SC Notification
	SCDynamicStoreRef		scDynStore;			// DynamicStore
	SCDynamicStoreContext	scDSContext;		// DynamicStoreContext
	
}


@property(nonatomic, readwrite)   NSInteger                myPortNo;            // ソケットポート番号

@property(nonatomic, strong)  NSString*                scKeyHostName;        // DynamicStore Key [for LocalHostName]
@property(nonatomic, strong)  NSString*                scKeyNetIPv4;        // DynamicStore Key [for Global IPv4]
@property(nonatomic, strong)  NSString*                scKeyIFIPv4;        // DynamicStore Key [for IF IPv4 Address]

@property(nonatomic, strong)  NSString*                myHostName;            // コンピュータ名

// 現在値
@property(nonatomic, strong)  NSString*                primaryNIC;            // 有線ネットワークインタフェース

@property(nonatomic, strong)  NSLock*                    sockLock;            // ソケット送信排他ロック
@property(nonatomic, strong)  NSMutableDictionary*    sendList;            // 応答待ちメッセージ一覧（再送用）
// 受信サーバ関連
@property(nonatomic, strong)  NSConnection*            serverConnection;    // メッセージ受信スレッドとのコネクション
@property(nonatomic, strong)  NSLock*                    serverLock;            // サーバ待ち合わせ用ロック

// ファクトリ
+ (MessageCenter*)sharedCenter;

// クラスメソッド
+ (long)nextMessageID;
+ (BOOL)isNetworkLinked;

// 受信Rawデータの分解
+ (BOOL)parseReceiveData:(char*)buffer length:(ssize_t)len into:(IPMsgData*)data;

// メッセージ送信（ブロードキャスト）
- (void)broadcastEntry;
- (void)broadcastAbsence;
- (void)broadcastExit;

// メッセージ送信（通常）
- (void)sendMessage:(SendMessage*)msg to:(NSArray*)to;
- (void)sendOpenSealMessage:(RecvMessage*)info;
- (void)sendReleaseAttachmentMessage:(RecvMessage*)info;

// 情報取得
- (NSInteger)myPortNo;
- (NSString*)myHostName;

@end
