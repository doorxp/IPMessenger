/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: ReceiveControl.m
 *	Module		: 受信メッセージウィンドウコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>
#import "ReceiveControl.h"
#import "Config.h"
#import "UserInfo.h"
#import "LogManager.h"
#import "MessageCenter.h"
#import "WindowManager.h"
#import "RecvMessage.h"
#import "SendControl.h"
#import "AttachmentFile.h"
#import "Attachment.h"
#import "DebugLog.h"
#import "AppControl.h"
#include <unistd.h>

/*============================================================================*
 * クラス実装
 *============================================================================*/

@implementation ReceiveControl

/*----------------------------------------------------------------------------*
 * 初期化／解放
 *----------------------------------------------------------------------------*/

// 初期化
- (id)initWithRecvMessage:(RecvMessage*)msg {
	Config*		config = [Config sharedConfig];

	self = [super init];

	if (!msg) {
		return nil;
	}

	if (![NSBundle.mainBundle loadNibNamed:@"ReceiveWindow" owner:self topLevelObjects:nil]) {
		return nil;
	}

	// ログ出力
	if (config.standardLogEnabled) {
		if (![msg locked] || !config.logChainedWhenOpen) {
			[[LogManager standardLog] writeRecvLog:msg];
			[msg setNeedLog:NO];
		}
	}

	// 表示内容の設定
	[self.dateLabel setObjectValue:msg.receiveDate];
	[self.userNameLabel setStringValue:[[msg fromUser] summaryString]];
	[self.messageArea setString:[msg appendix]];
	if ([msg multicast]) {
		[self.infoBox setTitle:NSLocalizedString(@"RecvDlg.BoxTitleMulti", nil)];
	} else if ([msg broadcast]) {
		[self.infoBox setTitle:NSLocalizedString(@"RecvDlg.BoxTitleBroad", nil)];
	} else if ([msg absence]) {
		[self.infoBox setTitle:NSLocalizedString(@"RecvDlg.BoxTitleAbsence", nil)];
	}
	if (![msg sealed]) {
		[self.sealButton removeFromSuperview];
		[self.window makeFirstResponder:self.messageArea];
	} else {
		[self.replyButton setEnabled:NO];
		[self.quotCheck setEnabled:NO];
		[self.window makeFirstResponder:self.sealButton];
	}
	if ([msg locked]) {
		[self.sealButton setTitle:NSLocalizedString(@"RecvDlg.LockBtnStr", nil)];
	}

	// クリッカブルURL設定
	if (config.useClickableURL) {
		NSMutableAttributedString*	attrStr;
		NSScanner*					scanner;
		NSCharacterSet*				charSet;
		NSArray*					schemes;
		attrStr	= [self.messageArea textStorage];
		scanner	= [NSScanner scannerWithString:[msg appendix]];
		charSet	= [NSCharacterSet characterSetWithCharactersInString:NSLocalizedString(@"RecvDlg.URL.Delimiter", nil)];
		schemes = [NSArray arrayWithObjects:@"http://", @"https://", @"ftp://", @"file://", @"rtsp://", @"afp://", @"mailto:", nil];
		while (![scanner isAtEnd]) {
			NSString*	sentence;
			NSRange		range;
			unsigned	i;
			if (![scanner scanUpToCharactersFromSet:charSet intoString:&sentence]) {
				continue;
			}
			for (i = 0; i < [schemes count]; i++) {
				range = [sentence rangeOfString:[schemes objectAtIndex:i]];
				if (range.location != NSNotFound) {
					if (range.location > 0) {
						sentence	= [sentence substringFromIndex:range.location];
					}
					range.length	= [sentence length];
					range.location	= [scanner scanLocation] - [sentence length];
					[attrStr addAttribute:NSLinkAttributeName value:sentence range:range];
					[attrStr addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
					[attrStr addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1] range:range];
					break;
				}
			}
			if (i < [schemes count]) {
				continue;
			}
			range = [sentence rangeOfString:@"://"];
			if (range.location != NSNotFound) {
				range.location	= [scanner scanLocation] - [sentence length];
				range.length	= [sentence length];
				[attrStr addAttribute:NSLinkAttributeName value:sentence range:range];
				[attrStr addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
				[attrStr addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1] range:range];
				continue;
			}
		}
	}

    self.recvMsg = msg ;
	[[WindowManager sharedManager] setReceiveWindow:self forKey:self.recvMsg];

	if (![self.recvMsg sealed]) {
		// 重要ログボタンの有効／無効
		if (config.alternateLogEnabled) {
			[self.altLogButton setEnabled:config.alternateLogEnabled];
		} else {
			[self.altLogButton setHidden:YES];
		}

		// 添付ボタンの有効／無効
		if ([[self.recvMsg attachments] count] > 0) {
			[self.attachButton setEnabled:YES];
		}
	}

	[self setAttachHeader];
	[self.attachTable reloadData];
	[self.attachTable selectAll:self];

    self.downloader = nil;
    self.pleaseCloseMe = NO;
    self.attachSheetRefreshTimer = nil;

	return self;
}

// 解放処理
- (void)dealloc {
    self.recvMsg = nil;
    self.downloader = nil;
//	[recvMsg release];
//	[downloader release];
//	[super dealloc];
}

/*----------------------------------------------------------------------------*
 * ウィンドウ表示
 *----------------------------------------------------------------------------*/

- (void)showWindow {
	NSWindow* orgKeyWin = [NSApp keyWindow];
	if (orgKeyWin) {
		if ([[orgKeyWin delegate] isKindOfClass:[SendControl class]]) {
			[self.window orderFront:self];
			[orgKeyWin orderFront:self];
		} else {
			[self.window makeKeyAndOrderFront:self];
		}
	} else {
		[self.window makeKeyAndOrderFront:self];
	}
	if (([[self.recvMsg attachments] count] > 0) && ![self.recvMsg sealed]) {
		[self.attachDrawer open];
	}
}

/*----------------------------------------------------------------------------*
 * ボタン
 *----------------------------------------------------------------------------*/

- (IBAction)buttonPressed:(id)sender {
	if (sender == self.attachSaveButton) {
		NSOpenPanel* op = [NSOpenPanel openPanel];
		[self.attachSaveButton setEnabled:NO];
		[op setCanChooseFiles:NO];
		[op setCanChooseDirectories:YES];
		[op setPrompt:NSLocalizedString(@"RecvDlg.Attach.SelectBtn", nil)];

        [op beginSheetModalForWindow:self.window
                   completionHandler:^(NSInteger result)
        {
            [self sheetDidEnd:op
                   returnCode:result
                  contextInfo:(__bridge void *)(sender)];
        }];
	} else if (sender == self.attachSheetCancelButton) {
		[self.downloader stopDownload];
	} else {
		DBG(@"Unknown button pressed(%@)", sender);
	}
}

- (void)attachTableDoubleClicked:(id)sender {
	if (sender == self.attachTable) {
		[self buttonPressed:self.attachSaveButton];
	}
}

// シート終了処理
- (void)sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)code contextInfo:(void*)info {
    if (info == (__bridge void *)(self.attachSaveButton)) {
		if (code == NSModalResponseOK) {
			NSFileManager*	fileManager	= [NSFileManager defaultManager];
			NSString*		directory	= [[(NSOpenPanel*)sheet directoryURL] relativePath];
			NSIndexSet*		indexes		= [self.attachTable selectedRowIndexes];
			NSUInteger		index;
		
			self.downloader = [[AttachmentClient alloc] initWithRecvMessage:self.recvMsg saveTo:directory];
			index = [indexes firstIndex];
			while (index != NSNotFound) {
				NSString*	path;
				Attachment*	attach;
				attach = [[self.recvMsg attachments] objectAtIndex:index];
				if (!attach) {
					index = [indexes indexGreaterThanIndex:index];
					continue;
				}
				path = [directory stringByAppendingPathComponent:[[attach file] name]];
				// ファイル存在チェック
				if ([fileManager fileExistsAtPath:path]) {
					// 上書き確認
					NSInteger result;
					WRN(@"file exists(%@)", path);
                    NSAlert *alert = [NSAlert new];
					if ([[attach file] isDirectory]) {
//						result = NSRunAlertPanel(	NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Title", nil),
//													NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Msg", nil),
//													NSLocalizedString(@"RecvDlg.AttachDirOverwrite.OK", nil),
//													NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Cancel", nil),
//													nil,
//													[[attach file] name]);
                        
                        alert.messageText = NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Title", nil);
                        alert.informativeText = [NSString stringWithFormat: NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Msg", nil), [[attach file] name]];
                        
                        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.AttachDirOverwrite.OK", nil)];
                        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.AttachDirOverwrite.Cancel", nil)];
                        
                       
                        
                        
					} else {
//						result = NSRunAlertPanel(	NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Title", nil),
//													NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Msg", nil),
//													NSLocalizedString(@"RecvDlg.AttachFileOverwrite.OK", nil),
//													NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Cancel", nil),
//													nil,
//													[[attach file] name]);
                        
                        alert.messageText = NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Title", nil);
                        alert.informativeText = [NSString stringWithFormat: NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Msg", nil), [[attach file] name]];
                        
                        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.AttachFileOverwrite.OK", nil)];
                        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.AttachFileOverwrite.Cancel", nil)];
					}
                    
                    result = [alert runModal];
                    
					switch (result) {
					case NSAlertFirstButtonReturn:
						DBG(@"overwrite ok.");
						break;
					case NSAlertSecondButtonReturn:
						DBG(@"overwrite canceled.");
						[self.attachTable deselectRow:index];	// 選択解除
						index = [indexes indexGreaterThanIndex:index];
						continue;
					default:
						ERR(@"inernal error.");
						break;
					}
				}
				[self.downloader addTarget:attach];
				index = [indexes indexGreaterThanIndex:index];
			}
			[sheet orderOut:self];
			if ([self.downloader numberOfTargets] == 0) {
				WRN(@"downloader has no targets");
                self.downloader = nil;
				return;
			}
			// ダウンロード準備（UI）
			[self.attachSaveButton setEnabled:NO];
			[self.attachTable setEnabled:NO];
			[self.attachSheetProgress setIndeterminate:NO];
			[self.attachSheetProgress setMaxValue:[self.downloader totalSize]];
			[self.attachSheetProgress setDoubleValue:0];
			// シート表示
//			[NSApp beginSheet:attachSheet
//			   modalForWindow:window
//				modalDelegate:self
//			   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
//				  contextInfo:nil];
            
            [self.window beginSheet:self.attachSheet completionHandler:^(NSModalResponse returnCode) {
                [self sheetDidEnd:self.attachSheet returnCode:returnCode contextInfo:nil];
            }];
            
			// ダウンロード（スレッド）開始
            self.attachSheetRefreshTitle			= NO;
            self.attachSheetRefreshFileName		= NO;
            self.attachSheetRefreshPercentage	= NO;
            self.attachSheetRefreshFileNum		= NO;
            self.attachSheetRefreshDirNum		= NO;
            self.attachSheetRefreshSize			= NO;
			[self.downloader startDownload:self];
            self.attachSheetRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
																	   target:self
																	 selector:@selector(downloadSheetRefresh:)
																	 userInfo:nil
																	  repeats:YES];
		} else {
			[self.attachSaveButton setEnabled:([self.attachTable numberOfSelectedRows] > 0)];
		}
	} else if (sheet == self.attachSheet) {
		[self.attachSheetRefreshTimer invalidate];
        self.attachSheetRefreshTimer = nil;
		[self.recvMsg removeDownloadedAttachments];
		[sheet orderOut:self];
		[self.attachSaveButton setEnabled:([self.attachTable numberOfSelectedRows] > 0)];
		[self.attachTable reloadData];
		[self setAttachHeader];
		[self.attachTable setEnabled:YES];
		if ([[self.recvMsg attachments] count] <= 0) {
//			[attachDrawer performSelectorOnMainThread:@selector(close:) withObject:self waitUntilDone:YES];
			[self.attachDrawer close];
			[self.attachButton setEnabled:NO];
		}
        self.downloader = nil;
	}
    else if (info == (__bridge void *)(self.recvMsg)) {
		[sheet orderOut:self];
		if (code == NSModalResponseOK) {
            self.pleaseCloseMe = YES;
			[self.window performClose:self];
		}
	}
}

/*----------------------------------------------------------------------------*
 * 返信処理
 *----------------------------------------------------------------------------*/

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	// 封書開封前はメニューとキーボードショートカットで返信できてしまわないようにする
	// （メニューアイテムの判定方法が暫定）
    if ([[item keyEquivalent] isEqualToString:@"r"] && ([item keyEquivalentModifierMask] & NSEventModifierFlagCommand)) {
		return [self.replyButton isEnabled];
	}
	return YES;
}

// 返信ボタン押下時処理
- (IBAction)replyMessage:(id)sender {
	Config*		config	= [Config sharedConfig];
	NSString*	quotMsg	= nil;
    id			sendCtl	= [[WindowManager sharedManager] replyWindowForKey:_recvMsg];
	if (sendCtl) {
		[[sendCtl window] makeKeyAndOrderFront:self];
		return;
	}
	if ([self.quotCheck state]) {
		NSString* quote = config.quoteString;

		// 選択範囲があれば選択範囲を引用、なければ全文引用
		NSRange	range = [self.messageArea selectedRange];
		if (range.length <= 0) {
			quotMsg = [self.messageArea string];
		} else {
			quotMsg = [[self.messageArea string] substringWithRange:range];
		}
		if (([quotMsg length] > 0) && ([quote length] > 0)) {
			// 引用文字を入れる
			NSArray*			array;
			NSMutableString*	strBuf;
			NSUInteger					lines;
			NSUInteger					iCount;
			array	= [quotMsg componentsSeparatedByString:@"\n"];
			lines	= [array count];
			strBuf	= [NSMutableString stringWithCapacity:
							[quotMsg length] + ([quote length] + 1) * lines];
			for (iCount = 0; iCount < lines; iCount++) {
				[strBuf appendString:quote];
				[strBuf appendString:[array objectAtIndex:iCount]];
				[strBuf appendString:@"\n"];
			}
			quotMsg = strBuf;
		}
	}
	// 送信ダイアログ作成
	//sendCtl =
    
    AppControl *appCtl = [NSApp delegate];
    appCtl.lastDockDraggedWindow = [[SendControl alloc] initWithSendMessage:quotMsg recvMessage:self.recvMsg];
}

/*----------------------------------------------------------------------------*
 * 封書関連処理
 *----------------------------------------------------------------------------*/

// 封書ボタン押下時処理
- (IBAction)openSeal:(id)sender {
	if ([self.recvMsg locked]) {
		// 鍵付きの場合
		// フィールド／ラベルをクリア
		[self.pwdSheetField setStringValue: @""];
		[self.pwdSheetErrorLabel setStringValue: @""];
		// シート表示
//		[NSApp beginSheet:pwdSheet
//		   modalForWindow:window
//			modalDelegate:self
//		   didEndSelector:@selector(pwdSheetDidEnd:returnCode:contextInfo:)
//			  contextInfo:nil];
        
        [self.window beginSheet:self.pwdSheet completionHandler:^(NSModalResponse returnCode) {
            [self pwdSheetDidEnd:self.pwdSheet returnCode:returnCode contextInfo:nil];
        }];
	} else {
		// 封書消去
		[sender removeFromSuperview];
		[self.replyButton setEnabled:YES];
		[self.quotCheck setEnabled:YES];
		[self.altLogButton setEnabled:[Config sharedConfig].alternateLogEnabled];
		if ([[self.recvMsg attachments] count] > 0) {
			[self.attachButton setEnabled:YES];
			[self.attachDrawer open];
		}

		// 封書開封通知送信
		[[MessageCenter sharedCenter] sendOpenSealMessage:self.recvMsg];
	}
}

// パスワードシート終了処理
- (void)pwdSheetDidEnd:(NSWindow*)sheet returnCode:(NSModalResponse)code contextInfo:(void*)info {
	[self.pwdSheet orderOut:self];
}

// パスワード入力シートOKボタン押下時処理
- (IBAction)okPwdSheet:(id)sender {
	NSString*	password	= [Config sharedConfig].password;
	NSString*	input		= [self.pwdSheetField stringValue];

	// パスワードチェック
	if (password) {
		if ([password length] > 0) {
			if ([input length] <= 0) {
				[self.pwdSheetErrorLabel setStringValue:NSLocalizedString(@"RecvDlg.PwdChk.NoPwd", nil)];
				return;
			}
			if (![password isEqualToString:[NSString stringWithCString:crypt([input UTF8String], "IP") encoding:NSUTF8StringEncoding]] &&
				![password isEqualToString:input]) {
				// 平文とも比較するのはv0.4までとの互換性のため
				[self.pwdSheetErrorLabel setStringValue:NSLocalizedString(@"RecvDlg.PwdChk.PwdErr", nil)];
				return;
			}
		}
	}

	// 封書消去
	[self.sealButton removeFromSuperview];
	[self.replyButton setEnabled:YES];
	[self.quotCheck setEnabled:YES];
	[self.altLogButton setEnabled:[Config sharedConfig].alternateLogEnabled];
	if ([[self.recvMsg attachments] count] > 0) {
		[self.attachButton setEnabled:YES];
		[self.attachDrawer open];
	}

	// ログ出力
	if ([self.recvMsg needLog]) {
		[[LogManager standardLog] writeRecvLog:self.recvMsg];
		[self.recvMsg setNeedLog:NO];
	}

	// 封書開封通知送信
	[[MessageCenter sharedCenter] sendOpenSealMessage:self.recvMsg];

	[NSApp endSheet:self.pwdSheet returnCode:NSModalResponseOK];
}

// パスワード入力シートキャンセルボタン押下時処理
- (IBAction)cancelPwdSheet:(id)sender {
	[NSApp endSheet:self.pwdSheet returnCode:NSModalResponseCancel];
}

/*----------------------------------------------------------------------------*
 * 添付ファイル
 *----------------------------------------------------------------------------*/

- (void)downloadSheetRefresh:(NSTimer*)timer {
	if (self.attachSheetRefreshTitle) {
		NSUInteger num	= [self.downloader numberOfTargets];
		NSUInteger index	= [self.downloader indexOfTarget] + 1;
		NSString* title = [NSString stringWithFormat:NSLocalizedString(@"RecvDlg.AttachSheet.Title", nil), index, num];
		[self.attachSheetTitleLabel setStringValue:title];
        self.attachSheetRefreshTitle = NO;
	}
	if (self.attachSheetRefreshFileName) {
		[self.attachSheetFileNameLabel setStringValue:[self.downloader currentFile]];
        self.attachSheetRefreshFileName = NO;
	}
	if (self.attachSheetRefreshFileNum) {
		[self.attachSheetFileNumLabel setObjectValue:@([self.downloader numberOfFile])];
        self.attachSheetRefreshFileNum = NO;
	}
	if (self.attachSheetRefreshDirNum) {
		[self.attachSheetDirNumLabel setObjectValue:[NSNumber numberWithUnsignedInt:[self.downloader numberOfDirectory]]];
        self.attachSheetRefreshDirNum = NO;
	}
	if (self.attachSheetRefreshPercentage) {
		[self.attachSheetPercentageLabel setStringValue:[NSString stringWithFormat:@"%d %%", [self.downloader percentage]]];
        self.attachSheetRefreshPercentage = NO;
	}
	if (self.attachSheetRefreshSize) {
		double		downSize	= [self.downloader downloadSize];
		double		totalSize	= [self.downloader totalSize];
		NSString*	str			= nil;
		float		bps;
		if (totalSize < 1024) {
			str = [NSString stringWithFormat:@"%d / %d Bytes", (int)downSize, (int)totalSize];
		}
		if (!str) {
			downSize /= 1024.0;
			totalSize /= 1024.0;
			if (totalSize < 1024) {
				str = [NSString stringWithFormat:@"%.1f / %.1f KBytes", downSize, totalSize];
			}
		}
		if (!str) {
			downSize /= 1024.0;
			totalSize /= 1024.0;
			if (totalSize < 1024) {
				str = [NSString stringWithFormat:@"%.2f / %.2f MBytes", downSize, totalSize];
			}
		}
		if (!str) {
			downSize /= 1024.0;
			totalSize /= 1024.0;
			str = [NSString stringWithFormat:@"%.2f / %.2f GBytes", downSize, totalSize];
		}
		[self.attachSheetSizeLabel setStringValue:str];
		bps = ((float)[self.downloader averageSpeed] / 1024.0f);
		if (bps < 1024) {
			[self.attachSheetSpeedLabel setStringValue:[NSString stringWithFormat:@"%0.1f KBytes/sec", bps]];
		} else {
			bps /= 1024.0;
			[self.attachSheetSpeedLabel setStringValue:[NSString stringWithFormat:@"%0.2f MBytes/sec", bps]];
		}
        self.attachSheetRefreshSize = NO;
	}
}

- (void)downloadWillStart {
	[self.attachSheetTitleLabel setStringValue:NSLocalizedString(@"RecvDlg.AttachSheet.Start", nil)];
	[self.attachSheetFileNameLabel setStringValue:@""];
    self.attachSheetRefreshTitle			= NO;
    self.attachSheetRefreshFileName		= NO;
    self.attachSheetRefreshFileNum		= YES;
    self.attachSheetRefreshDirNum		= YES;
    self.attachSheetRefreshPercentage	= YES;
    self.attachSheetRefreshSize			= YES;
	[self downloadSheetRefresh:nil];
}

- (void)downloadDidFinished:(DownloadResult)result {
	[self.attachSheetTitleLabel setStringValue:NSLocalizedString(@"RecvDlg.AttachSheet.Finish", nil)];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	[NSApp endSheet:self.attachSheet returnCode:NSModalResponseOK];
	if ((result != DL_SUCCESS) && (result != DL_STOP)) {
		NSString* msg = nil;
		switch (result) {
		case DL_TIMEOUT:				// 通信タイムアウト
			msg = NSLocalizedString(@"RecvDlg.DownloadError.TimeOut", nil);
			break;
		case DL_CONNECT_ERROR:			// 接続セラー
			msg = NSLocalizedString(@"RecvDlg.DownloadError.Connect", nil);
			break;
		case DL_DISCONNECTED:
			msg = NSLocalizedString(@"RecvDlg.DownloadError.Disconnected", nil);
			break;
		case DL_SOCKET_ERROR:			// ソケットエラー
			msg = NSLocalizedString(@"RecvDlg.DownloadError.Socket", nil);
			break;
		case DL_COMMUNICATION_ERROR:	// 送受信エラー
			msg = NSLocalizedString(@"RecvDlg.DownloadError.Communication", nil);
			break;
		case DL_FILE_OPEN_ERROR:		// ファイルオープンエラー
			msg = NSLocalizedString(@"RecvDlg.DownloadError.FileOpen", nil);
			break;
		case DL_INVALID_DATA:			// 異常データ受信
			msg = NSLocalizedString(@"RecvDlg.DownloadError.InvalidData", nil);
			break;
		case DL_INTERNAL_ERROR:			// 内部エラー
			msg = NSLocalizedString(@"RecvDlg.DownloadError.Internal", nil);
			break;
		case DL_SIZE_NOT_ENOUGH:		// ファイルサイズ以上
			msg = NSLocalizedString(@"RecvDlg.DownloadError.FileSize", nil);
			break;
		case DL_OTHER_ERROR:			// その他エラー
		default:
			msg = NSLocalizedString(@"RecvDlg.DownloadError.OtherError", nil);
			break;
		}
//		NSBeginCriticalAlertSheet(	NSLocalizedString(@"RecvDlg.DownloadError.Title", nil),
//									NSLocalizedString(@"RecvDlg.DownloadError.OK", nil),
//									nil, nil, self.window, nil, nil, nil, nil, msg, result);
        
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"RecvDlg.DownloadError.Title", nil);
        alert.informativeText = [NSString stringWithFormat:msg, result];
        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.DownloadError.OK", nil)];
        
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        
	}
}

- (void)downloadFileChanged {
    self.attachSheetRefreshFileName = YES;
}

- (void)downloadNumberOfFileChanged {
    self.attachSheetRefreshFileNum = YES;
}

- (void)downloadNumberOfDirectoryChanged {
    self.attachSheetRefreshDirNum = YES;
}

- (void)downloadIndexOfTargetChanged {
    self.attachSheetRefreshTitle	= YES;
}

- (void)downloadTotalSizeChanged {
	[self.attachSheetProgress setMaxValue:[self.downloader totalSize]];
    self.attachSheetRefreshSize = YES;
}

- (void)downloadDownloadedSizeChanged {
	[self.attachSheetProgress setDoubleValue:[self.downloader downloadSize]];
    self.attachSheetRefreshSize = YES;
}

- (void)downloadPercentageChanged {
    self.attachSheetRefreshPercentage = YES;
}

/*----------------------------------------------------------------------------*
 * NSTableDataSourceメソッド
 *----------------------------------------------------------------------------*/

- (NSInteger)numberOfRowsInTableView:(NSTableView*)aTableView {
	if (aTableView == self.attachTable) {
		return [[self.recvMsg attachments] count];
	} else {
		ERR(@"Unknown TableView(%@)", aTableView);
	}
	return 0;
}

- (id)tableView:(NSTableView*)aTableView
		objectValueForTableColumn:(NSTableColumn*)aTableColumn
		row:(int)rowIndex {
	if (aTableView == self.attachTable) {
		Attachment*					attach;
		NSMutableAttributedString*	cellValue;
		NSFileWrapper*				fileWrapper;
		NSTextAttachment*			textAttachment;
		if (rowIndex >= [[self.recvMsg attachments] count]) {
			ERR(@"invalid index(row=%d)", rowIndex);
			return nil;
		}
		attach = [[self.recvMsg attachments] objectAtIndex:rowIndex];
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

// ユーザリストの選択変更
- (void)tableViewSelectionDidChange:(NSNotification*)aNotification {
	NSTableView* table = [aNotification object];
	if (table == self.attachTable) {
		float			size	= 0;
		NSUInteger		index;
		NSIndexSet*		selects = [self.attachTable selectedRowIndexes];
		Attachment*		attach	= nil;

		index = [selects firstIndex];
		while (index != NSNotFound) {
			attach	= [[self.recvMsg attachments] objectAtIndex:index];
			size	+= (float)[attach file].size / 1024;
			index	= [selects indexGreaterThanIndex:index];
		}
		[self.attachSaveButton setEnabled:([selects count] > 0)];
	} else {
		ERR(@"Unknown TableView(%@)", table);
	}
}

/*----------------------------------------------------------------------------*
 * その他
 *----------------------------------------------------------------------------*/

//- (NSWindow*)window {
//	return window;
//}

// 一番奥のウィンドウを手前に移動
- (IBAction)backWindowToFront:(id)sender {
	NSArray*	wins	= [NSApp orderedWindows];
	NSInteger			i;
	for (i = [wins count] - 1; i >= 0; i--) {
		NSWindow* win = [wins objectAtIndex:i];
		if ([win isVisible] && [[win delegate] isKindOfClass:[ReceiveControl class]]) {
			[win makeKeyAndOrderFront:self];
			break;
		}
	}
}

// メッセージ部フォントパネル表示
- (void)showReceiveMessageFontPanel:(id)sender {
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

// メッセージ部フォント保存
- (void)saveReceiveMessageFont:(id)sender {
	[Config sharedConfig].receiveMessageFont = [self.messageArea font];
}

// メッセージ部フォントを標準に戻す
- (void)resetReceiveMessageFont:(id)sender {
	[self.messageArea setFont:[Config sharedConfig].defaultReceiveMessageFont];
}

// 重要ログボタン押下時処理
- (IBAction)writeAlternateLog:(id)sender
{
	if ([Config sharedConfig].logWithSelectedRange) {
		[[LogManager alternateLog] writeRecvLog:self.recvMsg withRange:[self.messageArea selectedRange]];
	} else {
		[[LogManager alternateLog] writeRecvLog:self.recvMsg];
	}
	[self.altLogButton setEnabled:NO];
}

// Nibファイルロード時処理
- (void)awakeFromNib {
	Config* config	= [Config sharedConfig];
	NSSize	size	= config.receiveWindowSize;
	NSRect	frame	= [self.window frame];

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

	// 引用チェックをデフォルト判定
	if (config.quoteCheckDefault) {
		[self.quotCheck setState:YES];
	}

	// 添付リストの行設定
	[self.attachTable setRowHeight:16.0];

	// 添付テーブルダブルクリック時処理
	[self.attachTable setDoubleAction:@selector(attachTableDoubleClicked:)];

//	[attachSheetProgress setUsesThreadedAnimation:YES];
}

// ウィンドウリサイズ時処理
- (void)windowDidResize:(NSNotification *)notification
{
	// ウィンドウサイズを保存
	[Config sharedConfig].receiveWindowSize = [self.window frame].size;
}

// ウィンドウクローズ判定処理
- (BOOL)windowShouldClose:(id)sender {
	if (!self.pleaseCloseMe && ([[self.recvMsg attachments] count] > 0)) {
		// 添付ファイルが残っているがクローズするか確認
//		NSBeginAlertSheet(	NSLocalizedString(@"RecvDlg.CloseWithAttach.Title", nil),
//							NSLocalizedString(@"RecvDlg.CloseWithAttach.OK", nil),
//							NSLocalizedString(@"RecvDlg.CloseWithAttach.Cancel", nil),
//							nil,
//                          self.window,
//							self,
//							@selector(sheetDidEnd:returnCode:contextInfo:),
//							nil,
//                          (__bridge void *)(self.recvMsg),
//							NSLocalizedString(@"RecvDlg.CloseWithAttach.Msg", nil));
        
        
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"RecvDlg.CloseWithAttach.Title", nil);
        alert.informativeText = NSLocalizedString(@"RecvDlg.CloseWithAttach.Msg", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.CloseWithAttach.OK", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.CloseWithAttach.Cancel", nil)];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [self sheetDidEnd:self.window returnCode:returnCode contextInfo:(__bridge void *)(self.recvMsg)];
        }];
        
        
		[self.attachDrawer open];
		return NO;
	}
	if (!self.pleaseCloseMe && ![self.replyButton isEnabled]) {
		// 未開封だがクローズするか確認
//		NSBeginAlertSheet(	NSLocalizedString(@"RecvDlg.CloseWithSeal.Title", nil),
//							NSLocalizedString(@"RecvDlg.CloseWithSeal.OK", nil),
//							NSLocalizedString(@"RecvDlg.CloseWithSeal.Cancel", nil),
//							nil,
//                          self.window,
//							self,
//							@selector(sheetDidEnd:returnCode:contextInfo:),
//							nil,
//                          (__bridge void *)(self.recvMsg),
//							NSLocalizedString(@"RecvDlg.CloseWithSeal.Msg", nil));
        
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"RecvDlg.CloseWithSeal.Title", nil);
        alert.informativeText = NSLocalizedString(@"RecvDlg.CloseWithSeal.Msg", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.CloseWithSeal.OK", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"RecvDlg.CloseWithSeal.Cancel", nil)];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            [self sheetDidEnd:self.window returnCode:returnCode contextInfo:(__bridge void *)(self.recvMsg)];
        }];
        
		return NO;
	}

	return YES;
}

// ウィンドウクローズ時処理
- (void)windowWillClose:(NSNotification*)aNotification {
	if ([[self.recvMsg attachments] count] > 0) {
		// 添付ファイルが残っている場合破棄通知
		[[MessageCenter sharedCenter] sendReleaseAttachmentMessage:self.recvMsg];
	}
	[[WindowManager sharedManager] removeReceiveWindowForKey:self.recvMsg];
// なぜか解放されないので手動で

}

- (void)setAttachHeader {
	NSString*		format	= NSLocalizedString(@"RecvDlg.Attach.Header", nil);
	NSString*		title	= [NSString stringWithFormat:format, [[self.recvMsg attachments] count]];
	[[[self.attachTable tableColumnWithIdentifier:@"Attachment"] headerCell] setStringValue:title];
}

@end
