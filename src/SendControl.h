/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: SendControl.h
 *	Module		: 送信メッセージウィンドウコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class UserInfo;
@class RecvMessage;

/*============================================================================*
 * クラス定義
 *============================================================================*/

@interface SendControl : NSObject

@property(nonatomic, strong)IBOutlet NSDrawer*        attachDrawer;        // 添付ファイルDrawer
@property(nonatomic, strong)IBOutlet NSWindow*        window;                // 送信ウィンドウ
@property(nonatomic, strong)IBOutlet NSSplitView*    splitView;
@property(nonatomic, strong)IBOutlet NSView*        splitSubview1;
@property(nonatomic, strong)IBOutlet NSView*        splitSubview2;
@property(nonatomic, strong)IBOutlet NSSearchField*    searchField;        // ユーザ検索フィールド
@property(nonatomic, strong)IBOutlet NSMenu*        searchMenu;            // ユーザ検索メニュー
@property(nonatomic, strong)IBOutlet NSTableView*    userTable;            // ユーザ一覧
@property(nonatomic, strong)IBOutlet NSTextField*    userNumLabel;        // ユーザ数ラベル
@property(nonatomic, strong)IBOutlet NSButton*        refreshButton;        // 更新ボタン
@property(nonatomic, strong)IBOutlet NSButton*        passwordCheck;        // 鍵チェックボックス
@property(nonatomic, strong)IBOutlet NSButton*        sealCheck;            // 封書チェックボックス
@property(nonatomic, strong)IBOutlet NSTextView*    messageArea;        // メッセージ入力欄
@property(nonatomic, strong)IBOutlet NSButton*        sendButton;            // 送信ボタン
@property(nonatomic, strong)IBOutlet NSButton*        attachButton;        // 添付ファイルDrawerトグルボタン

@property(nonatomic, strong)IBOutlet NSTableView*    attachTable;        // 添付ファイル一覧
@property(nonatomic, strong)IBOutlet NSButton*        attachAddButton;    // 添付追加ボタン
@property(nonatomic, strong)IBOutlet NSButton*        attachDelButton;    // 添付削除ボタン
@property(nonatomic, strong)NSMutableArray*            attachments;        // 添付ファイル
@property(nonatomic, strong)NSMutableDictionary*    attachmentsDic;        // 添付ファイル辞書
@property(nonatomic, strong)RecvMessage*            receiveMessage;        // 返信元メッセージ
@property(nonatomic, strong)NSMutableArray*            users;                // ユーザリスト
@property(nonatomic, strong)NSPredicate*            userPredicate;        // ユーザ検索フィルタ
@property(nonatomic, strong)NSMutableArray*            selectedUsers;        // 選択ユーザリスト
@property(nonatomic, strong)NSLock*                    selectedUsersLock;    // 選択ユーザリストロック

// 初期化
- (id)initWithSendMessage:(NSString*)msg recvMessage:(RecvMessage*)recv;

// ハンドラ
- (IBAction)buttonPressed:(id)sender;
- (IBAction)checkboxChanged:(id)sender;

- (IBAction)searchUser:(id)sender;
- (IBAction)selectUser:(id)sender;
- (IBAction)updateUserSearch:(id)sender;
- (IBAction)searchMenuItemSelected:(id)sender;

- (IBAction)sendPressed:(id)sender;
- (IBAction)sendMessage:(id)sender;
- (IBAction)userListUserMenuItemSelected:(id)sender;
- (IBAction)userListGroupMenuItemSelected:(id)sender;
- (IBAction)userListHostMenuItemSelected:(id)sender;
- (IBAction)userListIPAddressMenuItemSelected:(id)sender;
- (IBAction)userListLogonMenuItemSelected:(id)sender;
- (IBAction)userListVersionMenuItemSelected:(id)sender;
- (void)userListChanged:(NSNotification*)aNotification;

// 添付ファイル
- (void)appendAttachmentByPath:(NSString*)path;

// その他
- (IBAction)updateUserList:(id)sender;
//- (NSWindow*)window;
- (void)setAttachHeader;

@end
