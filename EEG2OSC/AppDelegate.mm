//
//  AppDelegate.mm
//  EEG2OSC
//
//  Created by Szymon Kaliski on 14/04/14.
//  Copyright (c) 2014 Szymon Kaliski. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize portField, serverFied, ipField;

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
	posX = 0;
	posY = 0;

	eEvent = EE_EmoEngineEventCreate();
	eState = EE_EmoStateCreate();

	oscClient = [[F53OSCClient alloc] init];
	oscServer = [[F53OSCServer alloc] init];
	[oscServer setPort:[serverFied intValue]];
	[oscServer setDelegate:self];

	isConnected = (EE_EngineConnect() == EDK_OK);
	isRunning = false;

	NSLog(@"isConnected: %d", isConnected);

	if (isConnected) {
		hData = EE_DataCreate();
		EE_DataSetBufferSizeInSec(timerInterval);

		EE_CognitivSetActiveActions(userID, COG_NEUTRAL | COG_LIFT);

		[NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(runEEG) userInfo:NULL repeats:YES];
	}
}

- (void)takeMessage:(F53OSCMessage *)trainMessage {
	if (isRunning) {
		NSString *address = [trainMessage addressPattern];
		NSArray *arguments = [trainMessage arguments];
		NSLog(@"OSC in: %@ %@", address, [arguments componentsJoinedByString:@", "]);

		if ([address isEqualToString:@"/train/neutral"]) {
			EE_CognitivSetTrainingAction(userID, COG_NEUTRAL);
			EE_CognitivSetTrainingControl(userID, COG_START);
		}

		if ([address isEqualToString:@"/train/lift"]) {
			EE_CognitivSetTrainingAction(userID, COG_LIFT);
			EE_CognitivSetTrainingControl(userID, COG_START);
		}

		if ([address isEqualToString:@"/train/accept"]) {
			EE_CognitivSetTrainingControl(userID, COG_ACCEPT);
		}

		if ([address isEqualToString:@"/train/reject"]) {
			EE_CognitivSetTrainingControl(userID, COG_REJECT);
		}
	}
}

- (IBAction)runButtonClicked:(id)sender {
	isRunning = [(NSButton *)sender state];

	ipAddress = [[NSString alloc] initWithString:[ipField stringValue]];
	port = [portField intValue];

	[oscServer stopListening];
	[oscServer setPort:[serverFied intValue]];

	if (isRunning) {
		[oscServer startListening];

		// don't nap if running in background
		if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)]) {
			[self setActivity:[[NSProcessInfo processInfo] beginActivityWithOptions:0x00FFFFFF reason:@"OSC"]];
		}

		NSLog(@"Running: %@:%d (server: %d)", ipAddress, port, [oscServer port]);
	}
}

- (void)runEEG {
	if (isRunning && EE_EngineGetNextEvent(eEvent) == EDK_OK) {
		EE_Event_t eventType = EE_EmoEngineEventGetType(eEvent);
		EE_EmoEngineEventGetUserId(eEvent, &userID);

		// user add event
		if (eventType == EE_UserAdded) {
			EE_DataAcquisitionEnable(userID, TRUE);
			NSLog(@"User added with ID: %d", userID);
		}

		// emo state updated
		if (eventType == EE_EmoStateUpdated) {
			// EEG data
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

						message = [F53OSCMessage messageWithAddressPattern:address arguments:@[ value ]];
						[oscClient sendPacket:message toHost:ipAddress onPort:port];
					}
				}
				delete[] ddata;
			}

			// Cognitiv data
			EE_EmoEngineEventGetEmoState(eEvent, eState);

			int actionType = ES_CognitivGetCurrentAction(eState);
			float actionPower = ES_CognitivGetCurrentActionPower(eState);
			NSString *messageAction;

			switch (actionType) {
				case COG_NEUTRAL: messageAction = @"neutral"; break;
				case COG_LIFT: messageAction = @"lift"; break;
				default: break;
			}

			if (messageAction && actionPower > 0) {
				NSLog(@"emo action text: %@ (%f)", messageAction, actionPower);

				message = [F53OSCMessage messageWithAddressPattern:@"/cognitiv/action" arguments:@[ messageAction, [NSNumber numberWithFloat:actionPower] ]];
				[oscClient sendPacket:message toHost:ipAddress onPort:port];
			}

			// Affectiv data
			float engagementBoredom = ES_AffectivGetEngagementBoredomScore(eState);
			float excitementLongTerm = ES_AffectivGetExcitementLongTermScore(eState);
			float excitementShortTem = ES_AffectivGetExcitementShortTermScore(eState);
			float frustration = ES_AffectivGetFrustrationScore(eState);
			float meditation = ES_AffectivGetMeditationScore(eState);

			message = [F53OSCMessage messageWithAddressPattern:@"/affectiv/engagement" arguments:@[ [NSNumber numberWithFloat:engagementBoredom] ]];
			[oscClient sendPacket:message toHost:ipAddress onPort:port];

			message = [F53OSCMessage messageWithAddressPattern:@"/affectiv/excitement-long" arguments:@[ [NSNumber numberWithFloat:excitementLongTerm] ]];
			[oscClient sendPacket:message toHost:ipAddress onPort:port];

			message = [F53OSCMessage messageWithAddressPattern:@"/affectiv/excitement-short" arguments:@[ [NSNumber numberWithFloat:excitementShortTem] ]];
			[oscClient sendPacket:message toHost:ipAddress onPort:port];

			message = [F53OSCMessage messageWithAddressPattern:@"/affectiv/frustration" arguments:@[ [NSNumber numberWithFloat:frustration] ]];
			[oscClient sendPacket:message toHost:ipAddress onPort:port];

			message = [F53OSCMessage messageWithAddressPattern:@"/affectiv/meditation" arguments:@[ [NSNumber numberWithFloat:meditation] ]];
			[oscClient sendPacket:message toHost:ipAddress onPort:port];
		}

		// Expressiv data
		int blinkStatus = ES_ExpressivIsBlink(eState);
		message = [F53OSCMessage messageWithAddressPattern:@"/expressiv/blink" arguments:@[ [NSNumber numberWithInt:blinkStatus] ]];
		[oscClient sendPacket:message toHost:ipAddress onPort:port];

		// Cognitiv event
		if (eventType == EE_CognitivEvent) {
			EE_CognitivEvent_t cognitiveEvent = EE_CognitivEventGetType(eEvent);
			NSString *messageText;

			switch (cognitiveEvent) {
				case EE_CognitivTrainingStarted: messageText = @"training started"; break;
				case EE_CognitivTrainingSucceeded: messageText = @"training succeeded"; break;
				case EE_CognitivTrainingFailed: messageText = @"training failed"; break;
				case EE_CognitivTrainingCompleted: messageText = @"training completed"; break;
				case EE_CognitivTrainingRejected: messageText = @"training rejected"; break;
				case EE_CognitivAutoSamplingNeutralCompleted: messageText = @"auto sampling completed"; break;
				case EE_CognitivSignatureUpdated: messageText = @"signature updated"; break;
				case EE_CognitivNoEvent: NSLog(@"no cognitiv event..."); break;
				default: break;
			}

			NSLog(@"cognitiv event: %@", messageText);

			if (messageText) {
				message = [F53OSCMessage messageWithAddressPattern:@"/cognitiv/event" arguments:@[messageText]];
				[oscClient sendPacket:message toHost:ipAddress onPort:port];
			}
		}

		// Signal quality
		int numChannels = 14;
		EE_EEG_ContactQuality_t contactQuality[numChannels];
		ES_GetContactQualityFromAllChannels(eState, contactQuality, numChannels);

		NSMutableArray *contactQualites = [[NSMutableArray alloc] init];
		for (int i = 0; i < numChannels; ++i) {
//			NSLog(@"contact quality for %d: %d", i, contactQuality[i]);
			[contactQualites addObject:[NSNumber numberWithInt:contactQuality[i]]];
		}

		message = [F53OSCMessage messageWithAddressPattern:@"/quality" arguments:contactQualites];
		[oscClient sendPacket:message toHost:ipAddress onPort:port];

		// Gyro data
		int gyroX, gyroY;
		EE_HeadsetGetGyroDelta(userID, &gyroX, &gyroY);
		posX += gyroX;
		posY += gyroY;
		message = [F53OSCMessage messageWithAddressPattern:@"/gyro" arguments:@[ [NSNumber numberWithInt:posX], [NSNumber numberWithInt:posY] ]];
		[oscClient sendPacket:message toHost:ipAddress onPort:port];
	}
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

@end
