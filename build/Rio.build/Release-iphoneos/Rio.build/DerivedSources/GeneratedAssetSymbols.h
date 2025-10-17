#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"app.amorfati.Rio";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "Base" asset catalog color resource.
static NSString * const ACColorNameBase AC_SWIFT_PRIVATE = @"Base";

/// The "Theme2/inboundBubble" asset catalog color resource.
static NSString * const ACColorNameTheme2InboundBubble AC_SWIFT_PRIVATE = @"Theme2/inboundBubble";

/// The "Theme1/inboundBubble" asset catalog color resource.
static NSString * const ACColorNameTheme1InboundBubble AC_SWIFT_PRIVATE = @"Theme1/inboundBubble";

/// The "Default/inboundBubble" asset catalog color resource.
static NSString * const ACColorNameDefaultInboundBubble AC_SWIFT_PRIVATE = @"Default/inboundBubble";

/// The "Theme1/outboundBubble" asset catalog color resource.
static NSString * const ACColorNameTheme1OutboundBubble AC_SWIFT_PRIVATE = @"Theme1/outboundBubble";

/// The "Default/outboundBubble" asset catalog color resource.
static NSString * const ACColorNameDefaultOutboundBubble AC_SWIFT_PRIVATE = @"Default/outboundBubble";

/// The "Theme2/outboundBubble" asset catalog color resource.
static NSString * const ACColorNameTheme2OutboundBubble AC_SWIFT_PRIVATE = @"Theme2/outboundBubble";

/// The "ownBubble" asset catalog color resource.
static NSString * const ACColorNameOwnBubble AC_SWIFT_PRIVATE = @"ownBubble";

/// The "amy" asset catalog image resource.
static NSString * const ACImageNameAmy AC_SWIFT_PRIVATE = @"amy";

/// The "cartouche" asset catalog image resource.
static NSString * const ACImageNameCartouche AC_SWIFT_PRIVATE = @"cartouche";

/// The "edward" asset catalog image resource.
static NSString * const ACImageNameEdward AC_SWIFT_PRIVATE = @"edward";

/// The "joaquin" asset catalog image resource.
static NSString * const ACImageNameJoaquin AC_SWIFT_PRIVATE = @"joaquin";

/// The "read" asset catalog image resource.
static NSString * const ACImageNameRead AC_SWIFT_PRIVATE = @"read";

/// The "scarlet" asset catalog image resource.
static NSString * const ACImageNameScarlet AC_SWIFT_PRIVATE = @"scarlet";

#undef AC_SWIFT_PRIVATE
