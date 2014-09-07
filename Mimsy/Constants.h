#import <Foundation/Foundation.h>

extern const NSRange NSZeroRange;

// A good reference for Unicode characters is: http://www.fileformat.info/info/unicode/category/index.htm
extern NSString* EllipsisChar;
extern NSString* ReplacementChar;

extern NSString* RightArrowChar;
extern NSString* DownArrowChar;
extern NSString* DownHookedArrowChar;

/*
 *  Summary:
 *    Virtual keycodes
 *
 *  Discussion:
 *    These constants are the virtual keycodes defined originally in
 *    Inside Mac Volume V, pg. V-191. They identify physical keys on a
 *    keyboard. Those constants with "ANSI" in the name are labeled
 *    according to the key position on an ANSI-standard US keyboard.
 *    For example, ANSI_AKeyCode indicates the virtual keycode for the key
 *    with the letter 'A' in the US keyboard layout. Other keyboard
 *    layouts may have the 'A' key label on a different physical key;
 *    in this case, pressing 'A' will generate a different virtual
 *    keycode.
 */
enum {
	ANSI_AKeyCode                    = 0x00,
	ANSI_SKeyCode                    = 0x01,
	ANSI_DKeyCode                    = 0x02,
	ANSI_FKeyCode                    = 0x03,
	ANSI_HKeyCode                    = 0x04,
	ANSI_GKeyCode                    = 0x05,
	ANSI_ZKeyCode                    = 0x06,
	ANSI_XKeyCode                    = 0x07,
	ANSI_CKeyCode                    = 0x08,
	ANSI_VKeyCode                    = 0x09,
	ANSI_BKeyCode                    = 0x0B,
	ANSI_QKeyCode                    = 0x0C,
	ANSI_WKeyCode                    = 0x0D,
	ANSI_EKeyCode                    = 0x0E,
	ANSI_RKeyCode                    = 0x0F,
	ANSI_YKeyCode                    = 0x10,
	ANSI_TKeyCode                    = 0x11,
	ANSI_1KeyCode                    = 0x12,
	ANSI_2KeyCode                    = 0x13,
	ANSI_3KeyCode                    = 0x14,
	ANSI_4KeyCode                    = 0x15,
	ANSI_6KeyCode                    = 0x16,
	ANSI_5KeyCode                    = 0x17,
	ANSI_EqualKeyCode                = 0x18,
	ANSI_9KeyCode                    = 0x19,
	ANSI_7KeyCode                    = 0x1A,
	ANSI_MinusKeyCode                = 0x1B,
	ANSI_8KeyCode                    = 0x1C,
	ANSI_0KeyCode                    = 0x1D,
	ANSI_RightBracketKeyCode         = 0x1E,
	ANSI_OKeyCode                    = 0x1F,
	ANSI_UKeyCode                    = 0x20,
	ANSI_LeftBracketKeyCode          = 0x21,
	ANSI_IKeyCode                    = 0x22,
	ANSI_PKeyCode                    = 0x23,
	ANSI_LKeyCode                    = 0x25,
	ANSI_JKeyCode                    = 0x26,
	ANSI_QuoteKeyCode                = 0x27,
	ANSI_KKeyCode                    = 0x28,
	ANSI_SemicolonKeyCode            = 0x29,
	ANSI_BackslashKeyCode            = 0x2A,
	ANSI_CommaKeyCode                = 0x2B,
	ANSI_SlashKeyCode                = 0x2C,
	ANSI_NKeyCode                    = 0x2D,
	ANSI_MKeyCode                    = 0x2E,
	ANSI_PeriodKeyCode               = 0x2F,
	ANSI_GraveKeyCode                = 0x32,
	ANSI_KeypadDecimalKeyCode        = 0x41,
	ANSI_KeypadMultiplyKeyCode       = 0x43,
	ANSI_KeypadPlusKeyCode           = 0x45,
	ANSI_KeypadClearKeyCode          = 0x47,
	ANSI_KeypadDivideKeyCode         = 0x4B,
	ANSI_KeypadEnterKeyCode          = 0x4C,
	ANSI_KeypadMinusKeyCode          = 0x4E,
	ANSI_KeypadEqualsKeyCode         = 0x51,
	ANSI_Keypad0KeyCode              = 0x52,
	ANSI_Keypad1KeyCode              = 0x53,
	ANSI_Keypad2KeyCode              = 0x54,
	ANSI_Keypad3KeyCode              = 0x55,
	ANSI_Keypad4KeyCode              = 0x56,
	ANSI_Keypad5KeyCode              = 0x57,
	ANSI_Keypad6KeyCode              = 0x58,
	ANSI_Keypad7KeyCode              = 0x59,
	ANSI_Keypad8KeyCode              = 0x5B,
	ANSI_Keypad9KeyCode              = 0x5C
};

/* keycodes for keys that are independent of keyboard layout*/
enum {
	ReturnKeyCode                    = 0x24,
	TabKeyCode                       = 0x30,
	SpaceKeyCode                     = 0x31,
	DeleteKeyCode                    = 0x33,
	EscapeKeyCode                    = 0x35,
	CommandKeyCode                   = 0x37,
	ShiftKeyCode                     = 0x38,
	CapsLockKeyCode                  = 0x39,
	OptionKeyCode                    = 0x3A,
	ControlKeyCode                   = 0x3B,
	RightShiftKeyCode                = 0x3C,
	RightOptionKeyCode               = 0x3D,
	RightControlKeyCode              = 0x3E,
	FunctionKeyCode                  = 0x3F,
	F17KeyCode                       = 0x40,
	VolumeUpKeyCode                  = 0x48,
	VolumeDownKeyCode                = 0x49,
	MuteKeyCode                      = 0x4A,
	F18KeyCode                       = 0x4F,
	F19KeyCode                       = 0x50,
	F20KeyCode                       = 0x5A,
	F5KeyCode                        = 0x60,
	F6KeyCode                        = 0x61,
	F7KeyCode                        = 0x62,
	F3KeyCode                        = 0x63,
	F8KeyCode                        = 0x64,
	F9KeyCode                        = 0x65,
	F11KeyCode                       = 0x67,
	F13KeyCode                       = 0x69,
	F16KeyCode                       = 0x6A,
	F14KeyCode                       = 0x6B,
	F10KeyCode                       = 0x6D,
	F12KeyCode                       = 0x6F,
	F15KeyCode                       = 0x71,
	HelpKeyCode                      = 0x72,
	HomeKeyCode                      = 0x73,
	PageUpKeyCode                    = 0x74,
	ForwardDeleteKeyCode             = 0x75,
	F4KeyCode                        = 0x76,
	EndKeyCode                       = 0x77,
	F2KeyCode                        = 0x78,
	PageDownKeyCode                  = 0x79,
	F1KeyCode                        = 0x7A,
	LeftArrowKeyCode                 = 0x7B,
	RightArrowKeyCode                = 0x7C,
	DownArrowKeyCode                 = 0x7D,
	UpArrowKeyCode                   = 0x7E
};