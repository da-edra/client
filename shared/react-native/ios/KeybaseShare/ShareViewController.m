//
//  ShareViewController.m
//  KeybaseShare
//
//  Created by Michael Maxim on 8/31/18.
//  Copyright © 2018 Keybase. All rights reserved.
//

#import "ShareViewController.h"
#import "keybase/keybase.h"
#import "Pusher.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "Fs.h"

#if TARGET_OS_SIMULATOR
const BOOL isSimulator = YES;
#else
const BOOL isSimulator = NO;
#endif


@interface ShareViewController ()
@property NSDictionary* convTarget;
@property BOOL hasInited;
@end

@implementation ShareViewController

- (BOOL)isContentValid {
    return YES;
}

- (void)presentationAnimationDidFinish {
  NSError* error = nil;
  NSDictionary* fsPaths = [[FsHelper alloc] setupFs:YES setupSharedHome:NO];
  KeybaseExtensionInit(fsPaths[@"home"], fsPaths[@"sharedHome"], fsPaths[@"logFile"], @"prod", isSimulator, NULL, NULL, &error);
  if (error != nil) {
    NSLog(@"Failed to init: %@", error);
    InitFailedViewController* initFailed = [InitFailedViewController alloc];
    [initFailed setDelegate:self];
    [self pushConfigurationViewController:initFailed];
    return;
  }
  [self setHasInited:YES];
  
  NSString* jsonSavedConv = KeybaseExtensionGetSavedConv();
  if ([jsonSavedConv length] > 0) {
    NSData* data = [jsonSavedConv dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* conv = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
    if (!conv) {
      NSLog(@"failed to parse saved conv: %@", error);
    } else {
      [self setConvTarget:conv];
      [self reloadConfigurationItems];
    }
  }
}

-(void)initFailedClosed {
  [self cancel];
}

- (NSItemProvider*)firstSatisfiesTypeIdentifierCond:(NSArray*)attachments cond:(BOOL (^)(NSItemProvider*))cond {
  for (NSItemProvider* a in attachments) {
    if (cond(a)) {
      return a;
    }
  }
  return nil;
}

- (NSMutableArray*)allSatisfiesTypeIdentifierCond:(NSArray*)attachments cond:(BOOL (^)(NSItemProvider*))cond {
  NSMutableArray* res = [NSMutableArray array];
  for (NSItemProvider* a in attachments) {
    if (cond(a)) {
      [res addObject:a];
    }
  }
  return res;
}

- (BOOL)isRealURL:(NSItemProvider*)item {
  return (BOOL)([item hasItemConformingToTypeIdentifier:@"public.url"] && ![item hasItemConformingToTypeIdentifier:@"public.file-url"]);
}

- (NSArray*)getSendableAttachments {
  NSExtensionItem *input = self.extensionContext.inputItems.firstObject;
  NSArray* attachments = [input attachments];
  NSMutableArray* res = [NSMutableArray array];
  NSItemProvider* item = [self firstSatisfiesTypeIdentifierCond:attachments cond:^(NSItemProvider* a) {
    return [self isRealURL:a];
  }];
  if (item) {
   [res addObject:item];
  }
  if ([res count] == 0) {
    item = [self firstSatisfiesTypeIdentifierCond:attachments cond:^(NSItemProvider* a) {
      return (BOOL)([a hasItemConformingToTypeIdentifier:@"public.text"]);
    }];
    if (item) {
      [res addObject:item];
    }
  }
  if ([res count] == 0) {
    res = [self allSatisfiesTypeIdentifierCond:attachments cond:^(NSItemProvider* a) {
      return (BOOL)([a hasItemConformingToTypeIdentifier:@"public.image"] || [a hasItemConformingToTypeIdentifier:@"public.movie"]);
    }];
  }
  if([res count] == 0 && attachments.firstObject != nil) {
    [res addObject:attachments.firstObject];
  }
  return res;
}

- (UIView*)loadPreviewView {
  NSArray* items = [self getSendableAttachments];
  if ([items count] == 0) {
    return [super loadPreviewView];
  }
  NSItemProvider* item = items[0];
  if ([self isRealURL:item]) {
    [item loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:^(NSURL *url, NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView setText:[NSString stringWithFormat:@"%@\n%@", self.contentText, [url absoluteString]]];
      });
    }];
    return nil;
  }
  return [super loadPreviewView];
}

- (void)didReceiveMemoryWarning {
    KeybaseExtensionForceGC();
    [super didReceiveMemoryWarning];
}

- (void)createVideoPreview:(NSURL*)url resultCb:(void (^)(int,int,int,int,int,NSData*))resultCb  {
  NSError *error = NULL;
  CMTime time = CMTimeMake(1, 1);
  AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
  AVAssetImageGenerator *generateImg = [[AVAssetImageGenerator alloc] initWithAsset:asset];
  [generateImg setAppliesPreferredTrackTransform:YES];
  CGImageRef cgOriginal = [generateImg copyCGImageAtTime:time actualTime:NULL error:&error];
  [generateImg setMaximumSize:CGSizeMake(640, 640)];
  CGImageRef cgThumb = [generateImg copyCGImageAtTime:time actualTime:NULL error:&error];
  int duration = CMTimeGetSeconds([asset duration]);
  UIImage* original = [UIImage imageWithCGImage:cgOriginal];
  UIImage* scaled = [UIImage imageWithCGImage:cgThumb];
  NSData* preview = UIImageJPEGRepresentation(scaled, 0.7);
  resultCb(duration, original.size.width, original.size.height, scaled.size.width, scaled.size.height, preview);
  CGImageRelease(cgOriginal);
  CGImageRelease(cgThumb);
}

- (void)createImagePreview:(NSURL*)url resultCb:(void (^)(int,int,int,int,NSData*))resultCb  {
  UIImage* original = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
  CFURLRef cfurl = CFBridgingRetain(url);
  CGImageSourceRef is = CGImageSourceCreateWithURL(cfurl, nil);
  NSDictionary* opts = [[NSDictionary alloc] initWithObjectsAndKeys:
                        (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
                        (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
                        [NSNumber numberWithInt:640], (id)kCGImageSourceThumbnailMaxPixelSize,
                        nil];
  CGImageRef image = CGImageSourceCreateThumbnailAtIndex(is, 0, (CFDictionaryRef)opts);
  UIImage* scaled = [UIImage imageWithCGImage:image];
  NSData* preview = UIImageJPEGRepresentation(scaled, 0.7);
  resultCb(original.size.width, original.size.height, scaled.size.width, scaled.size.height, preview);
  CGImageRelease(image);
  CFRelease(cfurl);
  CFRelease(is);
}

- (void) maybeCompleteRequest:(BOOL)lastItem {
  if (!lastItem) { return; }
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.extensionContext completeRequestReturningItems:nil completionHandler:nil];
  });
}

- (void)processItem:(NSItemProvider*)item lastItem:(BOOL)lastItem {
  PushNotifier* pusher = [[PushNotifier alloc] init];
  NSString* convID = self.convTarget[@"ConvID"];
  NSString* name = self.convTarget[@"Name"];
  NSNumber* membersType = self.convTarget[@"MembersType"];
  NSItemProviderCompletionHandler urlHandler = ^(NSURL* url, NSError* error) {
    KeybaseExtensionPostText(convID, name, NO, [membersType longValue], self.contentText, pusher, &error);
    [self maybeCompleteRequest:lastItem];
  };
  
  NSItemProviderCompletionHandler textHandler = ^(NSString* text, NSError* error) {
    KeybaseExtensionPostText(convID, name, NO, [membersType longValue], text, pusher, &error);
    [self maybeCompleteRequest:lastItem];
  };
  
  NSItemProviderCompletionHandler fileHandler = ^(NSURL* url, NSError* error) {
    // Check for no URL
    if (url == nil) {
      [self maybeCompleteRequest:lastItem];
      return;
    }
    NSString* filePath = [url relativePath];
    if ([item hasItemConformingToTypeIdentifier:@"public.movie"]) {
      // Generate image preview here, since it runs out of memory easy in Go
      [self createVideoPreview:url resultCb:^(int duration, int baseWidth, int baseHeight, int previewWidth, int previewHeight, NSData* preview) {
        NSError* error = NULL;
        KeybaseExtensionPostVideo(convID, name, NO, [membersType longValue], self.contentText, filePath,
                                 duration, baseWidth, baseHeight, previewWidth, previewHeight, preview, pusher, &error);
      }];
    } else if ([item hasItemConformingToTypeIdentifier:@"public.image"]) {
      // Generate image preview here, since it runs out of memory easy in Go
      [self createImagePreview:url resultCb:^(int baseWidth, int baseHeight, int previewWidth, int previewHeight, NSData* preview) {
        NSError* error = NULL;
        KeybaseExtensionPostJPEG(convID, name, NO, [membersType longValue], self.contentText, filePath,
                                 baseWidth, baseHeight, previewWidth, previewHeight, preview, pusher, &error);
      }];
    }  else {
      NSError* error = NULL;
      KeybaseExtensionPostFile(convID, name, NO, [membersType longValue], self.contentText, filePath, pusher, &error);
    }
    [self maybeCompleteRequest:lastItem];
  };
  
  if ([item hasItemConformingToTypeIdentifier:@"public.movie"]) {
    [item loadItemForTypeIdentifier:@"public.movie" options:nil completionHandler:fileHandler];
  } else if ([item hasItemConformingToTypeIdentifier:@"public.image"]) {
    [item loadItemForTypeIdentifier:@"public.image" options:nil completionHandler:fileHandler];
  } else if ([item hasItemConformingToTypeIdentifier:@"public.file-url"]) {
    [item loadItemForTypeIdentifier:@"public.file-url" options:nil completionHandler:fileHandler];
  } else if ([item hasItemConformingToTypeIdentifier:@"public.text"]) {
    [item loadItemForTypeIdentifier:@"public.text" options:nil completionHandler:textHandler];
  } else if ([item hasItemConformingToTypeIdentifier:@"public.url"]) {
    [item loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:urlHandler];
  } else {
    [pusher localNotification:@"extension" msg:@"We failed to send your message. Please try from the Keybase app."
                   badgeCount:-1 soundName:@"default" convID:@"" typ:@"chat.extension"];
    [self maybeCompleteRequest:lastItem];
  }
}

- (void)didSelectPost {
  if (!self.convTarget) {
    [self maybeCompleteRequest:YES];
    return;
  }
  NSArray* items = [self getSendableAttachments];
  if ([items count] == 0) {
    [self maybeCompleteRequest:YES];
    return;
  }
  for (int i = 0; i < [items count]; i++) {
    BOOL lastItem = (BOOL)(i == [items count]-1);
    [self processItem:items[i] lastItem:lastItem];
  }
}

- (NSArray *)configurationItems {
  SLComposeSheetConfigurationItem *item = [[SLComposeSheetConfigurationItem alloc] init];
  item.title = @"Share to...";
  item.valuePending = !self.hasInited;
  if (self.convTarget) {
    item.value = self.convTarget[@"Name"];
  } else if (self.hasInited) {
    item.value = @"Please choose";
  }
  item.tapHandler = ^{
    ConversationViewController *viewController = [[ConversationViewController alloc] initWithStyle:UITableViewStylePlain];
    viewController.delegate = self;
    [self pushConfigurationViewController:viewController];
  };
  return @[item];
}

- (void)convSelected:(NSDictionary *)conv {
  [self setConvTarget:conv];
  [self reloadConfigurationItems];
  [self popConfigurationViewController];
}

@end
