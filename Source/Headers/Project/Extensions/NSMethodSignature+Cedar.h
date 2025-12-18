#import <Foundation/Foundation.h>

// Helper function to strip problematic type encodings
NSString *cdr_stripProblematicEncodings(const char *typeEncoding);

@interface NSMethodSignature (Cedar)

+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block;
+ (NSMethodSignature *)cdr_sanitizedSignatureFromSignature:(NSMethodSignature *)signature;
- (NSMethodSignature *)cdr_signatureWithoutSelectorArgument;

@end
