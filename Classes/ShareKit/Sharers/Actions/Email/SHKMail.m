//
//  SHKMail.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/17/10.

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

#import "SHKConfiguration.h"
#import "SHKMail.h"

@implementation SHKMailComposeViewController

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	// Remove the SHK view wrapper from the window
	[[SHK currentHelper] viewWasDismissed];
}

@end

@implementation SHKMail

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return SHKLocalizedString(@"Share via Email");
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
	return YES;
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
	return [MFMailComposeViewController canSendMail];
}

- (BOOL)shouldAutoShare
{
	return YES;
}

#pragma mark - URL Shortening

- (void)shortenURL
{	
	
	if (![SHK connected]) {
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.title, [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] forKey:@"bitly-link"];
		
		[self sendMail];	
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
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Shorten URL Error")
									 message:SHKLocalizedString(@"We could not shorten the URL.")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Continue")
						   otherButtonTitles:nil] autorelease] show];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : item.title, [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] forKey:@"bitly-link"];
	}
	
	else
	{		
		///if already a bitly login, use url instead
		if ([result isEqualToString:@"ALREADY_A_BITLY_LINK"])
			result = [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		[item setCustomValue:[NSString stringWithFormat:@"%@ %@", item.text ? item.text : item.title, result] forKey:@"bitly-link"];
	}
	
	[self sendMail];
}

#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{
	self.quiet = YES;
	
	if (![self validateItem])
		return NO;
	
	return [self sendMail]; // Put the actual sending action in another method to make subclassing SHKMail easier
}

- (BOOL)sendMail
{	
	SHKMailComposeViewController *mailController = [[[SHKMailComposeViewController alloc] init] autorelease];
                                                    
	if (!mailController) {
		// e.g. no mail account registered (will show alert)
		[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
		return YES;
	}
	
	mailController.mailComposeDelegate = self;
	
	NSString *body = [item customValueForKey:@"body"];
	
	if (body == nil)
	{
		if (item.text != nil)
			body = item.text;
		
        if ([item customValueForKey:@"bitly-link"] != nil) {
			
			if (body != nil) {
				body = [body stringByAppendingFormat:@"<br/><br/>%@",[item customValueForKey:@"bitly-link"]];
			} else {
				body = [item customValueForKey:@"bitly-link"];
			}
			
		}
        		
		if (item.data)
		{
			NSString *attachedStr = SHKLocalizedString(@"Attached: %@", item.title ? item.title : item.filename);
			
			if (body != nil)
				body = [body stringByAppendingFormat:@"<br/><br/>%@", attachedStr];
			
			else
				body = attachedStr;
		}
		
		// fallback
		if (body == nil)
			body = @"";
		
		// sig
		if ([SHKCONFIG(sharedWithSignature) boolValue])
		{
			body = [body stringByAppendingString:@"<br/><br/>"];
			body = [body stringByAppendingString:SHKLocalizedString(@"Sent from %@", SHKCONFIG(appName))];
		}
		
		// save changes to body
		[item setCustomValue:body forKey:@"body"];
	}
	
	if (item.data)		
		[mailController addAttachmentData:item.data mimeType:item.mimeType fileName:item.filename];
	
	if (item.image){
		float jpgQuality = 1;
		if ([item customValueForKey:@"jpgQuality"] != nil) {
			jpgQuality = [[item customValueForKey:@"jpgQuality"] floatValue];
		}
		[mailController addAttachmentData:UIImageJPEGRepresentation(item.image, jpgQuality) mimeType:@"image/jpeg" fileName:@"Image.jpg"];
	}
	
	[mailController setSubject:item.title];
	[mailController setMessageBody:body isHTML:YES];
			
	[[SHK currentHelper] showViewController:mailController];
	
	return YES;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
	
	switch (result) 
	{
		case MFMailComposeResultSent:
			[self sendDidFinish];
			break;
		case MFMailComposeResultSaved:
			[self sendDidFinish];
			break;
		case MFMailComposeResultCancelled:
			[self sendDidCancel];
			break;
		case MFMailComposeResultFailed:
			[self sendDidFailWithError:nil];
			break;
	}
}


@end
