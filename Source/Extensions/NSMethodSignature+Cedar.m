#import "NSMethodSignature+Cedar.h"
#import "CDRBlockHelper.h"

static const char *Block_signature(id blockObj) {
    struct Block_literal *block = (struct Block_literal *)blockObj;
    union Block_descriptor_rest descriptor_rest = block->descriptor->rest;

    BOOL hasCopyDispose = !!(block->flags & (1<<25));

    const char *signature = hasCopyDispose ? descriptor_rest.layout_with_copy_dispose.signature : descriptor_rest.layout_without_copy_dispose.signature;

    return signature;
}

@implementation NSMethodSignature (Cedar)

+ (NSString *) cdr_stripProblematicEncodings:(const char *) typeEncoding {
    if (!typeEncoding) {
        return @"";
    }
    
    NSString *typeEncodingString = [NSString stringWithUTF8String:typeEncoding];
    
    // Replace ANY parenthesized union/struct encodings with 'B' (C++ bool)
    // This handles complex encodings like (?={?=CCCCCCCC}Q) in Xcode 26+
    // More aggressive pattern to catch all variants
    NSRegularExpression *unionPattern = [NSRegularExpression regularExpressionWithPattern:@"\\([^)]*\\)" options:0 error:NULL];
    NSString *strippedTypeEncoding = [unionPattern stringByReplacingMatchesInString:typeEncodingString options:0 range:NSMakeRange(0, [typeEncodingString length]) withTemplate:@"B"];
    
    // Strip quoted substrings (e.g., "name")
    NSRegularExpression *quotedPattern = [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*\"" options:0 error:NULL];
    strippedTypeEncoding = [quotedPattern stringByReplacingMatchesInString:strippedTypeEncoding options:0 range:NSMakeRange(0, [strippedTypeEncoding length]) withTemplate:@""];
    
    // Strip angle-bracketed content (e.g., <ProtocolName>)
    NSRegularExpression *angleBracketPattern = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:NULL];
    strippedTypeEncoding = [angleBracketPattern stringByReplacingMatchesInString:strippedTypeEncoding options:0 range:NSMakeRange(0, [strippedTypeEncoding length]) withTemplate:@""];
    
    // If after stripping we end up with an empty or whitespace-only string, default to 'B' (bool)
    strippedTypeEncoding = [strippedTypeEncoding stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([strippedTypeEncoding length] == 0) {
        return @"B";
    }
    
    return strippedTypeEncoding;
}
+ (NSMethodSignature *)cdr_signatureFromBlock:(id)block {
    const char *signatureTypes = Block_signature(block);
    NSString *strippedSignatureTypeString = [self cdr_stripProblematicEncodings: signatureTypes];
    return [NSMethodSignature signatureWithObjCTypes:[strippedSignatureTypeString UTF8String]];
}

+ (NSMethodSignature *)cdr_sanitizedSignatureFromSignature:(NSMethodSignature *)signature {
    if (!signature) {
        return nil;
    }

    @try {
        // Build a cleaned signature string from the original signature
        NSMutableString *cleanedSignatureString = [NSMutableString string];

        // Add the return type
        const char *returnType = [signature methodReturnType];
        NSString *cleanedReturnType = [self cdr_stripProblematicEncodings: returnType];
        [cleanedSignatureString appendString:cleanedReturnType];

        // Add all argument types
        for (NSUInteger i = 0; i < [signature numberOfArguments]; i++) {
            const char *argType = [signature getArgumentTypeAtIndex:i];
            NSString *cleanedArgType = [self cdr_stripProblematicEncodings: argType];
            [cleanedSignatureString appendString:cleanedArgType];
        }

        return [NSMethodSignature signatureWithObjCTypes:[cleanedSignatureString UTF8String]];
    } @catch (NSException *exception) {
        // If sanitization fails, return the original signature
        // This shouldn't happen, but provides a fallback
        NSLog(@"Cedar: Failed to sanitize method signature: %@", exception);
        return signature;
    }
}

- (NSMethodSignature *)cdr_signatureWithoutSelectorArgument {
    NSAssert([self numberOfArguments]>1 && strcmp([self getArgumentTypeAtIndex:1], ":")==0, @"Unable to remove _cmd from a method signature without a _cmd argument");

    NSMutableString *modifiedTypesString = [NSMutableString string];
    
    [modifiedTypesString appendString:[NSMethodSignature cdr_stripProblematicEncodings: [self methodReturnType]]];

    for (NSInteger argIndex=0; argIndex<[self numberOfArguments]; argIndex++) {
        if (argIndex==1) { continue; }
        [modifiedTypesString appendString:[NSMethodSignature cdr_stripProblematicEncodings: [self getArgumentTypeAtIndex:argIndex]]];
    }

    return [NSMethodSignature signatureWithObjCTypes:[modifiedTypesString UTF8String]];
}

@end
