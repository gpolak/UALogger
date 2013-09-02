//
//  UALogger.m
//
//  Created by Matt Coneybeare on 09/1/13.
//  Copyright (c) 2013 Urban Apps, LLC. All rights reserved.
//

#import "UALogger.h"

#import <asl.h>


// We use static class vars because UALogger only has class methods
static BOOL		UA__shouldLogInProduction = NO;
static BOOL		UA__shouldLogInDebug	  = YES;
static NSString *UA__verbosityFormatPlain = nil;
static NSString *UA__verbosityFormatBasic = nil;
static NSString *UA__verbosityFormatFull = nil;
static NSString *UA__bundleName = nil;
static NSString *UA__userDefaultsKey = nil;


@implementation UALogger


#pragma mark - Setup

+ (void)initialize {
	[super initialize];
	[self setupDefaultFormats];
}

+ (void)setupDefaultFormats {
	// Setup default formats
	
	// UALoggerVerbosityPlain is simple called with:
	//
	// 1. [NSString stringWithFormat:(s), ##__VA_ARGS__]:
	//
	[UALogger setFormat:@"%@" forVerbosity:UALoggerVerbosityPlain];
	
	
	// UALoggerVerbosityBasic is formatted with arguments passed in this order:
	//
	//	1. [[NSString stringWithUTF8String:__FILE__] lastPathComponent]
	//	2. [NSNumber numberWithInt:__LINE__]
	//	3. [NSString stringWithFormat:(s), ##__VA_ARGS__] ]
	//
	[UALogger setFormat:@"<%@:%@> %@" forVerbosity:UALoggerVerbosityBasic];
	
	
	// UALoggerVerbosityFull is formatted with arguments passed in this order:
	//
	//	1. self
	//	2. [[NSString stringWithUTF8String:__FILE__] lastPathComponent]
	//	3. [NSNumber numberWithInt:__LINE__]
	//	4. NSStringFromSelector(_cmd)
	//	5. [NSString stringWithFormat:(s), ##__VA_ARGS__]
	//
	[UALogger setFormat:@"<%p %@:%@ (%@)> %@" forVerbosity:UALoggerVerbosityFull];
}

+ (NSString *)formatForVerbosity:(UALoggerVerbosity)verbosity {
	switch (verbosity) {
		case UALoggerVerbosityNone:		return nil;
		case UALoggerVerbosityPlain:	return UA__verbosityFormatPlain;
		case UALoggerVerbosityBasic:	return UA__verbosityFormatBasic;
		case UALoggerVerbosityFull:		return UA__verbosityFormatFull;
		default:
			return nil;
	}
}

+ (void)resetDefaultLogFormats {
	[self setupDefaultFormats];
}

+ (BOOL)shouldLogInProduction {
	return UA__shouldLogInProduction;
}

+ (void)setShouldLogInProduction:(BOOL)shouldLogInProduction {
	UA__shouldLogInProduction = shouldLogInProduction;
}

+ (BOOL)shouldLogInDebug {
	return UA__shouldLogInDebug;
}

+ (void)setShouldLogInDebug:(BOOL)shouldLogInDebug {
	UA__shouldLogInDebug = shouldLogInDebug;
}

+ (void)setFormat:(NSString *)format forVerbosity:(UALoggerVerbosity)verbosity {
	switch (verbosity) {
		case UALoggerVerbosityNone: return;
		case UALoggerVerbosityPlain:
			UA__verbosityFormatPlain = format;
			break;
		case UALoggerVerbosityBasic:
			UA__verbosityFormatBasic = format;
			break;
		case UALoggerVerbosityFull:
			UA__verbosityFormatFull = format;
			break;
	}
}

#pragma mark - Logging

+ (BOOL)isProduction {
#ifdef DEBUG // Only log on the app store if the debug setting is enabled in settings
	return NO;
#else
	return YES;
#endif
}

+ (BOOL)loggingEnabled {
	// True if...
	return (![UALogger isProduction] && [UALogger shouldLogInDebug]) ||					// Debug and logging is enabled in debug OR
		   ([UALogger isProduction] && [UALogger shouldLogInProduction]) ||				// Production and logging is enabled in production OR
		   ([[NSUserDefaults standardUserDefaults] boolForKey:[self userDefaultsKey]]);	// the User Defaults override is set.
}

+ (void)logWithVerbosity:(UALoggerVerbosity)verbosity formatArgs:(NSArray *)args {
	
	if (UALoggerVerbosityNone == verbosity)
		return;
	

	[UALogger log:[self formatForVerbosity:verbosity],
				  [args count] >= 1 ? [args objectAtIndex:0] : nil,
				  [args count] >= 2 ? [args objectAtIndex:1] : nil,
				  [args count] >= 3 ? [args objectAtIndex:2] : nil,
				  [args count] >= 4 ? [args objectAtIndex:3] : nil,
				  [args count] >= 5 ? [args objectAtIndex:4] : nil,
				  [args count] >= 6 ? [args objectAtIndex:5] : nil,
				  [args count] >= 7 ? [args objectAtIndex:6] : nil,
				  [args count] >= 8 ? [args objectAtIndex:7] : nil,
				  [args count] >= 9 ? [args objectAtIndex:8] : nil
	 ];
}

+ (void)log:(NSString *)format, ... {
	
	@try {
		if ([UALogger loggingEnabled]) {
            if (format != nil) {
                va_list args;
                va_start(args, format);
                NSLogv(format, args);
                va_end(args);
            }
        }
    } @catch (...) {
        NSLogv(@"Caught an exception in UALogger", nil);
    }

}


#pragma mark - Application Log Collection

+ (NSString *)bundleName {
	if (!UA__bundleName)
		UA__bundleName = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	return UA__bundleName;
}

+ (void)setBundleName:(NSString *)bundleName {
	UA__bundleName = bundleName;
}


+ (NSString *)userDefaultsKey {
	if (!UA__userDefaultsKey)
		UA__userDefaultsKey = UALogger_LoggingEnabled;
	
	return UA__userDefaultsKey;
}

+ (void)setUserDefaultsKey:(NSString *)userDefaultsKey {
	UA__userDefaultsKey = userDefaultsKey;
}


+ (NSArray *)getConsoleLogEntriesForBundleName:(NSString *)bundleName {
	NSMutableArray *logs = [NSMutableArray array];
	
	aslmsg q, m;
	int i;
	const char *key, *val;
	
	NSString *queryTerm = bundleName;
	
	q = asl_new(ASL_TYPE_QUERY);
	asl_set_query(q, ASL_KEY_SENDER, [queryTerm UTF8String], ASL_QUERY_OP_EQUAL);
	
	aslresponse r = asl_search(NULL, q);
	while (NULL != (m = aslresponse_next(r))) {
		NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
		
		for (i = 0; (NULL != (key = asl_key(m, i))); i++) {
			NSString *keyString = [NSString stringWithUTF8String:(char *)key];
			
			val = asl_get(m, key);
			
			NSString *string = [NSString stringWithUTF8String:val];
			[tmpDict setObject:string forKey:keyString];
		}
		
		NSString *message = [tmpDict objectForKey:@"Message"];
		if (message)
			[logs addObject:message];
		
	}
	aslresponse_free(r);
	
	return logs;
}

+ (void)getApplicationLog:(void (^)(NSArray *logs))onComplete {
	dispatch_queue_t backgroundQueue = dispatch_queue_create("com.urbanapps.ualogger", 0);
	dispatch_async(backgroundQueue, ^{
		NSArray *logs = [UALogger getConsoleLogEntriesForBundleName:[self bundleName]];
		onComplete(logs);
	});
}

+ (NSString *)applicationLog {
	NSArray *logs = [UALogger getConsoleLogEntriesForBundleName:[self bundleName]];
	return [logs componentsJoinedByString:@"\n"];
}


@end
