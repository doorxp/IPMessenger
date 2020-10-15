/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: AttachStatusControl.h
 *	Module		: 添付ファイル状況表示パネルコントローラ
 *============================================================================*/

#import <Cocoa/Cocoa.h>

@class AttachmentServer;

@interface AttachStatusControl : NSObject
@property(nonatomic, strong) IBOutlet NSPanel*        panel;
@property(nonatomic, strong) IBOutlet NSOutlineView*    attachTable;
@property(nonatomic, strong) IBOutlet NSButton*        dispAlwaysCheck;
@property(nonatomic, strong) IBOutlet NSButton*        deleteButton;

- (IBAction)buttonPressed:(id)sender;
- (IBAction)checkboxChanged:(id)sender;

@end
