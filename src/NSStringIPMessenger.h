/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: NSStringIPMessenger.h
 *	Module		: NSStringカテゴリ拡張
 *============================================================================*/

#import <Foundation/Foundation.h>


@interface NSString(IPMessenger)

// IPMessenger用送受信文字列変換（C文字列→NSString)
+ (id)stringWithGB18030String:(const char*)cString;

// IPMessenger用送受信文字列変換（C文字列→NSString)
- (id)initWithGB18030String:(const char*)cString;

// IPMessenger用送受信文字列変換
- (const char*)GB18030String;
@end
