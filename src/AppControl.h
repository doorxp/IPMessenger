/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: AppControl.h
 *	Module		: アプリケーションコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class RecvMessage;
@class SendControl;

#ifndef MAC_OS_X_VERSION_10_6
#define MAC_OS_X_VERSION_10_6	1060
#endif

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface AppControl : NSObject
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
<NSApplicationDelegate>
#endif

@property(nonatomic, strong) IBOutlet NSMenu*        absenceMenu;                    // 不在メニュー
@property(nonatomic, strong) IBOutlet NSMenuItem*    absenceOffMenuItem;                // 不在解除メニュー項目
@property(nonatomic, strong) IBOutlet NSMenu*        absenceMenuForDock;                // Dock用不在メニュー
@property(nonatomic, strong) IBOutlet NSMenuItem*    absenceOffMenuItemForDock;        // Dock用不在解除メニュー項目
@property(nonatomic, strong) IBOutlet NSMenu*        absenceMenuForStatusBar;        // ステータスバー用不在メニュー
@property(nonatomic, strong) IBOutlet NSMenuItem*    absenceOffMenuItemForStatusBar;    // ステータスバー用不在解除メニュー項目

@property(nonatomic, strong) IBOutlet NSMenuItem*    showNonPopupMenuItem;            // ノンポップアップ表示メニュー項目

@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListUserMenuItem;        // 送信ウィンドウユーザ一覧ユーザメニュー項目
@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListGroupMenuItem;    // 送信ウィンドウユーザ一覧グループメニュー項目
@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListHostMenuItem;        // 送信ウィンドウユーザ一覧ホストメニュー項目
@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListIPAddressMenuItem;// 送信ウィンドウユーザ一覧IPアドレスメニュー項目
@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListLogonMenuItem;    // 送信ウィンドウユーザ一覧ログオンメニュー項目
@property(nonatomic, strong) IBOutlet NSMenuItem*    sendWindowListVersionMenuItem;    // 送信ウィンドウユーザ一覧バージョンメニュー項目

@property(nonatomic, strong) IBOutlet NSMenu*        statusBarMenu;                    // ステータスバー用のメニュー
@property(nonatomic, strong) NSStatusItem*            statusBarItem;                    // ステータスアイテムのインスタンス

@property(nonatomic, readwrite) int                    activatedFlag;                    // アプリケーションアクティベートフラグ

@property(nonatomic, strong) NSMutableArray*            receiveQueue;                    // 受信メッセージキュー
@property(nonatomic, strong) NSLock*                    receiveQueueLock;                // 受信メッセージキュー排他ロック

@property(nonatomic, strong) NSTimer*                iconToggleTimer;                // アイコントグル用タイマー
@property(nonatomic, readwrite) BOOL                    iconToggleState;                // アイコントグル状態（YES:通常/NO:リバース)

@property(nonatomic, strong) NSImage*                iconNormal;                        // 通常時アプリアイコン
@property(nonatomic, strong) NSImage*                iconNormalReverse;                // 通常時アプリアイコン（反転）
@property(nonatomic, strong) NSImage*                iconAbsence;                    // 不在時アプリアイコン
@property(nonatomic, strong) NSImage*                iconAbsenceReverse;                // 不在時アプリアイコン（反転）
@property(nonatomic, strong) NSImage*                 iconSmallNormal;                // 通常時アプリスモールアイコン
@property(nonatomic, strong) NSImage*                 iconSmallNormalReverse;            // 通常時アプリスモールアイコン（反転）
@property(nonatomic, strong) NSImage*                iconSmallAbsence;                // 不在時アプリスモールアイコン
@property(nonatomic, strong) NSImage*                iconSmallAbsenceReverse;        // 不在時アプリスモールアイコン（反転）
@property(nonatomic, strong) NSImage*                iconSmallAlaternate;            // 選択時アプリスモールアイコン

@property(nonatomic, strong) NSDate*                    lastDockDraggedDate;            // 前回Dockドラッグ受付時刻
@property(nonatomic, strong) SendControl*            lastDockDraggedWindow;            // 前回Dockドラッグ時生成ウィンドウ

// メッセージ送受信／ウィンドウ関連処理
- (IBAction)newMessage:(id)sender;
- (void)receiveMessage:(RecvMessage*)msg;
- (IBAction)closeAllWindows:(id)sender;
- (IBAction)closeAllDialogs:(id)sender;
- (IBAction)showNonPopupMessage:(id)sender;

// 不在関連処理
- (IBAction)absenceMenuChanged:(id)sender;
- (void)buildAbsenceMenu;
- (void)setAbsenceOff;

// ステータスバー関連
- (IBAction)clickStatusBar:(id)sender;
- (void)initStatusBar;
- (void)removeStatusBar;

// その他
- (IBAction)gotoHomePage:(id)sender;
- (IBAction)showAcknowledgement:(id)sender;
- (IBAction)openLog:(id)sender;

- (void)checkLogConversion:(BOOL)aStdLog path:(NSString*)aPath;

@end
