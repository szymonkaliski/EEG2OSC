//
//  AppDelegate.h
//  EEG2OSC
//
//  Created by Szymon Kaliski on 14/04/14.
//  Copyright (c) 2014 Szymon Kaliski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "F53OSC.h"

#import "edk.h"
#import "edkErrorCode.h"
#import "EmoStateDLL.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	EmoEngineEventHandle eEvent;
	EmoStateHandle eState;
	DataHandle hData;
	unsigned int userID;
	
	F53OSCClient *oscClient;
	
	NSString *ipAddress;
	int port;
	
	bool isConnected, isRunning;
}

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSTextField *ipField;
@property (weak) IBOutlet NSTextField *portField;

- (IBAction)runButtonClicked:(id)sender;

@end
