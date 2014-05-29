/*============================================================================*
 * (C) 2001-2011 G.Ishiwata, All Rights Reserved.
 *
 *	Project		: IP Messenger for Mac OS X
 *	File		: NSStringIPMessenger.m
 *	Module		: NSStringカテゴリ拡張
 *============================================================================*/

#import "NSStringIPMessenger.h"
#import "DebugLog.h"

@implementation NSString(IPMessenger)

// IPMessenger用送受信文字列変換（C文字列→NSString)
+ (id)stringWithGB18030String:(const char*)cString
{
	return [[[NSString alloc] initWithGB18030String:cString] autorelease];
}

// IPMessenger用送受信文字列変換（C文字列→NSString)
- (id)initWithGB18030String:(const char*)cString
{
    NSStringEncoding encoding =
    CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
	return [self initWithCString:cString encoding:encoding];
}


// IPMessenger用送受信文字列変換（NSString→C文字列)
- (const char*)GB18030String
{
	// SJISの場合、'¥'は'\'に変換しておかないと文字化けする
    NSStringEncoding encoding =
    CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
	NSString* str = self;
//    [self stringByReplacingOccurrencesOfString:@"¥"
//													withString:@"\\"];
	if (![str canBeConvertedToEncoding:encoding]) {
		// 変換できない文字がある場合は安全な方法で変換する
		NSData*			data1 = [str dataUsingEncoding:encoding
								  allowLossyConversion:YES];
		NSMutableData*	data2 = [[data1 mutableCopy] autorelease];
		[data2 appendBytes:"\0" length:1];
		return (const char*)[data2 bytes];
	}
	// 変換できるならそのまま
	return [str cStringUsingEncoding:encoding];
}

@end
