#import <Foundation/Foundation.h>

@interface NSMethodSignature (Cedar)

+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block;
+ (NSMethodSignature *)cdr_sanitizedSignatureFromSignature:(NSMethodSignature *)signature;
- (NSMethodSignature *)cdr_signatureWithoutSelectorArgument;

@end
