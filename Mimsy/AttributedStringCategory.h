#import <Foundation/Foundation.h>

@interface NSMutableAttributedString (MutableAttributedStringCategory)

- (void)copyAttributes:(NSArray*)names from:(NSAttributedString*)from;

@end
