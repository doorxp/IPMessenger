/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: SendControl.m
 *	Module		: 送信メッセージウィンドウコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "SendControl.h"
#import "AppControl.h"
#import "Config.h"
#import "LogManager.h"
#import "UserInfo.h"
#import "UserManager.h"
#import "RecvMessage.h"
#import "SendMessage.h"
#import "Attachment.h"
#import "AttachmentFile.h"
#import "AttachmentServer.h"
#import "MessageCenter.h"
#import "WindowManager.h"
#import "ReceiveControl.h"
#import "DebugLog.h"


#define _SEARCH_MENUITEM_TAG_ALPHA		(0)
#define _SEARCH_MENUITEM_TAG_PINYING	(1)
#define _SEARCH_MENUITEM_TAG_USER		(2)
#define _SEARCH_MENUITEM_TAG_GROUP		(3)
#define _SEARCH_MENUITEM_TAG_HOST		(4)
#define _SEARCH_MENUITEM_TAG_LOGON		(5)

static NSImage*				attachmentImage		= nil;
static NSDate*				lastTimeOfEntrySent	= nil;
static NSMutableDictionary*	userListColumns		= nil;
static NSRecursiveLock*		userListColsLock	= nil;

@interface SendControl()<NSSplitViewDelegate>
- (void)updateSearchFieldPlaceholder;
@end


/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation SendControl

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithSendMessage:(NSString*)msg recvMessage:(RecvMessage*)recv {
	self = [super init];

	if (userListColumns == nil) {
		userListColumns		= [[NSMutableDictionary alloc] init];
	}
	if (userListColsLock == nil) {
		userListColsLock	= [[NSRecursiveLock alloc] init];
	}
	self.users				= [[[UserManager sharedManager] users] mutableCopy];
    self.selectedUsers		= [[NSMutableArray alloc] init];
    self.selectedUsersLock	= [[NSLock alloc] init];
    self.receiveMessage		= recv;
    self.attachments			= [[NSMutableArray alloc] init];
    self.attachmentsDic		= [[NSMutableDictionary alloc] init];

	// Nibファイルロード
	if (![NSBundle.mainBundle loadNibNamed:@"SendWindow" owner:self topLevelObjects:nil]) {
		return nil;
	}

	// 引用メッセージの設定
	if (msg) {
		if ([msg length] > 0) {
			// 引用文字列行末の改行がなければ追加
            NSRange r = NSMakeRange(self.messageArea.string.length, 0);
			if ([msg characterAtIndex:[msg length] - 1] != '\n') {
				[self.messageArea insertText:[msg stringByAppendingString:@"\n"] replacementRange:r];
			} else {
				[self.messageArea insertText:msg replacementRange:r];
			}
		}
	}

	// ユーザ数ラベルの設定
	[self userListChanged:nil];

	// 添付機能ON/OFF
	[self.attachButton setEnabled:[AttachmentServer isAvailable]];

	// 添付ヘッダカラム名設定
	[self setAttachHeader];

	// 送信先ユーザの選択
	if (self.receiveMessage) {
		NSUInteger index = [self.users indexOfObject:[self.receiveMessage fromUser]];
		if (index != NSNotFound) {
			[self.userTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
				   byExtendingSelection:[Config sharedConfig].allowSendingToMultiUser];
			[self.userTable scrollRowToVisible:index];
		}
	}

	// ウィンドウマネージャへの登録
	if (self.receiveMessage) {
		[[WindowManager sharedManager] setReplyWindow:self forKey:self.receiveMessage];
	}

	// ユーザリスト変更の通知登録
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(userListChanged:)
			   name:NOTICE_USER_LIST_CHANGED
			 object:nil];

	// ウィンドウ表示
	[self.window makeKeyAndOrderFront:self];
	// ファーストレスポンダ設定
	[self.window makeFirstResponder:self.messageArea];

    self.splitView.translatesAutoresizingMaskIntoConstraints = false;
    
	return self;
}

// 解放
- (void)dealloc {
    self.users = nil;
    self.userPredicate = nil;
    self.selectedUsers = nil;
    self.selectedUsersLock = nil;
    self.receiveMessage = nil;
    self.attachments = nil;
    self.attachmentsDic = nil;
    self.window = nil;
    
//	[users release];
//	[userPredicate release];
//	[selectedUsers release];
//	[selectedUsersLock release];
//	[receiveMessage release];
//	[attachments release];
//	[attachmentsDic release];
//	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * ボタン／チェックボックス操作
 *----------------------------------------------------------------------------*/

- (IBAction)buttonPressed:(id)sender {
	// 更新ボタン
	if (sender == self.refreshButton) {
		[self updateUserList:nil];
	}
	// 添付追加ボタン
	else if (sender == self.attachAddButton) {
		NSOpenPanel* op = [NSOpenPanel openPanel];;
		// 添付追加／削除ボタンを押せなくする
		[self.attachAddButton setEnabled:NO];
		[self.attachDelButton setEnabled:NO];
		// シート表示
		[op setCanChooseDirectories:YES];
        [op beginSheetModalForWindow:self.window
                   completionHandler:^(NSInteger result)
         {
            [self sheetDidEnd:op
                   returnCode:result
                  contextInfo:(__bridge void *)(sender)];
        }];
//		[op beginSheetForDirectory:nil
//							  file:nil
//					modalForWindow:window
//					 modalDelegate:self
//					didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
//					   contextInfo:sender];
	}
	// 添付削除ボタン
	else if (sender == self.attachDelButton) {
		NSInteger selIdx = [self.attachTable selectedRow];
		if (selIdx >= 0) {
			Attachment* info = [self.attachments objectAtIndex:selIdx];
			[self.attachmentsDic removeObjectForKey:[info file].path];
			[self.attachments removeObjectAtIndex:selIdx];
			[self.attachTable reloadData];
			[self setAttachHeader];
		}
	} else {
		ERR(@"unknown button pressed(%@)", sender);
	}
}

- (IBAction)checkboxChanged:(id)sender {
	// 封書チェックボックスクリック
	if (sender == self.sealCheck) {
		BOOL state = [self.sealCheck state];
		// 封書チェックがチェックされているときだけ鍵チェックが利用可能
		[self.passwordCheck setEnabled:state];
		// 封書チェックのチェックがはずされた場合は鍵のチェックも外す
		if (!state) {
			[self.passwordCheck setState:NSOffState];
		}
	}
	// 鍵チェックボックス
	else if (sender == self.passwordCheck) {
		// nop
	} else {
		ERR(@"Unknown button pressed(%@)", sender);
	}
}

// シート終了処理
- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)code contextInfo:(void*)info {
    if (info == (__bridge void *)(self.sendButton)) {
		[sheet orderOut:self];
		if (code == NSModalResponseOK || code == NSAlertFirstButtonReturn) {
			// 不在モードを解除してメッセージを送信
			[(id)[NSApp delegate] setAbsenceOff];
			[self sendMessage:self];
		}
    } else if (info == (__bridge void *)(self.attachAddButton)) {
		if (code == NSModalResponseOK || code == NSAlertFirstButtonReturn) {
			NSOpenPanel*	op = (NSOpenPanel*)sheet;
			//NSString*		fn = [op filename];
            NSString*		fn = [[op URL] relativePath];
			[self appendAttachmentByPath:fn];
		}
		[sheet orderOut:self];
		[self.attachAddButton setEnabled:YES];
		[self.attachDelButton setEnabled:([self.attachTable numberOfSelectedRows] > 0)];
	}
}

// 送信メニュー選択時処理
- (IBAction)sendMessage:(id)sender {
	[self sendPressed:sender];
}

// 送信ボタン押下／送信メニュー選択時処理
- (IBAction)sendPressed:(id)sender {
	SendMessage*	info;
	NSMutableArray*	to;
	NSString*		msg;
	BOOL			sealed;
	BOOL			locked;
	NSIndexSet*		userSet;
	Config*			config = [Config sharedConfig];
	NSUInteger		index;

	if (config.inAbsence) {
		// 不在モードを解除して送信するか確認
//		NSBeginAlertSheet(	NSLocalizedString(@"SendDlg.AbsenceOff.Title", nil),
//							NSLocalizedString(@"SendDlg.AbsenceOff.OK", nil),
//							NSLocalizedString(@"SendDlg.AbsenceOff.Cancel", nil),
//							nil,
//                          self.window,
//							self,
//							@selector(sheetDidEnd:returnCode:contextInfo:),
//							nil,
//                          (__bridge void *)(sender),
//							NSLocalizedString(@"SendDlg.AbsenceOff.Msg", nil),
//								[config absenceTitleAtIndex:config.absenceIndex]);
        
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"SendDlg.AbsenceOff.Title", nil);
        alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"SendDlg.AbsenceOff.Msg", nil), [config absenceTitleAtIndex:config.absenceIndex]];
        
        [alert addButtonWithTitle:NSLocalizedString(@"SendDlg.AbsenceOff.OK", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"SendDlg.AbsenceOff.Cancel", nil)];
        
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [self sheetDidEnd:self.window returnCode:returnCode contextInfo:(__bridge void *)(sender)];
        }];
        
		return;
	}

	// 送信情報整理
	msg		= [self.messageArea string];
	sealed	= [self.sealCheck state];
	locked	= [self.passwordCheck state];
	to		= [[NSMutableArray alloc] init] ;
	userSet	= [self.userTable selectedRowIndexes];
	index	= [userSet firstIndex];
	while (index != NSNotFound) {
		[to addObject:[self.users objectAtIndex:index]];
		index = [userSet indexGreaterThanIndex:index];
	}
	// 送信情報構築
	info = [SendMessage messageWithMessage:msg
							   attachments:self.attachments
									  seal:sealed
									  lock:locked];
	// メッセージ送信
	[[MessageCenter sharedCenter] sendMessage:info to:to];
	// ログ出力
	[[LogManager standardLog] writeSendLog:info to:to];
	// 受信ウィンドウ消去（初期設定かつ返信の場合）
	if (config.hideReceiveWindowOnReply) {
		ReceiveControl* receiveWin = [[WindowManager sharedManager] receiveWindowForKey:self.receiveMessage];
		if (receiveWin) {
			[[receiveWin window] performClose:self];
		}
	}
	// 自ウィンドウを消去
	[self.window performClose:self];
}

// 選択ユーザ一覧の更新
- (void)updateSelectedUsers {
	if ([self.selectedUsersLock tryLock]) {
		NSIndexSet*	select	= [self.userTable selectedRowIndexes];
		NSUInteger	index;
		[self.selectedUsers removeAllObjects];
		index = [select firstIndex];
		while (index != NSNotFound) {
			[self.selectedUsers addObject:[self.users objectAtIndex:index]];
			index = [select indexGreaterThanIndex:index];
		}
		[self.selectedUsersLock unlock];
	}
}

// SplitViewのリサイズ制限
- (CGFloat)splitView				:(NSSplitView*)sender
		  constrainMinCoordinate:(CGFloat)proposedMin
					 ofSubviewAt:(NSInteger)offset {
//	if (offset == 0) {
//		// 上側ペインの最小サイズを制限
//		return 90;
//	}
//	return proposedMin;
    return 60;
}

// SplitViewのリサイズ制限
- (CGFloat)splitView				:(NSSplitView*)sender
		  constrainMaxCoordinate:(CGFloat)proposedMax
					 ofSubviewAt:(NSInteger)offset {
    float m = [sender frame].size.height - [sender dividerThickness] - 60;
    return  m;
}

// SplitViewのリサイズ処理
- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    [sender adjustSubviews];
//	NSSize	newSize	= [sender frame].size;
//	float	divider	= [sender dividerThickness];
//	NSRect	frame1	= [self.splitSubview1 frame];
//	NSRect	frame2	= [self.splitSubview2 frame];
//
//	frame1.size.width	= newSize.width;
//	if (frame1.size.height > newSize.height - divider) {
//		// ヘッダ部の高さは変更しないがSplitViewの大きさ内には納める
//		frame1.size.height = newSize.height - divider;
//	}
//	frame2.origin.x		= 0;
//	frame2.size.width	= newSize.width + 2;
//	frame2.size.height	= newSize.height - frame1.size.height - divider;
//	[self.splitSubview1 setFrame:frame1];
//	[self.splitSubview2 setFrame:frame2];
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex {
    return  proposedEffectiveRect;
}

/*----------------------------------------------------------------------------*
 * NSTableDataSourceメソッド
 *----------------------------------------------------------------------------*/

- (NSInteger)numberOfRowsInTableView:(NSTableView*)aTableView {
	if (aTableView == self.userTable) {
		return [self.users count];
	} else if (aTableView == self.attachTable) {
		return [self.attachments count];
	} else {
		ERR(@"Unknown TableView(%@)", aTableView);
	}
	return 0;
}

- (id)tableView:(NSTableView*)aTableView
		objectValueForTableColumn:(NSTableColumn*)aTableColumn
		row:(int)rowIndex {
	if (aTableView == self.userTable) {
		UserInfo* info = [self.users objectAtIndex:rowIndex];
		NSString* iden = [aTableColumn identifier];
		if ([iden isEqualToString:kIPMsgUserInfoUserNamePropertyIdentifier]) {
			return info.userName;
		} else if ([iden isEqualToString:kIPMsgUserInfoGroupNamePropertyIdentifier]) {
			return info.groupName;
		} else if ([iden isEqualToString:kIPMsgUserInfoHostNamePropertyIdentifier]) {
			return info.hostName;
		} else if ([iden isEqualToString:kIPMsgUserInfoIPAddressPropertyIdentifier]) {
			return info.ipAddress;
		} else if ([iden isEqualToString:kIPMsgUserInfoLogOnNamePropertyIdentifier]) {
			return info.logOnName;
		} else if ([iden isEqualToString:kIPMsgUserInfoVersionPropertyIdentifer]) {
			return info.version;
		}else if ([iden isEqualToString:kIPMsgUserInfoUserAlphaPropertyIdentifier]){
            return info.userAlpha;
        }
        else {
			ERR(@"Unknown TableColumn(%@)", iden);
		}
	} else if (aTableView == self.attachTable) {
		Attachment*					attach;
		NSMutableAttributedString*	cellValue;
		NSFileWrapper*				fileWrapper;
		NSTextAttachment*			textAttachment;
		attach = [self.attachments objectAtIndex:rowIndex];
		if (!attach) {
			ERR(@"no attachments(row=%d)", rowIndex);
			return nil;
		}
        
        NSData *data = [NSData data];
		fileWrapper		= [[NSFileWrapper alloc] initRegularFileWithContents:data];
		textAttachment	= [[NSTextAttachment alloc] initWithFileWrapper:fileWrapper];
		[(NSCell*)[textAttachment attachmentCell] setImage:attach.icon];
		cellValue		= [[NSMutableAttributedString alloc] initWithString:[[attach file] name]];
		[cellValue replaceCharactersInRange:NSMakeRange(0, 0)
					   withAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]];
		[cellValue addAttribute:NSBaselineOffsetAttributeName
						  value:[NSNumber numberWithFloat:-3.0]
						  range:NSMakeRange(0, 1)];
		return cellValue;
	} else {
		ERR(@"Unknown TableView(%@)", aTableView);
	}
	return nil;
}

/*----------------------------------------------------------------------------*
 * NSTableViewDelegateメソッド
 *----------------------------------------------------------------------------*/

// ユーザリストの選択変更
- (void)tableViewSelectionDidChange:(NSNotification*)aNotification {
	NSTableView* table = [aNotification object];
	if (table == self.userTable) {
		NSInteger selectNum = [self.userTable numberOfSelectedRows];
		// 選択ユーザ一覧更新
		[self updateSelectedUsers];
		// １つ以上のユーザが選択されていない場合は送信ボタンが押下不可
		[self.sendButton setEnabled:(selectNum > 0)];
	} else if (table == self.attachTable) {
		[self.attachDelButton setEnabled:([self.attachTable numberOfSelectedRows] > 0)];
	} else {
		ERR(@"Unknown TableView(%@)", table);
	}
}

// ソートの変更
- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
	[self.users sortUsingDescriptors:[aTableView sortDescriptors]];
	[aTableView reloadData];
}

/*----------------------------------------------------------------------------*
 * 添付ファイル
 *----------------------------------------------------------------------------*/

- (void)appendAttachmentByPath:(NSString*)path {
	AttachmentFile*	file;
	Attachment*		attach;
	file = [AttachmentFile fileWithPath:path];
	if (!file) {
		WRN(@"file invalid(%@)", path);
		return;
	}
	attach = [Attachment attachmentWithFile:file];
	if (!attach) {
		WRN(@"attachement invalid(%@)", path);
		return;
	}
	if ([self.attachmentsDic objectForKey:path]) {
		WRN(@"already contains attachment(%@)", path);
		return;
	}
	[self.attachments addObject:attach];
	[self.attachmentsDic setObject:attach forKey:path];
	[self.attachTable reloadData];
	[self setAttachHeader];
    
    self.attachDrawer.delegate = (id)self;
  
	[self.attachDrawer open:self];
    
  
    
}

- (void)drawerWillOpen:(NSNotification *)notification {
    self.attachDrawer.contentView.wantsLayer = true;
    self.attachDrawer.contentView.layer.backgroundColor = self.window.backgroundColor.CGColor;
    NSView *frame = self.attachDrawer.contentView.superview;
    frame.wantsLayer = true;
    frame.layer.backgroundColor = self.window.backgroundColor.CGColor;
}

- (void)drawerDidOpen:(NSNotification *)notification {
    NSView *frame = self.attachDrawer.contentView.superview;
    frame.wantsLayer = true;
    frame.layer.backgroundColor = self.window.backgroundColor.CGColor;
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

- (IBAction)searchMenuItemSelected:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		NSInteger	newSt	= ([sender state] == NSOnState) ? NSOffState : NSOnState;
		BOOL		newVal	= (BOOL)(newSt == NSOnState);
		Config*		cfg		= [Config sharedConfig];

		[sender setState:newSt];
		switch ([sender tag]) {
            case _SEARCH_MENUITEM_TAG_ALPHA:
                cfg.sendSearchByUserAlpha = newVal;
                break;
            case _SEARCH_MENUITEM_TAG_PINYING:
                cfg.sendSearchByPinying = newVal;
                break;
			case _SEARCH_MENUITEM_TAG_USER:
				cfg.sendSearchByUserName = newVal;
				break;
			case _SEARCH_MENUITEM_TAG_GROUP:
				cfg.sendSearchByGroupName = newVal;
				break;
			case _SEARCH_MENUITEM_TAG_HOST:
				cfg.sendSearchByHostName = newVal;
				break;
			case _SEARCH_MENUITEM_TAG_LOGON:
				cfg.sendSearchByLogOnName = newVal;
				break;
			default:
				ERR(@"unknown tag(%ld)", [sender tag]);
				break;
		}
		[self updateUserSearch:self];
		[self updateSearchFieldPlaceholder];
	}
}

// ユーザリスト更新
- (IBAction)updateUserList:(id)sender {
	if (!lastTimeOfEntrySent || ([lastTimeOfEntrySent timeIntervalSinceNow] < -2.0)) {
		[[UserManager sharedManager] removeAllUsers];
		[[MessageCenter sharedCenter] broadcastEntry];
	} else {
		DBG(@"Cancel Refresh User(%f)", [lastTimeOfEntrySent timeIntervalSinceNow]);
	}
	lastTimeOfEntrySent = [NSDate date];
}

- (IBAction)userListMenuItemSelected:(id)sender with:(id)identifier {
	NSTableColumn* col = [self.userTable tableColumnWithIdentifier:identifier];
	if (col) {
		// あるので消す
		[userListColsLock lock];
		[userListColumns setObject:col forKey:identifier];
		[userListColsLock unlock];
		[self.userTable removeTableColumn:col];
		[sender setState:NSOffState];
		[[Config sharedConfig] setSendWindowUserListColumn:identifier hidden:YES];
	} else {
		// ないので追加する
		[userListColsLock lock];
		[self.userTable addTableColumn:[userListColumns objectForKey:identifier]];
		[userListColsLock unlock];
		[sender setState:NSOnState];
		[[Config sharedConfig] setSendWindowUserListColumn:identifier hidden:NO];
	}
}

- (IBAction)userListUserMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoUserNamePropertyIdentifier];
}

- (IBAction)userListGroupMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoGroupNamePropertyIdentifier];
}

- (IBAction)userListHostMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoHostNamePropertyIdentifier];
}

- (IBAction)userListIPAddressMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoIPAddressPropertyIdentifier];
}

- (IBAction)userListLogonMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoLogOnNamePropertyIdentifier];
}

- (IBAction)userListVersionMenuItemSelected:(id)sender {
	[self userListMenuItemSelected:sender with:kIPMsgUserInfoVersionPropertyIdentifer];
}

// ユーザ一覧変更時処理
- (void)userListChanged:(NSNotification*)aNotification
{
	[self.users setArray:[[UserManager sharedManager] users]];
	NSInteger totalNum = [self.users count];
	if (self.userPredicate) {
		[self.users filterUsingPredicate:self.userPredicate];
	}
    
	[self.users sortUsingDescriptors:[self.userTable sortDescriptors]];
	[self.selectedUsersLock lock];
	// ユーザ数設定
	[self.userNumLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"SendDlg.UserNumStr", nil), [self.users count], totalNum]];
    [self.userNumLabel sizeToFit];
	// ユーザリストの再描画
	[self.userTable reloadData];
	// 再選択
	[self.userTable deselectAll:self];
	for (UserInfo* user in self.selectedUsers) {
		NSUInteger index = [self.users indexOfObject:user];
		if (index != NSNotFound) {
			[self.userTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
				   byExtendingSelection:[Config sharedConfig].allowSendingToMultiUser];
		}
	}
	[self.selectedUsersLock unlock];
	[self updateSelectedUsers];
}

- (IBAction)searchUser:(id)sender
{
	NSResponder* firstResponder = [self.window firstResponder];
	if ([firstResponder isKindOfClass:[NSText class]] &&
		([(NSText*)firstResponder delegate] == (id)self.searchField)) {
		// 検索フィールドにフォーカスがある場合はメッセージ領域に移動
		[self.window makeFirstResponder:self.messageArea];
	} else {
		// 検索フィールドにフォーカスがなければフォーカスを移動
		[self.window makeFirstResponder:self.searchField];
	}
}

- (IBAction)selectUser:(id)sender
{
    [self.window makeFirstResponder:self.userTable];
}

- (IBAction)updateUserSearch:(id)sender
{
	NSString* searchWord = [self.searchField stringValue];
    self.userPredicate = nil;
	if ([searchWord length] > 0) {
        
        NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@", "];
        
        NSArray *arr = [[searchWord stringByTrimmingCharactersInSet:set] componentsSeparatedByCharactersInSet:set];
        
		Config*				cfg	= [Config sharedConfig];
		
        NSMutableArray *predicates = [NSMutableArray array];
        
		if (cfg.sendSearchByUserName) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoUserNamePropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoUserNamePropertyIdentifier, arr];
		}
		if (cfg.sendSearchByGroupName) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoGroupNamePropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			if ([fmt length] > 0) {
//				[fmt appendString:@" OR "];
//			}
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoGroupNamePropertyIdentifier, arr];
		}
		if (cfg.sendSearchByHostName) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoHostNamePropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			if ([fmt length] > 0) {
//				[fmt appendString:@" OR "];
//			}
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoHostNamePropertyIdentifier, arr];
		}
		if (cfg.sendSearchByLogOnName) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoLogOnNamePropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			if ([fmt length] > 0) {
//				[fmt appendString:@" OR "];
//			}
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoLogOnNamePropertyIdentifier, arr];
		}
        
        if (cfg.sendSearchByUserAlpha) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoUserAlphaPropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			if ([fmt length] > 0) {
//				[fmt appendString:@" OR "];
//			}
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoUserAlphaPropertyIdentifier, arr];
		}
        
        if (cfg.sendSearchByPinying) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SUBQUERY(%@,$x,%K contains[c] $x).@count>0", arr, kIPMsgUserInfoUserPinYingPropertyIdentifier];
            
            [predicates addObject:predicate];
            
//			if ([fmt length] > 0) {
//				[fmt appendString:@" OR "];
//			}
//			[fmt appendFormat:@"%@ contains[c] %@", kIPMsgUserInfoUserPinYingPropertyIdentifier, arr];
		}

		if (predicates.count > 0) {
            self.userPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
		}
	}
	[self userListChanged:nil];
}

- (void)updateSearchFieldPlaceholder
{
	Config*			cfg		= [Config sharedConfig];
	NSMutableArray*	array	= [NSMutableArray array];
	if (cfg.sendSearchByUserName) {
		[array addObject:NSLocalizedString(@"SendDlg.Search.Target.User", nil)];
	}
	if (cfg.sendSearchByGroupName) {
		[array addObject:NSLocalizedString(@"SendDlg.Search.Target.Group", nil)];
	}
	if (cfg.sendSearchByHostName) {
		[array addObject:NSLocalizedString(@"SendDlg.Search.Target.Host", nil)];
	}
	if (cfg.sendSearchByLogOnName) {
		[array addObject:NSLocalizedString(@"SendDlg.Search.Target.LogOn", nil)];
	}
    if (cfg.sendSearchByUserAlpha)
    {
        [array addObject:NSLocalizedString(@"SendDlg.Search.Target.Alpha", nil)];
    }
    if (cfg.sendSearchByPinying)
    {
        [array addObject:NSLocalizedString(@"SendDlg.Search.Target.PinYing", nil)];
    }
	NSString* str = @"";
	if ([array count] > 0) {
		NSString* sep = NSLocalizedString(@"SendDlg.Search.Placeholder.Separator", nil);
		NSString* fmt = NSLocalizedString(@"SendDlg.Search.Placeholder.Normal", nil);
		str = [NSString stringWithFormat:fmt, [array componentsJoinedByString:sep]];
	} else {
		str = NSLocalizedString(@"SendDlg.Search.Placeholder.Invalid", nil);
	}
	[[self.searchField cell] setPlaceholderString:str];
}

// ウィンドウを返す
//- (NSWindow*)window {
//	return self.window;
//}

// メッセージ部フォントパネル表示
- (void)showSendMessageFontPanel:(id)sender {
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

// メッセージ部フォント保存
- (void)saveSendMessageFont:(id)sender {
	[Config sharedConfig].sendMessageFont = [self.messageArea font];
}

// メッセージ部フォントを標準に戻す
- (void)resetSendMessageFont:(id)sender {
	[self.messageArea setFont:[Config sharedConfig].defaultSendMessageFont];
}

// 送信不可の場合にメニューからの送信コマンドを抑制する
- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(sendMessage:)) {
		return [self.sendButton isEnabled];
	}
	return [super respondsToSelector:aSelector];
}

- (void)setAttachHeader {
	NSString*		format	= NSLocalizedString(@"SendDlg.Attach.Header", nil);
	NSString*		title	= [NSString stringWithFormat:format, [self.attachments count]];
	[[[self.attachTable tableColumnWithIdentifier:@"Attachment"] headerCell] setStringValue:title];
}

/*----------------------------------------------------------------------------*
 *  デリゲート
 *----------------------------------------------------------------------------*/

// Nibファイルロード時処理
- (void)awakeFromNib {
	Config*			config		= [Config sharedConfig];
	NSSize			size		= config.sendWindowSize;
	float			splitPoint	= config.sendWindowSplit;
	NSRect			frame		= [self.window frame];
	int				i;

	// ウィンドウ位置、サイズ決定
	int sw	= [[NSScreen mainScreen] visibleFrame].size.width;
	int sh	= [[NSScreen mainScreen] visibleFrame].size.height;
	int ww	= [self.window frame].size.width;
	int wh	= [self.window frame].size.height;
    
	frame.origin.x = (sw - ww) / 2 + (rand() % (sw / 4)) - sw / 8;
	frame.origin.y = (sh - wh) / 2 + (rand() % (sh / 4)) - sh / 8;
	if ((size.width != 0) || (size.height != 0)) {
		frame.size.width	= size.width;
		frame.size.height	= size.height;
	}
	[self.window setFrame:frame display:NO];
    

	// SplitViewサイズ決定
	if (splitPoint != 0) {
		// 上部
		frame = [self.splitSubview1 frame];
		frame.size.height = splitPoint;
		[self.splitSubview1 setFrame:frame];
		// 下部
		frame = [self.splitSubview2 frame];
		frame.origin.x		= -1;
		frame.size.width	+= 2;
		frame.size.height = [self.splitView frame].size.height - splitPoint - [self.splitView dividerThickness];
		[self.splitSubview2 setFrame:frame];
		// 全体
		[self.splitView adjustSubviews];
	}
	frame = [self.splitSubview2 frame];
	frame.origin.x		= -1;
	frame.size.width	+= 2;
	[self.splitSubview2 setFrame:frame];

	// 封書チェックをデフォルト判定
	if (config.sealCheckDefault) {
		[self.sealCheck setState:NSOnState];
		[self.passwordCheck setEnabled:YES];
	}

	// 複数ユーザへの送信を許可
	[self.userTable setAllowsMultipleSelection:config.allowSendingToMultiUser];

	// ユーザリストの行間設定（デフォルト[3,2]→[2,1]）
	[self.userTable setIntercellSpacing:NSMakeSize(2, 1)];

	// ユーザリストのカラム処理
	NSArray* array = [NSArray arrayWithObjects:
                      kIPMsgUserInfoUserAlphaPropertyIdentifier,
                      kIPMsgUserInfoUserNamePropertyIdentifier,
                      kIPMsgUserInfoGroupNamePropertyIdentifier,
                      kIPMsgUserInfoHostNamePropertyIdentifier,
                      kIPMsgUserInfoIPAddressPropertyIdentifier,
                      kIPMsgUserInfoLogOnNamePropertyIdentifier,
                      kIPMsgUserInfoVersionPropertyIdentifer,
                      nil];
    
	for (i = 0; i < [array count]; i++) {
		NSString*		identifier	= [array objectAtIndex:i];
		NSTableColumn*	column		= [self.userTable tableColumnWithIdentifier:identifier];
		if (identifier && column) {
			// カラム保持
			[userListColsLock lock];
			[userListColumns setObject:column forKey:identifier];
			[userListColsLock unlock];
			// 設定値に応じてカラムの削除
			if ([config sendWindowUserListColumnHidden:identifier]) {
				[self.userTable removeTableColumn:column];
			}
		}
	}

	// ユーザリストのソート設定反映
	[self.users sortUsingDescriptors:[self.userTable sortDescriptors]];

	// 検索フィールドのメニュー設定
	[[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_USER] setState:config.sendSearchByUserName ? NSOnState : NSOffState];
	[[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_GROUP] setState:config.sendSearchByGroupName ? NSOnState : NSOffState];
	[[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_HOST] setState:config.sendSearchByHostName ? NSOnState : NSOffState];
	[[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_LOGON] setState:config.sendSearchByLogOnName ? NSOnState : NSOffState];
    [[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_ALPHA] setState:config.sendSearchByUserAlpha?NSOnState:NSOffState];
    [[self.searchMenu itemWithTag:_SEARCH_MENUITEM_TAG_PINYING] setState:config.sendSearchByPinying?NSOnState:NSOffState];
//    _SEARCH_MENUITEM_TAG_PINYING
    
	[[self.searchField cell] setSearchMenuTemplate:self.searchMenu];
	[self updateSearchFieldPlaceholder];

	// 添付リストの行設定
	[self.attachTable setRowHeight:16.0];

	// メッセージ部フォント
	if (config.sendMessageFont) {
		[self.messageArea setFont:config.sendMessageFont];
	}

	// ファイル添付アイコン
	if (!attachmentImage) {
		attachmentImage = [[NSImage alloc] initWithContentsOfFile:
								[[NSBundle mainBundle] pathForResource:@"AttachS" ofType:@"tiff"]];
	}

	// ファーストレスポンダ設定
	[self.window makeFirstResponder:self.messageArea];
}

// ウィンドウリサイズ時処理
- (void)windowDidResize:(NSNotification *)notification
{
	// ウィンドウサイズを保存
	[Config sharedConfig].sendWindowSize = [self.window frame].size;
}

// SplitViewリサイズ時処理
- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[Config sharedConfig].sendWindowSplit = [self.splitSubview1 frame].size.height;
}

// ウィンドウクローズ時処理
- (void)windowWillClose:(NSNotification*)aNotification {
	[[WindowManager sharedManager] removeReplyWindowForKey:self.receiveMessage];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    // なぜか解放されないので手動で
    self.attachDrawer = nil;
}

@end
