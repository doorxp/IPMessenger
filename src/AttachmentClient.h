/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: AttachmentClient.h
 *	Module		: 添付ファイルダウンローダクラス
 *============================================================================*/

#import <Foundation/Foundation.h>
#import "IPMessenger.h"

@class RecvMessage;
@class Attachment;
@class AttachmentClient;

/*============================================================================*
 * 定数定義
 *============================================================================*/

// ダウンロード結果コード
typedef enum
{
	DL_SUCCESS,					// 成功
	DL_STOP,					// 停止（ユーザからの）
	DL_TIMEOUT,					// 通信タイムアウト
	DL_SOCKET_ERROR,			// ソケットエラー
	DL_CONNECT_ERROR,			// 接続エラー
	DL_DISCONNECTED,			// 切断
	DL_COMMUNICATION_ERROR,		// 送受信エラー
	DL_FILE_OPEN_ERROR,			// ファイルオープンエラー
	DL_INVALID_DATA,			// 異常データ受信
	DL_INTERNAL_ERROR,			// 内部エラー
	DL_SIZE_NOT_ENOUGH,			// ファイルサイズ以上
	DL_OTHER_ERROR				// その他エラー（未使用）

} DownloadResult;

/*============================================================================*
 * プロトコル定義
 *============================================================================*/

// ダウンロード状況コールバックプロトコル
@protocol AttachmentClientListener
- (void)downloadWillStart;								// ダウンロード開始
- (void)downloadDidFinished:(DownloadResult)result;		// ダウンロード終了
- (void)downloadIndexOfTargetChanged;					// 対象添付ファイル変化（ディレクトリ配下は無関係）
- (void)downloadFileChanged;							// ダウンロード対象ファイル変化（ディレクトリ配下ファイルでも通知）
- (void)downloadNumberOfFileChanged;					// ファイル数変化
- (void)downloadNumberOfDirectoryChanged;				// フォルダ数変化
- (void)downloadTotalSizeChanged;						// 全体データサイズ変更（ディレクトリ配下のサイズ加算時）
- (void)downloadDownloadedSizeChanged;					// ダウンロード済みデータサイズ変化（データ受信時）
- (void)downloadPercentageChanged;						// ダウンロード済みデータ割合変化
@end

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface AttachmentClient : NSObject {
	// ダウンロード管理変数

	BOOL				stop;			// ダウンロード中止フラグ
	
	id					_listener;		// コールバックオブジェクト
	
	
	
	
}

@property(nonatomic, strong)  RecvMessage*        message;        // 受信メッセージ
@property(nonatomic, strong)  NSMutableArray*        targets;        // ダウンロード対象添付ファイルリスト
@property(nonatomic, strong)  NSLock*                lock;            // ダウンロード処理中ロック
@property(nonatomic, strong)  NSString*            savePath;        // 保存先パス
@property(nonatomic, strong)  NSConnection*        connection;        // ダウンロードスレッドとのコネクション
// ステータス管理変数
@property(nonatomic, strong)  NSDate*                startDate;        // 開始時刻
@property(nonatomic, strong)  NSString*            currentFile;    // ダウンロード中ファイル／ディレクトリ名

@property(nonatomic, readwrite)unsigned long long    totalSize;        // 全体サイズ
@property(nonatomic, readwrite)unsigned long long    downloadSize;    // ダウンロード済みサイズ
@property(nonatomic, readwrite)unsigned            percentage;        // ダウンロード済率

@property(nonatomic, readwrite)unsigned            indexOfTarget;    // ダウンロード中添付ファイルインデックス

@property(nonatomic, readwrite)unsigned            numberOfFile;    // 処理済みファイル数
@property(nonatomic, readwrite)unsigned            numberOfDirectory;    // 処理済みディレクトリ数

// 初期化
- (id)initWithRecvMessage:(RecvMessage*)msg saveTo:(NSString*)path;

// 対象添付ファイル管理
- (NSUInteger)numberOfTargets;
- (void)addTarget:(Attachment*)attachment;

// ダウンロード開始／終了
- (void)startDownload:(id<AttachmentClientListener>)obj;
- (void)stopDownload;

// getter
- (unsigned)indexOfTarget;
- (NSString*)currentFile;
- (unsigned)numberOfFile;
- (unsigned)numberOfDirectory;
- (unsigned long long)totalSize;
- (unsigned long long)downloadSize;
- (unsigned)percentage;
- (unsigned)averageSpeed;
@property(nonatomic, retain) id	listener;
@end

