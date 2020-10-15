/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: ReceiveControl.h
 *	Module		: 受信メッセージウィンドウコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "MessageCenter.h"
#import "AttachmentClient.h"

@class RecvMessage;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface ReceiveControl : NSObject <AttachmentClientListener>
@property(nonatomic, strong) IBOutlet NSWindow*                window;                        // ウィンドウ
@property(nonatomic, strong) IBOutlet NSBox*                    infoBox;                    // ヘッダ部BOX
@property(nonatomic, strong) IBOutlet NSTextField*            userNameLabel;                // 送信元ユーザ名ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            dateLabel;                    // 受信日時ラベル
@property(nonatomic, strong) IBOutlet NSButton*                altLogButton;                // 重要ログボタン
@property(nonatomic, strong) IBOutlet NSButton*                quotCheck;                    // 引用チェックボックス
@property(nonatomic, strong) IBOutlet NSButton*                replyButton;                // 返信ボタン
@property(nonatomic, strong) IBOutlet NSButton*                sealButton;                    // 封書ボタン（メッセージ部のカバー）
@property(nonatomic, strong) IBOutlet NSTextView*            messageArea;                // メッセージ部
@property(nonatomic, strong) IBOutlet NSButton*                attachButton;                // 添付ボタン
@property(nonatomic, strong) IBOutlet NSDrawer*                attachDrawer;                // 添付ファイルDrawer
@property(nonatomic, strong) IBOutlet NSTableView*            attachTable;                // 添付ファイル一覧
@property(nonatomic, strong) IBOutlet NSButton*                attachSaveButton;            // 添付保存ボタン
@property(nonatomic, strong) IBOutlet NSPanel*                pwdSheet;                    // パスワード入力パネル（シート）
@property(nonatomic, strong) IBOutlet NSTextField*            pwdSheetErrorLabel;            // パスワード入力パネルエラーラベル
@property(nonatomic, strong) IBOutlet NSSecureTextField*        pwdSheetField;                // パスワード入力パネルテキストフィールド
@property(nonatomic, strong) IBOutlet NSPanel*                attachSheet;                // ダウンロードシート
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetTitleLabel;        // ダウンロードシートタイトルラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetSpeedLabel;        // ダウンロードシート転送速度ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetFileNameLabel;    // ダウンロードシートファイル名ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetPercentageLabel;    // ダウンロードシート％ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetFileNumLabel;    // ダウンロードシートファイル数ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetDirNumLabel;        // ダウンロードシートフォルダ数ラベル
@property(nonatomic, strong) IBOutlet NSTextField*            attachSheetSizeLabel;        // ダウンロードシートサイズラベル
@property(nonatomic, strong) IBOutlet NSProgressIndicator*    attachSheetProgress;        // ダウンロードシートプログレスバー
@property(nonatomic, strong) IBOutlet NSButton*                attachSheetCancelButton;    // ダウンロードシートキャンセルボタン
@property(nonatomic, strong)  RecvMessage*                    recvMsg;                    // 受信メッセージ
@property(nonatomic, readwrite) BOOL                            pleaseCloseMe;                // 閉じる確認済みか？
@property(nonatomic, strong) AttachmentClient*                downloader;                    // ダウンロードオブジェクト
@property(nonatomic, strong) NSTimer*                        attachSheetRefreshTimer;    // ダウンロードシート更新タイマ
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshFileName;    // ダウンロードシード更新フラグ
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshPercentage;
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshTitle;
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshFileNum;
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshDirNum;
@property(nonatomic, readwrite) BOOL                            attachSheetRefreshSize;

// 初期化（ウィンドウは表示しない）
- (id)initWithRecvMessage:(RecvMessage*)msg;
// ウィンドウの表示
- (void)showWindow;
// ハンドラ
- (IBAction)buttonPressed:(id)sender;

- (IBAction)openSeal:(id)sender;
- (IBAction)replyMessage:(id)sender;
- (IBAction)writeAlternateLog:(id)sender;
- (IBAction)cancelPwdSheet:(id)sender;
- (IBAction)okPwdSheet:(id)sender;
// その他
- (IBAction)backWindowToFront:(id)sender;
- (NSWindow*)window;
- (void)setAttachHeader;

@end
