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

    NSString *quotedSubstringsPattern = @"\".*?\"";
    NSString *angleBracketedSubstringsPattern = @"<.*?>";
    NSString *parenthesizedSubstringsPattern = @"\\(.*?\\)";

    NSString *strippedTypeEncoding = typeEncodingString;
    for (NSString *pattern in @[quotedSubstringsPattern, angleBracketedSubstringsPattern, parenthesizedSubstringsPattern]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
        strippedTypeEncoding = [regex stringByReplacingMatchesInString:strippedTypeEncoding options:0 range:NSMakeRange(0, [strippedTypeEncoding length]) withTemplate:@""];
    }

    return strippedTypeEncoding;
}

@implementation NSMethodSignature (Cedar)

+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block {
    const char *signatureTypes = Block_signature(block);
    NSString *strippedSignatureTypeString = cdr_stripProblematicEncodings(signatureTypes);
    return [NSMethodSignature signatureWithObjCTypes:[strippedSignatureTypeString UTF8String]];
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
