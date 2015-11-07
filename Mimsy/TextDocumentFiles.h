#if OLD_EXTENSIONS
@class TextController;

// These are the proc files associated with the frontmost text document.
@interface TextDocumentFiles : NSObject

- (id)init;

- (TextController*)frontmost;

- (void)opened:(TextController*)controller;

- (void)onSelectionChanged:(TextController*)controller;
- (void)onTextChanged:(TextController*)controller;
- (void)onWordWrapChanged:(TextController*)controller;
- (void)onAppliedStyles:(TextController*)controller;

@end
#endif
