//
//  SHKTextMessage.m
//  ShareKit
//
//  Created by Jeremy Lyman on 9/21/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKSMS.h"


@implementation SHKMessageComposeViewController

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	// Remove the SHK view wrapper from the window
	[[SHK currentHelper] viewWasDismissed];
    
}

@end


@implementation SHKSMS

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Share via Text Message";
}

+ (BOOL)canShareText
{
	return YES;
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareImage
{
	return YES;
}

+ (BOOL)canShareFile
{
	return NO;
}

+ (BOOL)shareRequiresInternetConnection
{
	return NO;
}

+ (BOOL)requiresAuthentication
{
	return NO;
}


#pragma mark -
#pragma mark Configuration : Dynamic Enable

+ (BOOL)canShare
{
	return [MFMessageComposeViewController canSendText];
}

- (BOOL)shouldAutoShare
{
	return YES;
}


# pragma mark - URL Shortening

- (void)shortenURL
{	
	if (![SHK connected])
	{
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@",[item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],item.title] forKey:@"bitly-link"];
		
		[self sendSMS];		
		return;
	}
	
	if (!quiet)
		[[SHKActivityIndicator currentIndicator] displayActivity:SHKLocalizedString(@"Shortening URL...")];
    
	self.request = [[[SHKRequest alloc] initWithURL:[NSURL URLWithString:[NSMutableString stringWithFormat:@"http://api.bit.ly/v3/shorten?login=%@&apikey=%@&longUrl=%@&format=txt",
																		  SHKBitLyLogin,
																		  SHKBitLyKey,																		  
																		  SHKEncodeURL(item.URL)
																		  ]]
											 params:nil
										   delegate:self
								 isFinishedSelector:@selector(shortenURLFinished:)
											 method:@"GET"
										  autostart:YES] autorelease];
}

- (void)shortenURLFinished:(SHKRequest *)aRequest
{
	[[SHKActivityIndicator currentIndicator] hide];
	
	NSString *result = [[aRequest getResult] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	
	if (result == nil || [NSURL URLWithString:result] == nil)
	{
		// TODO - better error message
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Shorten URL Error")
									 message:SHKLocalizedString(@"We could not shorten the URL.")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Continue")
						   otherButtonTitles:nil] autorelease] show];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],item.title] forKey:@"bitly-link"];
	}
	
	else
	{		
		///if already a bitly login, use url instead
		if ([result isEqualToString:@"ALREADY_A_BITLY_LINK"])
			result = [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : result, item.title] forKey:@"bitly-link"];
	}
    
	[self sendText];
}


#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{
	self.quiet = YES;
	
	if (![self validateItem])
		return NO;
	
    [self shortenURL];
    
    return YES;
}

- (void)sendText
{	
    SHKMessageComposeViewController *smsController = [[[SHKMessageComposeViewController alloc] init] autorelease];
	[smsController setBody:[item customValueForKey:@"bitly-link"]];
    [smsController setMessageComposeDelegate:self];
	
	[[SHK currentHelper] showViewController:smsController];	
}

- (void)sharerCancelledSending:(SHKSharer *)sharer
{
	
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)controller 
				 didFinishWithResult:(MessageComposeResult)result 
{
	
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
	
	switch (result)
	{
		case MessageComposeResultCancelled:
			[self sendDidCancel];
			break;
		case MessageComposeResultSent:
			[self sendDidFinish];
			break;
		case MessageComposeResultFailed:
			[self sendDidFailWithError:nil];
			break;
		default:
			break;
	}
}


@end