//
//  AppDelegate.mm
//  EEG2OSC
//
//  Created by Szymon Kaliski on 14/04/14.
//  Copyright (c) 2014 Szymon Kaliski. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize portField, ipField;

EE_DataChannel_t targetChannelList[] = {
	ED_COUNTER,
	ED_AF3, ED_F7, ED_F3, ED_FC5, ED_T7,
	ED_P7, ED_O1, ED_O2, ED_P8, ED_T8,
	ED_FC6, ED_F4, ED_F8, ED_AF4, ED_GYROX, ED_GYROY, ED_TIMESTAMP,
	ED_FUNC_ID, ED_FUNC_VALUE, ED_MARKER, ED_SYNC_SIGNAL
};

NSString* targetChannelNames[] = {
	@"ED_COUNTER",
	@"ED_AF3", @"ED_F7", @"ED_F3", @"ED_FC5", @"ED_T7",
	@"ED_P7", @"ED_O1", @"ED_O2", @"ED_P8", @"ED_T8",
	@"ED_FC6", @"ED_F4", @"ED_F8", @"ED_AF4", @"ED_GYROX", @"ED_GYROY", @"ED_TIMESTAMP",
	@"ED_FUNC_ID", @"ED_FUNC_VALUE", @"ED_MARKER", @"ED_SYNC_SIGNAL"
};

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	float timerInterval = 0.25;
	
	eEvent = EE_EmoEngineEventCreate();
	eState = EE_EmoStateCreate();
	
	oscClient = [[F53OSCClient alloc] init];
	
	isConnected = (EE_EngineConnect() == EDK_OK);
	isRunning = false;

	NSLog(@"isConnected: %d", isConnected);
	
	if (isConnected) {
		hData = EE_DataCreate();
		EE_DataSetBufferSizeInSec(timerInterval);
		
		[NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(runEEG) userInfo:NULL repeats:YES];
	}
}

- (IBAction)runButtonClicked:(id)sender {
	isRunning = [(NSButton *)sender state];
	
	ipAddress = [[NSString alloc] initWithString:[ipField stringValue]];
	port = [portField intValue];
	
	NSLog(@"%@:%d", ipAddress, port);
}

- (void)runEEG {
	if (isRunning) {
		int state = EE_EngineGetNextEvent(eEvent);
		if (state == EDK_OK) {
			EE_Event_t eventType = EE_EmoEngineEventGetType(eEvent);
			EE_EmoEngineEventGetUserId(eEvent, &userID);
			
			if (eventType == EE_UserAdded) {
				EE_DataAcquisitionEnable(userID, TRUE);
				NSLog(@"User added with ID: %d", userID);
			}
			
			if (eventType == EE_EmoStateUpdated) {
				EE_DataUpdateHandle(userID, hData);
				
				unsigned int nSamplesTaken = 0;
				EE_DataGetNumberOfSample(hData, &nSamplesTaken);
				
				if (nSamplesTaken != 0) {
					double* ddata = new double[nSamplesTaken];
					for (int sampleIdx = 0; sampleIdx < (int)nSamplesTaken; ++sampleIdx) {
						for (int i = 0; i < sizeof(targetChannelList) / sizeof(EE_DataChannel_t); i++) {
							EE_DataGet(hData, targetChannelList[i], ddata, nSamplesTaken);
							
							NSString *fieldName = targetChannelNames[i];
							NSString *address = [@"/EEG/" stringByAppendingString:fieldName];
							NSNumber *value = [NSNumber numberWithFloat:(float)ddata[i]];

//							NSLog(@"%@: %f", targetChannelNames[i], [value floatValue]);
							F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:@[value]];
							
							[oscClient sendPacket:message toHost:ipAddress onPort:port];
						}
					}
					delete[] ddata;
				}
			}
		}
	}
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

@end
