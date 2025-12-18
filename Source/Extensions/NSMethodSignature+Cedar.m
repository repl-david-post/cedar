#import "NSMethodSignature+Cedar.h"
#import "CDRBlockHelper.h"

static const char *Block_signature(id blockObj) {
    struct Block_literal *block = (struct Block_literal *)blockObj;
    union Block_descriptor_rest descriptor_rest = block->descriptor->rest;

    BOOL hasCopyDispose = !!(block->flags & (1<<25));

    const char *signature = hasCopyDispose ? descriptor_rest.layout_with_copy_dispose.signature : descriptor_rest.layout_without_copy_dispose.signature;

    return signature;
}

static NSString *cdr_stripProblematicEncodings(const char *typeEncoding) {
    NSString *typeEncodingString = [NSString stringWithUTF8String:typeEncoding];

    // Replace complex BOOL union encodings with simple 'B' (C++ bool)
    // This handles encodings like (?={?=CCCCCCCC}Q) that appear in newer Xcode versions
    NSRegularExpression *boolUnionPattern = [NSRegularExpression regularExpressionWithPattern:@"\\(\\?=\\{\\?=C+\\}[^)]*\\)" options:0 error:NULL];
    NSString *strippedTypeEncoding = [boolUnionPattern stringByReplacingMatchesInString:typeEncodingString options:0 range:NSMakeRange(0, [typeEncodingString length]) withTemplate:@"B"];

    // Strip quoted substrings (e.g., "name")
    NSRegularExpression *quotedPattern = [NSRegularExpression regularExpressionWithPattern:@"\".*?\"" options:0 error:NULL];
    strippedTypeEncoding = [quotedPattern stringByReplacingMatchesInString:strippedTypeEncoding options:0 range:NSMakeRange(0, [strippedTypeEncoding length]) withTemplate:@""];

    // Strip angle-bracketed content (e.g., <ProtocolName>)
    NSRegularExpression *angleBracketPattern = [NSRegularExpression regularExpressionWithPattern:@"<.*?>" options:0 error:NULL];
    strippedTypeEncoding = [angleBracketPattern stringByReplacingMatchesInString:strippedTypeEncoding options:0 range:NSMakeRange(0, [strippedTypeEncoding length]) withTemplate:@""];

    return strippedTypeEncoding;
}

@implementation NSMethodSignature (Cedar)

+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block {
    const char *signatureTypes = Block_signature(block);
    NSString *strippedSignatureTypeString = cdr_stripProblematicEncodings(signatureTypes);
    return [NSMethodSignature signatureWithObjCTypes:[strippedSignatureTypeString UTF8String]];
}

+ (NSMethodSignature *)cdr_sanitizedSignatureFromSignature:(NSMethodSignature *)signature {
    if (!signature) {
        return nil;
    }

    // Build a cleaned signature string from the original signature
    NSMutableString *cleanedSignatureString = [NSMutableString string];

    // Add the return type
    [cleanedSignatureString appendString:cdr_stripProblematicEncodings([signature methodReturnType])];

    // Add all argument types
    for (NSUInteger i = 0; i < [signature numberOfArguments]; i++) {
        [cleanedSignatureString appendString:cdr_stripProblematicEncodings([signature getArgumentTypeAtIndex:i])];
    }

    return [NSMethodSignature signatureWithObjCTypes:[cleanedSignatureString UTF8String]];
}

- (NSMethodSignature *)cdr_signatureWithoutSelectorArgument {
    NSAssert([self numberOfArguments]>1 && strcmp([self getArgumentTypeAtIndex:1], ":")==0, @"Unable to remove _cmd from a method signature without a _cmd argument");

    NSMutableString *modifiedTypesString = [NSMutableString string];
    [modifiedTypesString appendString:cdr_stripProblematicEncodings([self methodReturnType])];

    for (NSInteger argIndex=0; argIndex<[self numberOfArguments]; argIndex++) {
        if (argIndex==1) { continue; }
        [modifiedTypesString appendString:cdr_stripProblematicEncodings([self getArgumentTypeAtIndex:argIndex])];
    }

    return [NSMethodSignature signatureWithObjCTypes:[modifiedTypesString UTF8String]];
}

@end
