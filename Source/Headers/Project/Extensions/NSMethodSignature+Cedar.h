#import <Foundation/Foundation.h>

// Helper function to strip problematic type encodings


@interface NSMethodSignature (Cedar)

+ (NSString *) cdr_stripProblematicEncodings:(const char *)typeEncoding;
+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block;
+ (NSMethodSignature *)cdr_sanitizedSignatureFromSignature:(NSMethodSignature *)signature;
- (NSMethodSignature *)cdr_signatureWithoutSelectorArgument;

@end
