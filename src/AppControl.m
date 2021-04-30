/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: AppControl.m
 *	Module		: アプリケーションコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "AppControl.h"
#import "Config.h"
#import "MessageCenter.h"
#import "AttachmentServer.h"
#import "RecvMessage.h"
#import "ReceiveControl.h"
#import "SendControl.h"
#import "NoticeControl.h"
#import "WindowManager.h"
#import "LogConverter.h"
#import "LogConvertController.h"
#import "UserInfo.h"
#import "DebugLog.h"

#define ABSENCE_OFF_MENU_TAG	1000
#define ABSENCE_ITEM_MENU_TAG	2000

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation AppControl

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)init
{
	self = [super init];
	if (self) {
		NSBundle* bundle = [NSBundle mainBundle];
		self.receiveQueue			= [[NSMutableArray alloc] init];
		self.receiveQueueLock		= [[NSLock alloc] init];
		self.iconToggleTimer			= nil;
		self.iconNormal				= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"IPMsg" ofType:@"icns"]];
		self.iconNormalReverse		= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"IPMsgReverse" ofType:@"icns"]];
		self.iconAbsence				= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"IPMsgAbsence" ofType:@"icns"]];
		self.iconAbsenceReverse		= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"IPMsgAbsenceReverse" ofType:@"icns"]];
		self.lastDockDraggedDate		= nil;
		self.lastDockDraggedWindow	= nil;
		self.iconSmallNormal			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"menu_normal" ofType:@"png"]];
		self.iconSmallNormalReverse	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"menu_highlight" ofType:@"png"]];
		self.iconSmallAbsence		= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"menu_normal" ofType:@"png"]];
		self.iconSmallAbsenceReverse	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"menu_highlight" ofType:@"png"]];
		self.iconSmallAlaternate		= [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"menu_alternate" ofType:@"png"]];
	}

	return self;
}

// 解放
- (void)dealloc
{
    
    self.receiveQueue=nil;
    self.receiveQueueLock=nil;
    self.iconToggleTimer=nil;
    self.iconNormal=nil;
    self.iconNormalReverse=nil;
    self.iconAbsence=nil;
    self.iconAbsenceReverse=nil;
//	[receiveQueue release];
//	[receiveQueueLock release];
//	[iconToggleTimer release];
//	[iconNormal release];
//	[iconNormalReverse release];
//	[iconAbsence release];
//	[iconAbsenceReverse release];
//	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * メッセージ送受信／ウィンドウ関連
 *----------------------------------------------------------------------------*/

// 新規メッセージウィンドウ表示処理
- (IBAction)newMessage:(id)sender {
	if (![NSApp isActive]) {
		self.activatedFlag = -1;		// アクティベートで新規ウィンドウが開いてしまうのを抑止
		[NSApp activateIgnoringOtherApps:YES];
	}
    
    self.lastDockDraggedWindow = [[SendControl alloc] initWithSendMessage:nil recvMessage:nil];
}

// メッセージ受信時処理
- (void)receiveMessage:(RecvMessage*)msg {
	Config*			config	= [Config sharedConfig];
	ReceiveControl*	recv;
    
  //  msg.fromUser.ipAddress
    
    if([config matchRefuseCondition:msg.fromUser])
    {
        return;
    }
    
	// 表示中のウィンドウがある場合無視する
	if ([[WindowManager sharedManager] receiveWindowForKey:msg]) {
		WRN(@"already visible message.(%@)", msg);
		return;
	}
	// 受信音再生
	[config.receiveSound play];
	// 受信ウィンドウ生成（まだ表示しない）
	recv = [[ReceiveControl alloc] initWithRecvMessage:msg];
	if (config.nonPopup) {
		if ((config.nonPopupWhenAbsence && config.inAbsence) ||
			(!config.nonPopupWhenAbsence)) {
			// ノンポップアップの場合受信キューに追加
			[self.receiveQueueLock lock];
			[self.receiveQueue addObject:recv];
			[self.receiveQueueLock unlock];
			switch (config.iconBoundModeInNonPopup) {
			case IPMSG_BOUND_ONECE:
				[NSApp requestUserAttention:NSInformationalRequest];
				break;
			case IPMSG_BOUND_REPEAT:
				[NSApp requestUserAttention:NSCriticalRequest];
				break;
			case IPMSG_BOUND_NONE:
			default:
				break;
			}
			if (!self.iconToggleTimer) {
				// アイコントグル開始
                self.iconToggleState	= YES;
                self.iconToggleTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
																   target:self
																 selector:@selector(toggleIcon:)
																 userInfo:nil
																  repeats:YES];
			}
			return;
		}
	}
	if (![NSApp isActive]) {
		[NSApp activateIgnoringOtherApps:YES];
	}
	[recv showWindow];
}

// すべてのウィンドウを閉じる
- (IBAction)closeAllWindows:(id)sender {
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([win isVisible]) {
			[win performClose:self];
		}
	}
}

// すべての通知ダイアログを閉じる
- (IBAction)closeAllDialogs:(id)sender {
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([[win delegate] isKindOfClass:[NoticeControl class]]) {
			[win performClose:self];
		}
	}
}

/*----------------------------------------------------------------------------*
 * 不在メニュー関連
 *----------------------------------------------------------------------------*/

- (NSMenuItem*)createAbsenceMenuItemAtIndex:(NSUInteger)index state:(BOOL)state {
	NSMenuItem* item = [[NSMenuItem alloc] init];
	[item setTitle:[[Config sharedConfig] absenceTitleAtIndex:index]];
	[item setEnabled:YES];
	[item setState:state];
	[item setTarget:self];
	[item setAction:@selector(absenceMenuChanged:)];
	[item setTag:ABSENCE_ITEM_MENU_TAG + index];
	return item;
}

// 不在メニュー作成
- (void)buildAbsenceMenu {
	Config*		config	= [Config sharedConfig];
	NSUInteger			num		= [config numberOfAbsences];
	NSInteger	index	= config.absenceIndex;
	NSUInteger			i;

	// 不在モード解除とその下のセパレータ以外を一旦削除
	for (i = [_absenceMenu numberOfItems] - 1; i > 1 ; i--) {
		[_absenceMenu removeItemAtIndex:i];
	}
	for (i = [_absenceMenuForDock numberOfItems] - 1; i > 1 ; i--) {
		[_absenceMenuForDock removeItemAtIndex:i];
	}
	for (i = [_absenceMenuForStatusBar numberOfItems] - 1; i > 1 ; i--) {
		[_absenceMenuForStatusBar removeItemAtIndex:i];
	}
	if (num > 0) {
		for (i = 0; i < num; i++) {
			[_absenceMenu addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
			[_absenceMenuForDock addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
			[_absenceMenuForStatusBar addItem:[self createAbsenceMenuItemAtIndex:i state:(i == index)]];
		}
	}
	[_absenceOffMenuItem setState:(index == -1)];
	[_absenceOffMenuItemForDock setState:(index == -1)];
	[_absenceOffMenuItemForStatusBar setState:(index == -1)];
	[_absenceMenu update];
	[_absenceMenuForDock update];
	[_absenceMenuForStatusBar update];
}

// 不在メニュー選択ハンドラ
- (IBAction)absenceMenuChanged:(id)sender {
	Config*		config	= [Config sharedConfig];
	NSInteger	oldIdx	= config.absenceIndex;
	NSInteger			newIdx;

	if ([sender tag] == ABSENCE_OFF_MENU_TAG) {
		newIdx = -2;
	} else {
		newIdx = [sender tag] - ABSENCE_ITEM_MENU_TAG;
	}

	// 現在選択されている不在メニューのチェックを消す
	if (oldIdx == -1) {
		oldIdx = -2;
	}
	[[_absenceMenu				itemAtIndex:oldIdx + 2] setState:NSOffState];
	[[_absenceMenuForDock		itemAtIndex:oldIdx + 2] setState:NSOffState];
	[[_absenceMenuForStatusBar	itemAtIndex:oldIdx + 2] setState:NSOffState];

	// 選択された項目にチェックを入れる
	[[_absenceMenu				itemAtIndex:newIdx + 2] setState:NSOnState];
	[[_absenceMenuForDock		itemAtIndex:newIdx + 2] setState:NSOnState];
	[[_absenceMenuForStatusBar	itemAtIndex:newIdx + 2] setState:NSOnState];

	// 選択された項目によってアイコンを変更する
	if (newIdx < 0) {
		[NSApp setApplicationIconImage:_iconNormal];
		[_statusBarItem setImage:_iconSmallNormal];
	} else {
		[NSApp setApplicationIconImage:_iconAbsence];
		[_statusBarItem setImage:_iconSmallAbsence];
	}

	[sender setState:NSOnState];

	config.absenceIndex = newIdx;
	[[MessageCenter sharedCenter] broadcastAbsence];
}

// 不在解除
- (void)setAbsenceOff {
	[self absenceMenuChanged:_absenceOffMenuItem];
}

/*----------------------------------------------------------------------------*
 * ステータスバー関連
 *----------------------------------------------------------------------------*/

- (void)initStatusBar {
	if (_statusBarItem == nil) {
		// ステータスバーアイテムの初期化
		self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		[_statusBarItem setTitle:@""];
		[_statusBarItem setImage:_iconSmallNormal];
		[_statusBarItem setAlternateImage:_iconSmallAlaternate];
		[_statusBarItem setMenu:_statusBarMenu];
		[_statusBarItem setHighlightMode:YES];
	}
}

- (void)removeStatusBar {
	if (_statusBarItem != nil) {
		// ステータスバーアイテムを破棄
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusBarItem];
		self.statusBarItem = nil;
	}
}

- (void)clickStatusBar:(id)sender{
    _activatedFlag = -1;		// アクティベートで新規ウィンドウが開いてしまうのを抑止
	[NSApp activateIgnoringOtherApps:YES];
	[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

// Webサイトに飛ぶ
- (IBAction)gotoHomePage:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"IPMsg.HomePage", nil)]];
}

// 謝辞の表示
- (IBAction)showAcknowledgement:(id)sender {
	NSString* path = [[NSBundle mainBundle] pathForResource:@"Acknowledgement" ofType:@"pdf"];
	[[NSWorkspace sharedWorkspace] openFile:path];
}

// Nibファイルロード完了時
- (void)awakeFromNib {
	Config* config = [Config sharedConfig];
	// メニュー設定
	[_sendWindowListUserMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoUserNamePropertyIdentifier]];
	[_sendWindowListGroupMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoGroupNamePropertyIdentifier]];
	[_sendWindowListHostMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoHostNamePropertyIdentifier]];
	[_sendWindowListIPAddressMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoIPAddressPropertyIdentifier]];
	[_sendWindowListLogonMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoLogOnNamePropertyIdentifier]];
	[_sendWindowListVersionMenuItem setState:![config sendWindowUserListColumnHidden:kIPMsgUserInfoVersionPropertyIdentifer]];
	[self buildAbsenceMenu];

	// ステータスバー
	if(config.useStatusBar){
		[self initStatusBar];
	}
}

// アプリ起動完了時処理
- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	TRC(@"Enter");

	// 画面位置計算時の乱数初期化
	srand((unsigned)time(NULL));

	// フラグ初期化
    _activatedFlag = -1;

	// ログファイルのUTF-8チェック
	TRC(@"Start log check");
	Config* config = [Config sharedConfig];
	if (config.standardLogEnabled) {
		TRC(@"Need StdLog check");
		[self checkLogConversion:YES path:config.standardLogFile];
	}
	if (config.alternateLogEnabled) {
		TRC(@"Need AltLog check");
		[self checkLogConversion:NO path:config.alternateLogFile];
	}
	TRC(@"Finish log check");

	// ENTRYパケットのブロードキャスト
	TRC(@"Broadcast entry");
	[[MessageCenter sharedCenter] broadcastEntry];

	// 添付ファイルサーバの起動
	TRC(@"Start attachment server");
	[AttachmentServer sharedServer];

	TRC(@"Complete");
}

// ログ参照クリック時
- (void) openLog:(id)sender{
	Config*	config	= [Config sharedConfig];
	// ログファイルのフルパスを取得する
	NSString *filePath = [config.standardLogFile stringByExpandingTildeInPath];
	// デフォルトのアプリでログを開く
	[[NSWorkspace sharedWorkspace] openFile : filePath];
}

// アプリ終了前確認
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
	// 表示されている受信ウィンドウがあれば終了確認
	NSEnumerator*	e = [[NSApp orderedWindows] objectEnumerator];
	NSWindow*		win;
	while ((win = (NSWindow*)[e nextObject])) {
		if ([win isVisible] && [[win delegate] isKindOfClass:[ReceiveControl class]]) {
			NSInteger ret = NSRunCriticalAlertPanel(
								NSLocalizedString(@"ShutDown.Confirm1.Title", nil),
								NSLocalizedString(@"ShutDown.Confirm1.Msg", nil),
								NSLocalizedString(@"ShutDown.Confirm1.OK", nil),
								NSLocalizedString(@"ShutDown.Confirm1.Cancel", nil),
								nil);
			if (ret == NSAlertAlternateReturn) {
				[win makeKeyAndOrderFront:self];
				// 終了キャンセル
				return NSTerminateCancel;
			}
			break;
		}
	}
	// ノンポップアップの未読メッセージがあれば終了確認
	[_receiveQueueLock lock];
	if ([_receiveQueue count] > 0) {
		NSInteger ret = NSRunCriticalAlertPanel(
								NSLocalizedString(@"ShutDown.Confirm2.Title", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Msg", nil),
								NSLocalizedString(@"ShutDown.Confirm2.OK", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Other", nil),
								NSLocalizedString(@"ShutDown.Confirm2.Cancel", nil));
		if (ret == NSAlertOtherReturn) {
			[_receiveQueueLock unlock];
			// 終了キャンセル
			return NSTerminateCancel;
		} else if (ret == NSAlertAlternateReturn) {
			[_receiveQueueLock unlock];
			[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
			// 終了キャンセル
			return NSTerminateCancel;
		}
	}
	[_receiveQueueLock unlock];
	// 終了
	return NSTerminateNow;
}

// アプリ終了時処理
- (void)applicationWillTerminate:(NSNotification*)aNotification {
	// EXITパケットのブロードキャスト
	[[MessageCenter sharedCenter] broadcastExit];
	// 添付ファイルサーバの終了
	[[AttachmentServer sharedServer] shutdownServer];

	// ステータスバー消去
	if ([Config sharedConfig].useStatusBar && (_statusBarItem != nil)) {
		// [self removeStatusBar]を呼ぶと落ちる（なぜ？）
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusBarItem];
	}

	// 初期設定の保存
	[[Config sharedConfig] save];

}

// アプリアクティベート
- (void)applicationDidBecomeActive:(NSNotification*)aNotification {
	// 初回だけは無視（起動時のアクティベートがあるので）
    _activatedFlag = (_activatedFlag == -1) ? NO : YES;
}

// Dockファイルドロップ時
- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)fileName {
	DBG(@"drop file=%@", fileName);
	if (_lastDockDraggedDate && _lastDockDraggedWindow) {
		if ([_lastDockDraggedDate timeIntervalSinceNow] > -0.5) {
			[_lastDockDraggedWindow appendAttachmentByPath:fileName];
		} else {
            self.lastDockDraggedDate		= nil;
            self.lastDockDraggedWindow	= nil;
		}
	}
	if (!_lastDockDraggedDate) {
		self.lastDockDraggedWindow = [[SendControl alloc] initWithSendMessage:nil recvMessage:nil];
		[_lastDockDraggedWindow appendAttachmentByPath:fileName];
		self.lastDockDraggedDate = [[NSDate alloc] init];
	}
	return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	if (item == _showNonPopupMenuItem) {
		if ([Config sharedConfig].nonPopup) {
			return ([_receiveQueue count] > 0);
		}
		return NO;
	}
	return YES;
}

- (IBAction)showNonPopupMessage:(id)sender {
	[self applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
}

// Dockクリック時
- (BOOL)applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)flag {
	int 		i;
	BOOL		b;
	BOOL		noWin = YES;
	Config*		config = [Config sharedConfig];
	NSArray*	wins;
	// ノンポップアップのキューにメッセージがあれば表示
	[_receiveQueueLock lock];
	b = ([_receiveQueue count] > 0);
	for (i = 0; i < [_receiveQueue count]; i++) {
		[[_receiveQueue objectAtIndex:i] showWindow];
	}
	[_receiveQueue removeAllObjects];
	// アイコントグルアニメーションストップ
	if (b && _iconToggleTimer) {
		[_iconToggleTimer invalidate];
		self.iconToggleTimer = nil;
		[NSApp setApplicationIconImage:((config.inAbsence) ? _iconAbsence : _iconNormal)];
		[_statusBarItem setImage:((config.inAbsence) ? _iconSmallAbsence : _iconSmallNormal)];
	}
	[_receiveQueueLock unlock];
	// 新規送信ウィンドウのオープン

//DBG(@"#window = %d", [[NSApp windows] count]);
	wins = [NSApp windows];
	for (i = 0; i < [wins count]; i++) {
		NSWindow* win = [wins objectAtIndex:i];
//		[win orderFront:self];
//		if ([[win delegate] isKindOfClass:[ReceiveControl class]] ||
//			[[win delegate] isKindOfClass:[SendControl class]]) {
		if ([win isVisible]) {
			noWin = NO;
			break;
		}
	}
	if (_activatedFlag != -1) {
		if ((noWin || !_activatedFlag) &&
			!b && config.openNewOnDockClick) {
			// ・クリック前からアクティブアプリだったか、または表示中のウィンドウが一個もない
			// ・環境設定で指定されている
			// ・ノンポップアップ受信でキューイングされた受信ウィンドウがない
			// のすべてを満たす場合、新規送信ウィンドウを開く
			[self newMessage:self];
		}
	}
    _activatedFlag = NO;
	return YES;
}

// アイコン点滅処理（タイマコールバック）
- (void)toggleIcon:(NSTimer*)timer {
	NSImage* img1;
	NSImage* img2;
    _iconToggleState = !_iconToggleState;


	if ([Config sharedConfig].inAbsence) {
		img1 = (_iconToggleState) ? _iconAbsence : _iconAbsenceReverse;
		img2 = (_iconToggleState) ? _iconSmallAbsence : _iconSmallAbsenceReverse;
	} else {
		img1 = (_iconToggleState) ? _iconNormal : _iconNormalReverse;
		img2 = (_iconToggleState) ? _iconSmallNormal : _iconSmallNormalReverse;
	}

	// ステータスバーアイコン
	if ([Config sharedConfig].useStatusBar) {
		if (_statusBarItem == nil) {
			[self initStatusBar];
		}
		[_statusBarItem setImage:img2];
	}
	// Dockアイコン
	[NSApp setApplicationIconImage:img1];
}

- (void)checkLogConversion:(BOOL)aStdLog path:(NSString*)aPath
{
	Config*			config __unused	= [Config sharedConfig];
	NSString*		name	= aStdLog ? @"StdLog" : @"AltLog";
	LogConverter*	converter;

	TRC(@"Start check %@ logfile", name);

	converter		= [LogConverter converter];
	converter.name	= name;
	converter.path	= [aPath stringByExpandingTildeInPath];

	if (![converter needConversion]) {
		TRC(@"%@ is up to date (UTF-8) -> end", name);
		return;
	}

	// ユーザへの変換確認
	WRN(@"%@ need to convert (SJIS->UTF-8) -> user confirm", name);
	NSString*	s		= [NSString stringWithFormat:@"Log.Conv.%@", name];
	NSString*	logName	= NSLocalizedString(s, nil);
	NSString*	title	= NSLocalizedString(@"Log.Conv.Title", nil);
	NSString*	message	= NSLocalizedString(@"Log.Conv.Message", nil);
	NSString*	ok		= NSLocalizedString(@"Log.Conv.OK", nil);
	NSString*	cancel	= NSLocalizedString(@"Log.Conv.Cancel", nil);

	NSAlert*	alert	= [[NSAlert alloc] init];
	[alert setMessageText:[NSString stringWithFormat:title, logName]];
	[alert setInformativeText:[NSString stringWithFormat:message, logName]];
	[alert addButtonWithTitle:ok];
	[alert addButtonWithTitle:cancel];
	[alert setAlertStyle:NSAlertStyleWarning];
	NSInteger ret = [alert runModal];
	if (ret == NSAlertFirstButtonReturn) {
		// OKを選んだら変換
		TRC(@"User confirmed %@ conversion", name);

		// 進捗ダイアログ作成
		LogConvertController* dialog = [[LogConvertController alloc] init];
		dialog.filePath	= converter.path;
		converter.delegate	= dialog;
		[dialog showWindow:self];

		// 変換処理
		TRC(@"LogConvert start(%@)", name);
		BOOL result = [converter convertToUTF8:[dialog window]];
		TRC(@"LogConvert result(%@,%s)", name, (result ? "YES" : "NO"));
		[dialog close];
		if (result == NO) {
			if ([converter.backupPath length] == 0) {
				// バックアップされていないようであればバックアップ
				[converter backup];
			}
			title	= NSLocalizedString(@"Log.ConvFail.Title", nil);
			message	= NSLocalizedString(@"Log.ConvFail.Message", nil);
			ok		= NSLocalizedString(@"Log.ConvFail.OK", nil);
			alert = [NSAlert alertWithMessageText:title
									defaultButton:ok 
								  alternateButton:nil
									  otherButton:nil
						informativeTextWithFormat:@"%@",message];
			[alert setAlertStyle:NSAlertStyleCritical];
			[alert runModal];
		}
	} else if (ret == NSAlertSecondButtonReturn) {
		// キャンセルを選んだ場合はログファイルをバックアップ
		ERR(@"User denied %@ conversion. -> backup", name);
		[converter backup];
	}

	if ([converter.backupPath length] > 0) {
		title	= NSLocalizedString(@"Log.Backup.Title", nil);
		ok		= NSLocalizedString(@"Log.Backup.OK", nil);
		alert = [NSAlert alertWithMessageText:title
								defaultButton:ok
							  alternateButton:nil
								  otherButton:nil
					informativeTextWithFormat:@"%@",converter.backupPath];
		[alert setAlertStyle:NSAlertStyleInformational];
		[alert runModal];
	}
}

- (void)applicationWillUnhide:(NSNotification *)notification {
    
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    
}

- (void)applicationWillBecomeActive:(NSNotification *)notification {
    
}

- (void)application:(NSApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity {
    
}
@end
