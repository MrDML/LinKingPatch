#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "LEPatchManager.h"
#import "WHC_DownloadObject.h"
#import "WHC_BaseOperation.h"
#import "WHC_DownloadOperation.h"
#import "WHC_HttpManager.h"
#import "WHC_HttpOperation.h"
#import "WHC_DownloadSessionTask.h"
#import "WHC_SessionDownloadManager.h"
#import "Reachability.h"
#import "UIButton+WHC_HttpButton.h"
#import "UIImageView+WHC_HttpImageView.h"
#import "WHC_ImageCache.h"
#import "WHC_DataModel.h"
#import "WHC_Json.h"
#import "WHC_Xml.h"
#import "WHC_XMLParser.h"
#import "LinKingPatch.h"

FOUNDATION_EXPORT double LinKingPatchVersionNumber;
FOUNDATION_EXPORT const unsigned char LinKingPatchVersionString[];

