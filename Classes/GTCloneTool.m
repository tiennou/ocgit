//
//  clone.c
//  ocgit
//
//  Created by Etienne on 12/11/13.
//  Copyright (c) 2013 tiennou. All rights reserved.
//

#import "GTCLITool.h"
#import <ObjectiveGit/GTCredential.h>

@interface GTCloneTool : GTCLITool <GTCLITool>

@end

@implementation GTCloneTool

+ (NSString *)toolName { return @"clone"; }

- (BOOL)performCommandWithArguments:(NSMutableArray *)arguments options:(NSArray *)options error:(NSError **)error {
    NSArray *commandOptions = [self.class parseOptions:arguments error:error];
    if (commandOptions.count != 0) {
        if (error) {
            *error = [NSError errorWithDomain:GTCLIDomainError code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unhandled options"}];
        }
        return NO;
    }

    if (arguments.count < 1 || arguments.count > 2) {
        if (error) *error = [NSError errorWithDomain:GTCLIDomainError code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid arguments"}];
        return NO;
    }

    NSURL *currentWorkingURL = [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath
                                          isDirectory:YES];

    // Parse arguments:
    // 1 - Let's parse our origin repository, first trying a local path,
    // then accepting it as a URL
    NSURL *repoURL = nil;
    NSString *repoURLString = arguments[0];
    if ([repoURLString hasPrefix:@"http://"]
        || [repoURLString hasPrefix:@"https://"]
        || [repoURLString hasPrefix:@"ssh://"]
        || [repoURLString hasPrefix:@"git://"]) {
        repoURL = [NSURL URLWithString:arguments[0]];
    } else {
        [NSURL fileURLWithPath:repoURLString];
    }

    // 2 - working directory (optional)
    NSURL *workingDirectoryURL = nil;
    if (arguments.count == 1) {
        // Use the repo URL to make a name for our working copy
        NSString *workingDirectoryName = repoURL.lastPathComponent;
        workingDirectoryURL = [currentWorkingURL URLByAppendingPathComponent:workingDirectoryName];
    } else if (arguments.count == 2) {
        // Use our 2nd argument to make our working copy name
        workingDirectoryURL = [currentWorkingURL URLByAppendingPathComponent:arguments[1]];
        workingDirectoryURL = [workingDirectoryURL URLByDeletingPathExtension]; // .git
    }

    if (repoURL == nil || workingDirectoryURL == nil) {
        if (error) *error = [NSError errorWithDomain:GTCLIDomainError code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid arguments"}];
        return NO;
    }

    // Create the working directory if it doesn't exist
    BOOL success = [NSFileManager.defaultManager createDirectoryAtURL:workingDirectoryURL
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:error];
    if (!success) {
        return NO;
    }

    GTCredentialProvider *provider = [self.class credentialProviderWithArguments:arguments error:error];

    NSDictionary *cloneOptions = @{ GTRepositoryCloneOptionsCredentialProvider: provider, };

    GTRepository *repo = [GTRepository cloneFromURL:repoURL
                                 toWorkingDirectory:workingDirectoryURL
                                            options:cloneOptions
                                              error:error
                              transferProgressBlock:^(const git_transfer_progress *stats) {
                          NSLog(@"Transferring objects: %d total, %d indexed, %d received in %ld bytes", stats->total_objects, stats->indexed_objects, stats->received_objects, stats->received_bytes);
                          }
                              checkoutProgressBlock:^(NSString *path, NSUInteger completedSteps, NSUInteger totalSteps) {
                          NSLog(@"Checking out %@, %ld/%ld", path, completedSteps, totalSteps);
                          }];

    return (repo != nil);
}

@end