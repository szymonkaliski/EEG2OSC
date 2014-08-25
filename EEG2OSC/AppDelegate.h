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

@interface AppDelegate : NSObject <NSApplicationDelegate, F53OSCPacketDestination> {
	EmoEngineEventHandle eEvent;
	EmoStateHandle eState;
	DataHandle hData;
	unsigned int userID;
	int posX, posY;
	float timerInterval;
	
	F53OSCClient *oscClient;
	F53OSCServer *oscServer;
	F53OSCMessage *message;
	
	NSString *ipAddress;
	int port;
	
	bool isConnected, isRunning;
}

@property (strong) id activity;

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSTextField *ipField;
@property (weak) IBOutlet NSTextField *portField;
@property (weak) IBOutlet NSTextField *serverFied;
@property (weak) IBOutlet NSMatrix *inputType;
@property (weak) IBOutlet NSTextField *infoLabel;

- (IBAction)runButtonClicked:(id)sender;

@end
