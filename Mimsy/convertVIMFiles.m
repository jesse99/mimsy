#import "convertVIMFiles.h"

#import "ArrayCategory.h"
#import "Assert.h"
#import "Glob.h"
#import "Metadata.h"
#import "StringCategory.h"
#import "Utils.h"

@interface Group : NSObject
@property NSString* name;				// eg "Conditional"
@property NSString* description;		// eg "if, then, else, endif, switch, etc."
@property NSString* parent;				// eg "Statement" (will be nil for "Normal")
@property NSString* link;				// nil unless hi link was used
@end

@interface GlobalStyle : NSObject
@property NSString* bgColor;
@property NSString* fgColor;
@property NSMutableDictionary* elements;// element name => ElementStyle*
@property NSArray* ignoredGroups;
@property NSArray* standardGroups;
@end

@interface ElementStyle : NSObject
@property NSString* bgColor;			// may be nil
@property NSString* fgColor;
@property NSArray* styles;				// list of bold, underline, undercurl, reverse/inverse, italic, standout, and NONE
@property bool processed;
@end

@implementation Group
+ (id)group:(NSString*)name description:(NSString*)description parent:(NSString*)parent
{
	Group* group = [Group new];
	
	group.name = name;
	group.description = description;
	group.parent = parent;
	group.link = nil;
	
	return group;
}
@end

@implementation GlobalStyle

- (id)init
{
	self.bgColor = @"gray97";
	self.fgColor = @"black";
	
	self.elements = [NSMutableDictionary new];
	self.elements[@"Normal"] = [ElementStyle new];
					
	self.ignoredGroups = @[
		// TODO: We may in the future use some of these.
		@"Directory",		// directory names (and other special names in listings)
		@"SpecialKey",		// used to show unprintable characters in the text. Generally: text that is displayed differently from what it really is.
		@"CursorLine",		// the screen line that the cursor is in when 'cursorline' is set
		@"Conceal",			// placeholder characters substituted for concealed text
		@"Folded",			// line used for closed folds
		@"FoldColumn",		
		@"Cursor",			// the character under the cursor
		@"NonText",			// characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line)
		@"LineNr",			// Line number for ":number" and ":#" commands
		@"Typedef",			// A typedef
		@"TypeDef",			// A typedef
		@"Todo",			// anything that needs extra attention; mostly the keywords TODO FIXME and XXX
		@"ToDo",			// anything that needs extra attention; mostly the keywords TODO FIXME and XXX
				
		// Don't think that we will ever use these.
		@"Ignore",			// left blank, hidden
		@"MatchParen",		// The character under the cursor or just before it, if it is a paired bracket, and its match
		@"ColorColumn",
		@"CursorIM",		// like Cursor, but used when in IME mode
		@"VertSplit",		// the column separating vertically split windows
		@"SignColumn",
		@"IncSearch",		// 'incsearch' highlighting
		@"ModeMsg",			// 'showmode' message
		@"MoreMsg",
		@"Pmenu",			// Popup menu: normal item
		@"PmenuSel",		// Popup menu: selected item
		@"PmenuSbar",		// Popup menu: scrollbar
		@"PmenuThumb",		// Popup menu: Thumb of the scrollbar
		@"Question",		// prompt and yes/no questions
		@"Search",			// Last search pattern highlighting
		@"SpellBad",		// Word that is not recognized by the spellchecker
		@"SpellCap",		// Word that should start with a capital
		@"SpellLocal",		// Word that is recognized by the spellchecker as one that is used in another region
		@"SpellRare",		// Word that is recognized by the spellchecker as one that is hardly ever used
		@"StatusLine",
		@"StatusLineNC",
		@"TabLine",
		@"TabLineFill",
		@"TabLineSel",
		@"Tag",				// you can use CTRL-] on this
		@"title",			// titles for output
		@"ErrorMsg",		// error messages on the command line
		@"WarningMsg",		// warning messages
		@"Menu",			// Current font, background and foreground colors of the menus.
		@"Title",			// titles for output
		@"Visual",			// Visual mode selection
		@"VisualNOS",		// Visual mode selection when vim is "Not Owning the Selection"
		@"WildMenu",		// WildMenu	current match in 'wildmenu' completion
		@"CursorColumn",	// the screen column that the cursor is in

		// Not sure what these are (maybe buggy color files)
		@"cIf0",
		@"lCursor",
		@"Scrollbar",
		@"SpellErrors",
		@"qfFileName",
		@"VimError",
		@"VimCommentTitle",
		@"qfError",
		@"LineNR",
		@"pythonDecorator",
		@"htmlArg",
		@"htmlLink",
		@"htmlBold",
		@"htmlBoldItalic",
		@"htmlBoldUnderline",
		@"htmlBoldUnderlineItalic",
		@"htmlItalic",
		@"htmlUnderline",
		@"htmlUnderlineItalic",
		@"htmlHead",
		@"htmlString",
		@"htmlTagName",
		@"javaScriptType",
		@"diffLine",
		@"diffFile",
		@"diffNewFile",
		@"diffOldFile",
		@"qfLineNr",
		@"mTag",
		@"ShowPairsHLp",
		@"ShowPairsHLe",
		@"ShowPairsHL",
		@"cBlock",
		@"Tooltip",
		@"TablineSel",
		@"Chatacter",
		@"Wildmenu",
		@"AutoHiGroup",
		@"pythonImport",
		@"Comments",
		@"pythonOperator",
		@"pythonRawString",
		@"pythonRepeat",
		@"pythonConditional",
		@"pythonComment",
		@"pythonStatement",
		@"Constants",
		@"pythonPrecondit",
		@"PerlPOD",
		@"VisualNos",
		@"Done",
		@"diffAdded",
		@"diffChanged",
		@"diffRemoved",
		@"Cursorline",
		@"Subtitle",
		@"Statusline",
		@"BrowseDirectory",
		@"StatuslineNC",
		@"javaScript",
		@"User2",
		@"Incsearch",
		@"TaglistTagName",
		@"browseDirectory",
		@"FoldedColumn",
		@"Match",
		@"User1",
		@"WarningMsgildMenu",
		@"Comma",
		@"Paren",
		@"SpellLocale",
		@"cSpecial",
		@"More",
		@"todo",
		@"cOctal",
		@"PreConduit",
		@"cCursor",
		@"vCursor",
		@"texStatement",
		@"Gutter",
		@"xmlTag",
		@"xmlEndTag",
		@"xmlTagName",
		@"vimFold",
		@"rubySymbol",
		@"Linenr",
		@"Titled",
		@"FoldeColumn",
		@"question",
		@"specialkey",
		@"nontext",
		@"directory",
		@"scrollbar",
		@"incsearch",
		@"cursor",
		@"statuslinenc",
		@"errormsg",
		@"modemsg",
		@"vertsplit",
		@"warningmsg",
		@"moremsg",
		@"visual",
		@"statusline",
		@"wildmenu",
		@"spellbad",
		@"spelllocal",
		@"linenr",
		@"tabline",
		@"spellcap",
		@"spellrare",
		@"foldcolumn",
		@"folded",
		@"cursorcolumn",
		@"tablinesel",
		@"matchparen",
		@"pmenu",
		@"cursorline",
		@"tablinefill",
		@"pmenusel",
		@"rubyBlockParameter",
		@"rubyPredefinedVariable",
		@"rubyPredefinedConstant",
		@"rubyException",
		@"rubyAccess",
		@"rubyPredefinedIdentifier",
		@"mySpecialSymbols",
		@"BrowseCurDirectory",
		@"BrowseSuffixes",
		@"BrowseFile",
		@"KDE",
		@"StatuslinePosition",
		@"vimFuncName",
		@"PageMark",
		@"CICS_Statement",
		@"Condition",
		@"NameSpace",
		@"StatuslineBufNr",
		@"StatuslineFlag",
		@"SQL_Statement",
		@"Builtin",
		@"StatuslineCapsBuddy",
		@"cPreCondit",
		@"diffSubname",
		@"HTMLString",
		@"StatementU",
		@"htmlTag",
		@"javaScriptParens",
		@"MBEChanged",
		@"MBENormal",
		@"MBEVisibleChanged",
		@"MBEVisibleNormal",
		@"mySpecialSymbols",
		@"oCursor",
		@"phpDefineClassName",
		@"phpParent",
		@"phpStringDouble",
		@"phpStructureHere",
		@"pythonBuiltin",
		@"railsClass",
		@"rubyRegexp",
		@"rubyRegexpSpecial",
		@"xmlString",
		@"search",
		@"Action",
		@"AnsiFuncPtr",
		@"BadStyle",
		@"BadWord",
		@"BlockBraces",
		@"browseSuffixes",
		@"BufExplorerActBuf",
		@"bufExplorerAltBuf",
		@"bufExplorerBufNbr",
		@"bufExplorerCurBuf",
		@"bufExplorerHelp",
		@"bufExplorerHidBuf",
		@"bufExplorerLockedBuf",
		@"bufExplorerMapping",
		@"bufExplorerModBuf",
		@"bufExplorerOpenIn",
		@"bufExplorerSortBy",
		@"bufExplorerSortType",
		@"bufExplorerTitle",
		@"bufExplorerToggleOpen",
		@"bufExplorerToggleSplit",
		@"bufExplorerUnlBuf",
		@"bufExplorerXxxBuf",
		@"cBinaryOperator",
		@"cBinaryOperatorError",
		@"cBraces",
		@"cDefine",
		@"cFenhao",
		@"cFormat",
		@"cInclude",
		@"cIncluded",
		@"cLabel",
		@"cLogicalOperator",
		@"cMaohao",
		@"cMathOperator",
		@"cOctalZero",
		@"ColumnMargin",
		@"confluenceHeading",
		@"confluenceHeadingMarker",
		@"confluenceVerbatim",
		@"cPointerOperator",
		@"cppSTLType",
		@"Cream_ShowMarksHL",
		@"cssBoxProp",
		@"cssBraces",
		@"cssBraces",
		@"cssClassName",
		@"cssColor",
		@"cssCommonAttr",
		@"cssFunctionName",
		@"cssIdentifier",
		@"cssImportant",
		@"cssPseudoClassId",
		@"cssSelectorOp",
		@"cssTagName",
		@"cssUIAttr",
		@"cssUIProp",
		@"cssURL",
		@"cssValueLength",
		@"CurrentLine",
		@"DebugBreak",
		@"DebugStop",
		@"def",
		@"Defined",
		@"diffOldLine",
		@"djangoArgument",
		@"djangoComment",
		@"djangoFilter",
		@"djangoStatement",
		@"djangoTagBlock",
		@"djangoVarBlock",
		@"doxygenArgumentWord",
		@"doxygenBrief",
		@"doxygenBriefL",
		@"doxygenBriefLine",
		@"doxygenCodeWord",
		@"doxygenComment",
		@"doxygenCommentL",
		@"doxygenHyperLink",
		@"doxygenParam",
		@"doxygenParamDirection",
		@"doxygenParamName",
		@"doxygenPrevL",
		@"doxygenSpecial",
		@"doxygenSpecialMultiLineDesc",
		@"doxygenStart",
		@"doxygenStartL",
		@"Emphasize",
		@"EQuote1",
		@"EQuote2",
		@"EQuote3",
		@"erubyComment",
		@"erubyDelimiter",
		@"erubyRailsHelperMethod",
		@"erubyRailsMethod",
		@"erubyRubyDelim",
		@"fortranLabelNumber",
		@"fortranType",
		@"fortranUnitHeader",
		@"hamlId",
		@"hamlRubyChar",
		@"helpHyperTextJump",
		@"Hint",
		@"htm",
		@"htmlEndTag",
		@"htmlEvent",
		@"htmlH1",
		@"htmlH2",
		@"htmlH3",
		@"htmlH4",
		@"htmlH5",
		@"htmlH6",
		@"htmlSpecialChar",
		@"htmlSpecialTagName",
		@"htmlTagN",
		@"htmlTitle",
		@"iCursor",
		@"icursor",
		@"ICursor",
		@"ifdefIfOut",
		@"Interpolation",
		@"javaBraces",
		@"javaClassDecl",
		@"javaDebug",
		@"javaDocComment",
		@"javaDocSeeTag",
		@"javaExceptions",
		@"javaExternal",
		@"javaFuncDef",
		@"javaLangObject",
		@"javaParen",
		@"javaParen1",
		@"javaParen2",
		@"javaRepeat",
		@"javaScopeDecl",
		@"javaScriptAjaxMethods",
		@"javaScriptAjaxObjects",
		@"javaScriptAjaxProperties",
		@"javaScriptBraces",
		@"javaScriptBrowserObjects",
		@"javaScriptConditional",
		@"javaScriptCssStyles",
		@"javaScriptDocComment",
		@"javaScriptDomElemFuncs",
		@"javaScriptDOMMethods",
		@"javaScriptDOMObjects",
		@"javaScriptEventListenerKeyword",
		@"javaScriptFuncName",
		@"javaScriptFunction",
		@"javaScriptHtmlElemFuncs",
		@"javaScriptHtmlElemProperties",
		@"javaScriptLabel",
		@"javaScriptOperator",
		@"javaScriptPrototype",
		@"javaScriptRailsFunction",
		@"javaScriptRegexpString",
		@"javaScriptRepeat",
		@"javaString",
		@"javaTypeDef",
		@"jinjaAttribute",
		@"jinjaComment",
		@"jinjaFilter",
		@"jinjaNumber",
		@"jinjaOperator",
		@"jinjaRaw",
		@"jinjaSpecial",
		@"jinjaStatement",
		@"jinjaString",
		@"jinjaTagBlock",
		@"jinjaVarBlock",
		@"jinjaVariable",
		@"js",
		@"Key",
		@"lcursor",
		@"level10c",
		@"level11c",
		@"level12c",
		@"level13c",
		@"level14c",
		@"level15c",
		@"level16c",
		@"level1c",
		@"level2c",
		@"level3c",
		@"level4c",
		@"level5c",
		@"level6c",
		@"level7c",
		@"level8c",
		@"level9c",
		@"lispList",
		@"mailEmail",
		@"mailHeader",
		@"mailHeaderKey",
		@"MailQ",
		@"MailQu",
		@"mailQuoted1",
		@"mailQuoted2",
		@"mailQuoted3",
		@"mailQuoted4",
		@"mailQuoted5",
		@"mailQuoted6",
		@"mailSignature",
		@"mailSubject",
		@"markdownCode",
		@"markdownCodeBlock",
		@"markdownLinkText",
		@"markdownUrl",
		@"Method",
		@"MicroController",
		@"MyDiffCommLine",
		@"MyDiffNew",
		@"MyDiffNormal",
		@"MyDiffRemoved",
		@"MyDiffSubName",
		@"MyTagListComment",
		@"MyTagListFileName",
		@"MyTagListTagName",
		@"MyTagListTagScope",
		@"MyTagListTitle",
		@"nCursor",
		@"ncursor",
		@"netrwExe",
		@"netrwList",
		@"netrwSymLink",
		@"netrwTags",
		@"netrwTilde",
		@"OperatorBold",
		@"otlTab0",
		@"otlTab1",
		@"otlTab2",
		@"otlTab3",
		@"otlTab4",
		@"otlTab5",
		@"otlTab6",
		@"otlTab7",
		@"otlTab8",
		@"otlTab9",
		@"otlTagRef",
		@"otlTodo",
		@"OverLength",
		@"perlControl",
		@"perlFunctionName",
		@"perlIdentifier",
		@"perlLabel",
		@"perlMatchStartEnd",
		@"perlMethod",
		@"perlNumber",
		@"perlOperator",
		@"perlPackageDecl",
		@"perlPackageRef",
		@"perlQQ",
		@"perlRepeat",
		@"perlSharpBang",
		@"perlShellCommand",
		@"perlSpecialBEOM",
		@"perlSpecialMatch",
		@"perlSpecialString",
		@"perlStatement",
		@"perlStatementControl",
		@"perlStatementFiledesc",
		@"perlStatementHash",
		@"perlStatementInclude",
		@"perlStatementNew",
		@"perlStatementStorage",
		@"perlStatementSub",
		@"perlStringStartEnd",
		@"perlVarMember",
		@"perlVarNotInMatches",
		@"perlVarPlain",
		@"perlVarPlain",
		@"perlVarPlain2",
		@"perlVarSimpleMember",
		@"perlVarSimpleMemberName",
		@"phpArrayPair",
		@"phpAssignByRef",
		@"phpDefine",
		@"phpDocBlock",
		@"phpFunctions",
		@"phpMemberSelector",
		@"phpOperator",
		@"phpPropertySelector",
		@"phpPropertySelectorInString",
		@"phpRegionDelimiter",
		@"phpRelation",
		@"phpSemicolon",
		@"phpUnknownSelector",
		@"phpVarSelector",
		@"plsqlConditional",
		@"plsqlFunction",
		@"plsqlRepeat",
		@"plsqlStorage",
		@"PMenu",
		@"PMenuSbar",
		@"pmenusbar",
		@"PMenuSbar",
		@"PMenuSel",
		@"pmenuthumb",
		@"PMenuThumb",
		@"prologFreeVariable",
		@"prologVariable",
		@"PythonBuiltin",
		@"pythonBuiltinFunc",
		@"pythonBuiltinFunction",
		@"pythonBuiltinObj",
		@"pythonClass",
		@"pythonCoding",
		@"pythonCommentedCode",
		@"pythonControl",
		@"pythonDisabledComment",
		@"pythonDocTest",
		@"pythonDocTest2",
		@"pythonEolComment",
		@"pythonEpydoc",
		@"pythonEscape",
		@"pythonException",
		@"pythonExClass",
		@"pythonFunction",
		@"pythonInfoComment",
		@"pythonJavadoc",
		@"pythonKingComment",
		@"pythonMajorSection",
		@"pythonMinorSection",
		@"pythonRegexp",
		@"pythonRequire",
		@"pythonRun",
		@"pythonSmartComment",
		@"pythonSpaceError",
		@"pythonTripleDirkString",
		@"pythonTripleTickString",
		@"railsMethod",
		@"rCursor",
		@"rcursor",
		@"rightMargin",
		@"rubyAttribute",
		@"rubyClass",
		@"rubyClassVariable",
		@"rubyConditional",
		@"rubyConditionalModifier",
		@"rubyConstant",
		@"rubyControl",
		@"rubyData",
		@"rubyDefine",
		@"rubyDocumentation",
		@"rubyEscape",
		@"rubyEval",
		@"rubyFunction",
		@"rubyGlobalVariable",
		@"rubyIdentifier",
		@"rubyInclude",
		@"rubyIndentifier",
		@"rubyInstanceVariable",
		@"rubyInterpolation",
		@"rubyInterpolationDelimiter",
		@"rubyKeyword",
		@"rubyLocalVariableOrMethod",
		@"rubyModule",
		@"rubyOperator",
		@"rubyOptionalDo",
		@"rubyPredifinedIdentifier",
		@"rubyPseudoVariable",
		@"rubyRailsARAssociationMethod",
		@"rubyRailsARMethod",
		@"rubyRailsMethod",
		@"rubyRailsRenderMethod",
		@"rubyRailsUserClass",
		@"rubyRegexpDelimiter",
		@"rubySpaceError",
		@"rubyString",
		@"rubyStringDelimiter",
		@"ShowMarksHLl",
		@"Sig",
		@"signcolumn",
		@"SourceLine",
		@"StatuslineChar",
		@"StatuslineFileEnc",
		@"StatuslineFileName",
		@"StatuslineFileType",
		@"StatuslinePath",
		@"StatuslineRealSyn",
		@"StatuslineSomething",
		@"StatuslineSyn",
		@"StatuslineTermEnc",
		@"StatuslineTime",
		@"StdFunction",
		@"StdName",
		@"Symbol",
		@"TabLineFillSel",
		@"TagListComment",
		@"TagListTagName",
		@"TagListTagScope",
		@"TagListTitle",
		@"TagName",
		@"Tags",
		@"Tb_Changed",
		@"Tb_Normal",
		@"Tb_VisibleNormal",
		@"texMatcher",
		@"texMath",
		@"texSection",
		@"tmeSupport",
		@"treeCWD",
		@"treeDir",
		@"treeDirSlash",
		@"treeFlag",
		@"treeHelp",
		@"treePart",
		@"treeUp",
		@"User3",
		@"User4",
		@"User5",
		@"UserLabel2",
		@"Variable",
		@"vimCommentString",
		@"vimCommentTitle",
		@"vimHiCtermColor",
		@"vimHiGuiRgb",
		@"VimOption",
		@"VimwikiHeader1",
		@"VimwikiHeader2",
		@"VimwikiHeader3",
		@"VimwikiHeader4",
		@"VimwikiHeader5",
		@"VimwikiHeader6",
		@"VIsualNOS",
		@"xmlAttrib",
		@"XmlAttrib",
		@"xmlAttrib",
		@"xmlAttribPunct",
		@"xmlCdata",
		@"xmlCdataCdata",
		@"xmlCdataEnd",
		@"xmlCdataStart",
		@"xmlComment",
		@"XmlEndTag",
		@"xmlEntity",
		@"XmlEntity",
		@"XmlEntityPunct",
		@"xmlEqual",
		@"xmlNamespace",
		@"XmlTag",
		@"XmlTagName",
		@"xpceKeyword",
		@"xpceVariable",
		@"XPTcurrentPH",
		@"XPTfollowingPH",
		@"XPTnextItem",
		@"yamlAlias",
		@"yamlAnchor",
		@"yamlDocumentHeader",
		@"yamlDocumentHeader",
		@"yamlKey",
		@"yamlTab",
		@"TagListFileName",
		@"rubySharpBang",
		@"otlTagDef",
		@"rubySharpBang",
		@"OperatorCurlyBrackets",
		@"TagListFileName",
		@"javaFold"
	];
				
	self.standardGroups = @[
		[Group group:@"Normal" description:@"normal text" parent:nil],
		[Group group:nil description:nil parent:nil],

		[Group group:@"Type" description:@"int, long, char, etc." parent:@"Normal"],
		[Group group:@"Structure" description:@"name in a struct or class declaration" parent:@"Type"],
		[Group group:@"UserType" description:@"a user defined type name" parent:@"Type"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Identifier" description:@"any variable name" parent:@"Normal"],
		[Group group:@"Argument" description:@"formal argument" parent:@"Constant"],	// think Constant parent looks a bit better
		[Group group:@"Function" description:@"function name (also: methods for classes)" parent:@"Identifier"],
		[Group group:@"Macro" description:@"name of a macro: NDEBUG, __FILE, MIN, etc" parent:@"Identifier"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Statement" description:@"any statement" parent:@"Normal"],
		[Group group:@"Conditional" description:@"if, then, else, endif, switch, etc." parent:@"Statement"],
		[Group group:@"Exception" description:@"try, catch, throw" parent:@"Statement"],
		[Group group:@"Keyword" description:@"any other keyword" parent:@"Statement"],
		[Group group:@"Label" description:@"target of a goto or a case in a switch statement" parent:@"Statement"],
		[Group group:@"Operator" description:@"\"sizeof\", \"+\", \"*\", etc." parent:@"Statement"],
		[Group group:@"Repeat" description:@"for, do, while, etc." parent:@"Statement"],
		[Group group:@"StorageClass" description:@"static, register, volatile, etc." parent:@"Statement"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Constant" description:@"any constant" parent:@"Normal"],
		[Group group:@"Boolean" description:@"a boolean constant: TRUE, false, etc." parent:@"Constant"],
		[Group group:@"Character" description:@"a character constant: 'c', '\\n'" parent:@"Constant"],
		[Group group:@"Float" description:@"a floating point constant: 2.3e10" parent:@"Constant"],
		[Group group:@"Number" description:@"a number constant: 234, 0xff" parent:@"Constant"],
		[Group group:@"String" description:@"a string constant: \"this is a string\"" parent:@"Constant"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Comment" description:@"any comment" parent:@"Normal"],
		[Group group:@"DocComment" description:@"comment used to generate documentation" parent:@"Comment"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"PreProc" description:@"generic Preprocessor" parent:@"Normal"],
		[Group group:@"Define" description:@"preprocessor #define" parent:@"PreProc"],
		[Group group:@"Include" description:@"preprocessor #include" parent:@"PreProc"],
		[Group group:@"PreCondit" description:@"preprocessor #if, #else, #endif, etc." parent:@"PreProc"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Special" description:@"any special symbol" parent:@"Normal"],
		[Group group:@"Debug" description:@"debugging statements" parent:@"Special"],
		[Group group:@"Delimiter" description:@"character that needs attention" parent:@"Special"],
		[Group group:@"SpecialChar" description:@"special character in a constant" parent:@"Special"],
		[Group group:@"SpecialComment" description:@"special things inside a comment" parent:@"Special"],
		[Group group:@"Attribute" description:@"e.g. in C#, Rust, Python (decorator)" parent:@"Special"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"Error" description:@"any erroneous construct" parent:@"Normal"],
		[Group group:@"Underlined" description:@"text that stands out, HTML links" parent:@"Normal"],
		[Group group:@"Warning" description:@"a problem which may not be an error" parent:@"Normal"],
		[Group group:nil description:nil parent:nil],
	
		[Group group:@"DiffAdd" description:@"added line" parent:@"Normal"],
		[Group group:@"DiffChange" description:@"changed line" parent:@"Normal"],
		[Group group:@"DiffDelete" description:@"deleted line" parent:@"Normal"],
		[Group group:@"DiffText" description:@"changed text within a changed line" parent:@"Normal"]
	];
	
	return self;
}

- (bool)hasElement:(NSString*)name
{
	ElementStyle* element = self.elements[name];
		
	return element != nil;
}

- (ElementStyle*)getElement:(NSString*)name
{
	ElementStyle* element = self.elements[name];
	
	if (!element)
	{
		element = [ElementStyle new];
		self.elements[name] = element;
	}
	
	return element;
}

@end

@implementation ElementStyle

- (id)init
{
	self.bgColor = nil;
	self.fgColor = @"black";
	self.styles = @[@"NONE"];
	return self;
}

- (ElementStyle*)changeFg:(NSString*)color
{
	ElementStyle* result = [ElementStyle new];
	
	result.fgColor = color;
	result.bgColor = self.bgColor;
	result.styles = self.styles;
	
	return result;
}

- (ElementStyle*)addStyle:(NSString*)name
{
	ElementStyle* result = [ElementStyle new];
	
	result.fgColor = self.fgColor;
	result.bgColor = self.bgColor;
	result.styles = [self.styles arrayByAddingObject:name];
	
	return result;
}

- (ElementStyle*)removeStyle:(NSString*)name
{
	ElementStyle* result = [ElementStyle new];
	
	result.fgColor = self.fgColor;
	result.bgColor = self.bgColor;
	result.styles = [self.styles arrayByRemovingObject:name];
	
	return result;
}

@end

typedef struct GuiColourTable
{
	char* name;
	int red;
	int green;
	int blue;
} GuiColourTable;

// From vim/runtime/rgb.txt
static GuiColourTable colors[] =
{
	{"snow", 255, 250, 250},
	{"ghost white", 248, 248, 255},
	{"GhostWhite", 248, 248, 255},
	{"white smoke", 245, 245, 245},
	{"WhiteSmoke", 245, 245, 245},
	{"gainsboro", 220, 220, 220},
	{"floral white", 255, 250, 240},
	{"FloralWhite", 255, 250, 240},
	{"old lace", 253, 245, 230},
	{"OldLace", 253, 245, 230},
	{"linen", 250, 240, 230},
	{"antique white", 250, 235, 215},
	{"AntiqueWhite", 250, 235, 215},
	{"papaya whip", 255, 239, 213},
	{"PapayaWhip", 255, 239, 213},
	{"blanched almond", 255, 235, 205},
	{"BlanchedAlmond", 255, 235, 205},
	{"bisque", 255, 228, 196},
	{"peach puff", 255, 218, 185},
	{"PeachPuff", 255, 218, 185},
	{"navajo white", 255, 222, 173},
	{"NavajoWhite", 255, 222, 173},
	{"moccasin", 255, 228, 181},
	{"cornsilk", 255, 248, 220},
	{"ivory", 255, 255, 240},
	{"lemon chiffon", 255, 250, 205},
	{"LemonChiffon", 255, 250, 205},
	{"seashell", 255, 245, 238},
	{"honeydew", 240, 255, 240},
	{"mint cream", 245, 255, 250},
	{"MintCream", 245, 255, 250},
	{"azure", 240, 255, 255},
	{"alice blue", 240, 248, 255},
	{"AliceBlue", 240, 248, 255},
	{"lavender", 230, 230, 250},
	{"lavender blush", 255, 240, 245},
	{"LavenderBlush", 255, 240, 245},
	{"misty rose", 255, 228, 225},
	{"MistyRose", 255, 228, 225},
	{"white", 255, 255, 255},
	{"black", 0, 0, 0},
	{"dark slate gray", 47, 79, 79},
	{"DarkSlateGray", 47, 79, 79},
	{"dark slate grey", 47, 79, 79},
	{"DarkSlateGrey", 47, 79, 79},
	{"dim gray", 105, 105, 105},
	{"DimGray", 105, 105, 105},
	{"dim grey", 105, 105, 105},
	{"DimGrey", 105, 105, 105},
	{"slate gray", 112, 128, 144},
	{"SlateGray", 112, 128, 144},
	{"slate grey", 112, 128, 144},
	{"SlateGrey", 112, 128, 144},
	{"light slate gray", 119, 136, 153},
	{"LightSlateGray", 119, 136, 153},
	{"light slate grey", 119, 136, 153},
	{"LightSlateGrey", 119, 136, 153},
	{"gray", 190, 190, 190},
	{"grey", 190, 190, 190},
	{"light grey", 211, 211, 211},
	{"LightGrey", 211, 211, 211},
	{"light gray", 211, 211, 211},
	{"LightGray", 211, 211, 211},
	{"midnight blue", 25, 25, 112},
	{"MidnightBlue", 25, 25, 112},
	{"navy", 0, 0, 128},
	{"navy blue", 0, 0, 128},
	{"NavyBlue", 0, 0, 128},
	{"cornflower blue", 100, 149, 237},
	{"CornflowerBlue", 100, 149, 237},
	{"dark slate blue", 72, 61, 139},
	{"DarkSlateBlue", 72, 61, 139},
	{"slate blue", 106, 90, 205},
	{"SlateBlue", 106, 90, 205},
	{"medium slate blue", 123, 104, 238},
	{"MediumSlateBlue", 123, 104, 238},
	{"light slate blue", 132, 112, 255},
	{"LightSlateBlue", 132, 112, 255},
	{"medium blue", 0, 0, 205},
	{"MediumBlue", 0, 0, 205},
	{"royal blue", 65, 105, 225},
	{"RoyalBlue", 65, 105, 225},
	{"blue", 0, 0, 255},
	{"dodger blue", 30, 144, 255},
	{"DodgerBlue", 30, 144, 255},
	{"deep sky blue", 0, 191, 255},
	{"DeepSkyBlue", 0, 191, 255},
	{"sky blue", 135, 206, 235},
	{"SkyBlue", 135, 206, 235},
	{"light sky blue", 135, 206, 250},
	{"LightSkyBlue", 135, 206, 250},
	{"steel blue", 70, 130, 180},
	{"SteelBlue", 70, 130, 180},
	{"light steel blue", 176, 196, 222},
	{"LightSteelBlue", 176, 196, 222},
	{"light blue", 173, 216, 230},
	{"LightBlue", 173, 216, 230},
	{"powder blue", 176, 224, 230},
	{"PowderBlue", 176, 224, 230},
	{"pale turquoise", 175, 238, 238},
	{"PaleTurquoise", 175, 238, 238},
	{"dark turquoise", 0, 206, 209},
	{"DarkTurquoise", 0, 206, 209},
	{"medium turquoise", 72, 209, 204},
	{"MediumTurquoise", 72, 209, 204},
	{"turquoise", 64, 224, 208},
	{"cyan", 0, 255, 255},
	{"light cyan", 224, 255, 255},
	{"LightCyan", 224, 255, 255},
	{"cadet blue", 95, 158, 160},
	{"CadetBlue", 95, 158, 160},
	{"medium aquamarine", 102, 205, 170},
	{"MediumAquamarine", 102, 205, 170},
	{"aquamarine", 127, 255, 212},
	{"dark green", 0, 100, 0},
	{"DarkGreen", 0, 100, 0},
	{"dark olive green", 85, 107, 47},
	{"DarkOliveGreen", 85, 107, 47},
	{"dark sea green", 143, 188, 143},
	{"DarkSeaGreen", 143, 188, 143},
	{"sea green", 46, 139, 87},
	{"SeaGreen", 46, 139, 87},
	{"medium sea green", 60, 179, 113},
	{"MediumSeaGreen", 60, 179, 113},
	{"light sea green", 32, 178, 170},
	{"LightSeaGreen", 32, 178, 170},
	{"pale green", 152, 251, 152},
	{"PaleGreen", 152, 251, 152},
	{"spring green", 0, 255, 127},
	{"SpringGreen", 0, 255, 127},
	{"lawn green", 124, 252, 0},
	{"LawnGreen", 124, 252, 0},
	{"green", 0, 255, 0},
	{"chartreuse", 127, 255, 0},
	{"medium spring green", 0, 250, 154},
	{"MediumSpringGreen", 0, 250, 154},
	{"green yellow", 173, 255, 47},
	{"GreenYellow", 173, 255, 47},
	{"lime green", 50, 205, 50},
	{"LimeGreen", 50, 205, 50},
	{"yellow green", 154, 205, 50},
	{"YellowGreen", 154, 205, 50},
	{"forest green", 34, 139, 34},
	{"ForestGreen", 34, 139, 34},
	{"olive drab", 107, 142, 35},
	{"OliveDrab", 107, 142, 35},
	{"dark khaki", 189, 183, 107},
	{"darkyellow", 189, 183, 107},
	{"DarkKhaki", 189, 183, 107},
	{"khaki", 240, 230, 140},
	{"pale goldenrod", 238, 232, 170},
	{"PaleGoldenrod", 238, 232, 170},
	{"light goldenrod yellow", 250, 250, 210},
	{"LightGoldenrodYellow", 250, 250, 210},
	{"light yellow", 255, 255, 224},
	{"LightYellow", 255, 255, 224},
	{"yellow", 255, 255, 0},
	{"gold", 255, 215, 0},
	{"light goldenrod", 238, 221, 130},
	{"LightGoldenrod", 238, 221, 130},
	{"goldenrod", 218, 165, 32},
	{"dark goldenrod", 184, 134, 11},
	{"DarkGoldenrod", 184, 134, 11},
	{"rosy brown", 188, 143, 143},
	{"RosyBrown", 188, 143, 143},
	{"indian red", 205, 92, 92},
	{"IndianRed", 205, 92, 92},
	{"saddle brown", 139, 69, 19},
	{"SaddleBrown", 139, 69, 19},
	{"sienna", 160, 82, 45},
	{"peru", 205, 133, 63},
	{"burlywood", 222, 184, 135},
	{"beige", 245, 245, 220},
	{"wheat", 245, 222, 179},
	{"sandy brown", 244, 164, 96},
	{"SandyBrown", 244, 164, 96},
	{"tan", 210, 180, 140},
	{"chocolate", 210, 105, 30},
	{"firebrick", 178, 34, 34},
	{"brown", 165, 42, 42},
	{"dark salmon", 233, 150, 122},
	{"DarkSalmon", 233, 150, 122},
	{"salmon", 250, 128, 114},
	{"light salmon", 255, 160, 122},
	{"LightSalmon", 255, 160, 122},
	{"orange", 255, 165, 0},
	{"dark orange", 255, 140, 0},
	{"DarkOrange", 255, 140, 0},
	{"coral", 255, 127, 80},
	{"light coral", 240, 128, 128},
	{"LightCoral", 240, 128, 128},
	{"tomato", 255, 99, 71},
	{"orange red", 255, 69, 0},
	{"OrangeRed", 255, 69, 0},
	{"red", 255, 0, 0},
	{"hot pink", 255, 105, 180},
	{"HotPink", 255, 105, 180},
	{"deep pink", 255, 20, 147},
	{"DeepPink", 255, 20, 147},
	{"pink", 255, 192, 203},
	{"light pink", 255, 182, 193},
	{"LightPink", 255, 182, 193},
	{"pale violet red", 219, 112, 147},
	{"PaleVioletRed", 219, 112, 147},
	{"maroon", 176, 48, 96},
	{"medium violet red", 199, 21, 133},
	{"MediumVioletRed", 199, 21, 133},
	{"violet red", 208, 32, 144},
	{"VioletRed", 208, 32, 144},
	{"magenta", 255, 0, 255},
	{"violet", 238, 130, 238},
	{"plum", 221, 160, 221},
	{"orchid", 218, 112, 214},
	{"medium orchid", 186, 85, 211},
	{"MediumOrchid", 186, 85, 211},
	{"dark orchid", 153, 50, 204},
	{"DarkOrchid", 153, 50, 204},
	{"dark violet", 148, 0, 211},
	{"DarkViolet", 148, 0, 211},
	{"blue violet", 138, 43, 226},
	{"BlueViolet", 138, 43, 226},
	{"purple", 160, 32, 240},
	{"medium purple", 147, 112, 219},
	{"MediumPurple", 147, 112, 219},
	{"thistle", 216, 191, 216},
	{"snow1", 255, 250, 250},
	{"snow2", 238, 233, 233},
	{"snow3", 205, 201, 201},
	{"snow4", 139, 137, 137},
	{"seashell1", 255, 245, 238},
	{"seashell2", 238, 229, 222},
	{"seashell3", 205, 197, 191},
	{"seashell4", 139, 134, 130},
	{"AntiqueWhite1", 255, 239, 219},
	{"AntiqueWhite2", 238, 223, 204},
	{"AntiqueWhite3", 205, 192, 176},
	{"AntiqueWhite4", 139, 131, 120},
	{"bisque1", 255, 228, 196},
	{"bisque2", 238, 213, 183},
	{"bisque3", 205, 183, 158},
	{"bisque4", 139, 125, 107},
	{"PeachPuff1", 255, 218, 185},
	{"PeachPuff2", 238, 203, 173},
	{"PeachPuff3", 205, 175, 149},
	{"PeachPuff4", 139, 119, 101},
	{"NavajoWhite1", 255, 222, 173},
	{"NavajoWhite2", 238, 207, 161},
	{"NavajoWhite3", 205, 179, 139},
	{"NavajoWhite4", 139, 121, 94},
	{"LemonChiffon1", 255, 250, 205},
	{"LemonChiffon2", 238, 233, 191},
	{"LemonChiffon3", 205, 201, 165},
	{"LemonChiffon4", 139, 137, 112},
	{"cornsilk1", 255, 248, 220},
	{"cornsilk2", 238, 232, 205},
	{"cornsilk3", 205, 200, 177},
	{"cornsilk4", 139, 136, 120},
	{"ivory1", 255, 255, 240},
	{"ivory2", 238, 238, 224},
	{"ivory3", 205, 205, 193},
	{"ivory4", 139, 139, 131},
	{"honeydew1", 240, 255, 240},
	{"honeydew2", 224, 238, 224},
	{"honeydew3", 193, 205, 193},
	{"honeydew4", 131, 139, 131},
	{"LavenderBlush1", 255, 240, 245},
	{"LavenderBlush2", 238, 224, 229},
	{"LavenderBlush3", 205, 193, 197},
	{"LavenderBlush4", 139, 131, 134},
	{"MistyRose1", 255, 228, 225},
	{"MistyRose2", 238, 213, 210},
	{"MistyRose3", 205, 183, 181},
	{"MistyRose4", 139, 125, 123},
	{"azure1", 240, 255, 255},
	{"azure2", 224, 238, 238},
	{"azure3", 193, 205, 205},
	{"azure4", 131, 139, 139},
	{"SlateBlue1", 131, 111, 255},
	{"SlateBlue2", 122, 103, 238},
	{"SlateBlue3", 105, 89, 205},
	{"SlateBlue4", 71, 60, 139},
	{"RoyalBlue1", 72, 118, 255},
	{"RoyalBlue2", 67, 110, 238},
	{"RoyalBlue3", 58, 95, 205},
	{"RoyalBlue4", 39, 64, 139},
	{"blue1", 0, 0, 255},
	{"blue2", 0, 0, 238},
	{"blue3", 0, 0, 205},
	{"blue4", 0, 0, 139},
	{"DodgerBlue1", 30, 144, 255},
	{"DodgerBlue2", 28, 134, 238},
	{"DodgerBlue3", 24, 116, 205},
	{"DodgerBlue4", 16, 78, 139},
	{"SteelBlue1", 99, 184, 255},
	{"SteelBlue2", 92, 172, 238},
	{"SteelBlue3", 79, 148, 205},
	{"SteelBlue4", 54, 100, 139},
	{"DeepSkyBlue1", 0, 191, 255},
	{"DeepSkyBlue2", 0, 178, 238},
	{"DeepSkyBlue3", 0, 154, 205},
	{"DeepSkyBlue4", 0, 104, 139},
	{"SkyBlue1", 135, 206, 255},
	{"SkyBlue2", 126, 192, 238},
	{"SkyBlue3", 108, 166, 205},
	{"SkyBlue4", 74, 112, 139},
	{"LightSkyBlue1", 176, 226, 255},
	{"LightSkyBlue2", 164, 211, 238},
	{"LightSkyBlue3", 141, 182, 205},
	{"LightSkyBlue4", 96, 123, 139},
	{"SlateGray1", 198, 226, 255},
	{"SlateGray2", 185, 211, 238},
	{"SlateGray3", 159, 182, 205},
	{"SlateGray4", 108, 123, 139},
	{"LightSteelBlue1", 202, 225, 255},
	{"LightSteelBlue2", 188, 210, 238},
	{"LightSteelBlue3", 162, 181, 205},
	{"LightSteelBlue4", 110, 123, 139},
	{"LightBlue1", 191, 239, 255},
	{"LightBlue2", 178, 223, 238},
	{"LightBlue3", 154, 192, 205},
	{"LightBlue4", 104, 131, 139},
	{"LightCyan1", 224, 255, 255},
	{"LightCyan2", 209, 238, 238},
	{"LightCyan3", 180, 205, 205},
	{"LightCyan4", 122, 139, 139},
	{"PaleTurquoise1", 187, 255, 255},
	{"PaleTurquoise2", 174, 238, 238},
	{"PaleTurquoise3", 150, 205, 205},
	{"PaleTurquoise4", 102, 139, 139},
	{"CadetBlue1", 152, 245, 255},
	{"CadetBlue2", 142, 229, 238},
	{"CadetBlue3", 122, 197, 205},
	{"CadetBlue4", 83, 134, 139},
	{"turquoise1", 0, 245, 255},
	{"turquoise2", 0, 229, 238},
	{"turquoise3", 0, 197, 205},
	{"turquoise4", 0, 134, 139},
	{"cyan1", 0, 255, 255},
	{"cyan2", 0, 238, 238},
	{"cyan3", 0, 205, 205},
	{"cyan4", 0, 139, 139},
	{"DarkSlateGray1", 151, 255, 255},
	{"DarkSlateGray2", 141, 238, 238},
	{"DarkSlateGray3", 121, 205, 205},
	{"DarkSlateGray4", 82, 139, 139},
	{"aquamarine1", 127, 255, 212},
	{"aquamarine2", 118, 238, 198},
	{"aquamarine3", 102, 205, 170},
	{"aquamarine4", 69, 139, 116},
	{"DarkSeaGreen1", 193, 255, 193},
	{"DarkSeaGreen2", 180, 238, 180},
	{"DarkSeaGreen3", 155, 205, 155},
	{"DarkSeaGreen4", 105, 139, 105},
	{"SeaGreen1", 84, 255, 159},
	{"SeaGreen2", 78, 238, 148},
	{"SeaGreen3", 67, 205, 128},
	{"SeaGreen4", 46, 139, 87},
	{"PaleGreen1", 154, 255, 154},
	{"PaleGreen2", 144, 238, 144},
	{"PaleGreen3", 124, 205, 124},
	{"PaleGreen4", 84, 139, 84},
	{"SpringGreen1", 0, 255, 127},
	{"SpringGreen2", 0, 238, 118},
	{"SpringGreen3", 0, 205, 102},
	{"SpringGreen4", 0, 139, 69},
	{"green1", 0, 255, 0},
	{"green2", 0, 238, 0},
	{"green3", 0, 205, 0},
	{"green4", 0, 139, 0},
	{"chartreuse1", 127, 255, 0},
	{"chartreuse2", 118, 238, 0},
	{"chartreuse3", 102, 205, 0},
	{"chartreuse4", 69, 139, 0},
	{"OliveDrab1", 192, 255, 62},
	{"OliveDrab2", 179, 238, 58},
	{"OliveDrab3", 154, 205, 50},
	{"OliveDrab4", 105, 139, 34},
	{"DarkOliveGreen1", 202, 255, 112},
	{"DarkOliveGreen2", 188, 238, 104},
	{"DarkOliveGreen3", 162, 205, 90},
	{"DarkOliveGreen4", 110, 139, 61},
	{"khaki1", 255, 246, 143},
	{"khaki2", 238, 230, 133},
	{"khaki3", 205, 198, 115},
	{"khaki4", 139, 134, 78},
	{"LightGoldenrod1", 255, 236, 139},
	{"LightGoldenrod2", 238, 220, 130},
	{"LightGoldenrod3", 205, 190, 112},
	{"LightGoldenrod4", 139, 129, 76},
	{"LightYellow1", 255, 255, 224},
	{"LightYellow2", 238, 238, 209},
	{"LightYellow3", 205, 205, 180},
	{"LightYellow4", 139, 139, 122},
	{"yellow1", 255, 255, 0},
	{"yellow2", 238, 238, 0},
	{"yellow3", 205, 205, 0},
	{"yellow4", 139, 139, 0},
	{"gold1", 255, 215, 0},
	{"gold2", 238, 201, 0},
	{"gold3", 205, 173, 0},
	{"gold4", 139, 117, 0},
	{"goldenrod1", 255, 193, 37},
	{"goldenrod2", 238, 180, 34},
	{"goldenrod3", 205, 155, 29},
	{"goldenrod4", 139, 105, 20},
	{"DarkGoldenrod1", 255, 185, 15},
	{"DarkGoldenrod2", 238, 173, 14},
	{"DarkGoldenrod3", 205, 149, 12},
	{"DarkGoldenrod4", 139, 101, 8},
	{"RosyBrown1", 255, 193, 193},
	{"RosyBrown2", 238, 180, 180},
	{"RosyBrown3", 205, 155, 155},
	{"RosyBrown4", 139, 105, 105},
	{"IndianRed1", 255, 106, 106},
	{"IndianRed2", 238, 99, 99},
	{"IndianRed3", 205, 85, 85},
	{"IndianRed4", 139, 58, 58},
	{"sienna1", 255, 130, 71},
	{"sienna2", 238, 121, 66},
	{"sienna3", 205, 104, 57},
	{"sienna4", 139, 71, 38},
	{"burlywood1", 255, 211, 155},
	{"burlywood2", 238, 197, 145},
	{"burlywood3", 205, 170, 125},
	{"burlywood4", 139, 115, 85},
	{"wheat1", 255, 231, 186},
	{"wheat2", 238, 216, 174},
	{"wheat3", 205, 186, 150},
	{"wheat4", 139, 126, 102},
	{"tan1", 255, 165, 79},
	{"tan2", 238, 154, 73},
	{"tan3", 205, 133, 63},
	{"tan4", 139, 90, 43},
	{"chocolate1", 255, 127, 36},
	{"chocolate2", 238, 118, 33},
	{"chocolate3", 205, 102, 29},
	{"chocolate4", 139, 69, 19},
	{"firebrick1", 255, 48, 48},
	{"firebrick2", 238, 44, 44},
	{"firebrick3", 205, 38, 38},
	{"firebrick4", 139, 26, 26},
	{"brown1", 255, 64, 64},
	{"brown2", 238, 59, 59},
	{"brown3", 205, 51, 51},
	{"brown4", 139, 35, 35},
	{"salmon1", 255, 140, 105},
	{"salmon2", 238, 130, 98},
	{"salmon3", 205, 112, 84},
	{"salmon4", 139, 76, 57},
	{"LightSalmon1", 255, 160, 122},
	{"LightSalmon2", 238, 149, 114},
	{"LightSalmon3", 205, 129, 98},
	{"LightSalmon4", 139, 87, 66},
	{"orange1", 255, 165, 0},
	{"orange2", 238, 154, 0},
	{"orange3", 205, 133, 0},
	{"orange4", 139, 90, 0},
	{"DarkOrange1", 255, 127, 0},
	{"DarkOrange2", 238, 118, 0},
	{"DarkOrange3", 205, 102, 0},
	{"DarkOrange4", 139, 69, 0},
	{"coral1", 255, 114, 86},
	{"coral2", 238, 106, 80},
	{"coral3", 205, 91, 69},
	{"coral4", 139, 62, 47},
	{"tomato1", 255, 99, 71},
	{"tomato2", 238, 92, 66},
	{"tomato3", 205, 79, 57},
	{"tomato4", 139, 54, 38},
	{"OrangeRed1", 255, 69, 0},
	{"OrangeRed2", 238, 64, 0},
	{"OrangeRed3", 205, 55, 0},
	{"OrangeRed4", 139, 37, 0},
	{"red1", 255, 0, 0},
	{"red2", 238, 0, 0},
	{"red3", 205, 0, 0},
	{"red4", 139, 0, 0},
	{"DeepPink1", 255, 20, 147},
	{"DeepPink2", 238, 18, 137},
	{"DeepPink3", 205, 16, 118},
	{"DeepPink4", 139, 10, 80},
	{"HotPink1", 255, 110, 180},
	{"HotPink2", 238, 106, 167},
	{"HotPink3", 205, 96, 144},
	{"HotPink4", 139, 58, 98},
	{"pink1", 255, 181, 197},
	{"pink2", 238, 169, 184},
	{"pink3", 205, 145, 158},
	{"pink4", 139, 99, 108},
	{"LightPink1", 255, 174, 185},
	{"LightPink2", 238, 162, 173},
	{"LightPink3", 205, 140, 149},
	{"LightPink4", 139, 95, 101},
	{"PaleVioletRed1", 255, 130, 171},
	{"PaleVioletRed2", 238, 121, 159},
	{"PaleVioletRed3", 205, 104, 137},
	{"PaleVioletRed4", 139, 71, 93},
	{"maroon1", 255, 52, 179},
	{"maroon2", 238, 48, 167},
	{"maroon3", 205, 41, 144},
	{"maroon4", 139, 28, 98},
	{"VioletRed1", 255, 62, 150},
	{"VioletRed2", 238, 58, 140},
	{"VioletRed3", 205, 50, 120},
	{"VioletRed4", 139, 34, 82},
	{"magenta1", 255, 0, 255},
	{"magenta2", 238, 0, 238},
	{"magenta3", 205, 0, 205},
	{"magenta4", 139, 0, 139},
	{"orchid1", 255, 131, 250},
	{"orchid2", 238, 122, 233},
	{"orchid3", 205, 105, 201},
	{"orchid4", 139, 71, 137},
	{"plum1", 255, 187, 255},
	{"plum2", 238, 174, 238},
	{"plum3", 205, 150, 205},
	{"plum4", 139, 102, 139},
	{"MediumOrchid1", 224, 102, 255},
	{"MediumOrchid2", 209, 95, 238},
	{"MediumOrchid3", 180, 82, 205},
	{"MediumOrchid4", 122, 55, 139},
	{"DarkOrchid1", 191, 62, 255},
	{"DarkOrchid2", 178, 58, 238},
	{"DarkOrchid3", 154, 50, 205},
	{"DarkOrchid4", 104, 34, 139},
	{"purple1", 155, 48, 255},
	{"purple2", 145, 44, 238},
	{"purple3", 125, 38, 205},
	{"purple4", 85, 26, 139},
	{"MediumPurple1", 171, 130, 255},
	{"MediumPurple2", 159, 121, 238},
	{"MediumPurple3", 137, 104, 205},
	{"MediumPurple4", 93, 71, 139},
	{"thistle1", 255, 225, 255},
	{"thistle2", 238, 210, 238},
	{"thistle3", 205, 181, 205},
	{"thistle4", 139, 123, 139},
	{"gray0", 0, 0, 0},
	{"grey0", 0, 0, 0},
	{"gray1", 3, 3, 3},
	{"grey1", 3, 3, 3},
	{"gray2", 5, 5, 5},
	{"grey2", 5, 5, 5},
	{"gray3", 8, 8, 8},
	{"grey3", 8, 8, 8},
	{"gray4", 10, 10, 10},
	{"grey4", 10, 10, 10},
	{"gray5", 13, 13, 13},
	{"grey5", 13, 13, 13},
	{"gray6", 15, 15, 15},
	{"grey6", 15, 15, 15},
	{"gray7", 18, 18, 18},
	{"grey7", 18, 18, 18},
	{"gray8", 20, 20, 20},
	{"grey8", 20, 20, 20},
	{"gray9", 23, 23, 23},
	{"grey9", 23, 23, 23},
	{"gray10", 26, 26, 26},
	{"grey10", 26, 26, 26},
	{"gray11", 28, 28, 28},
	{"grey11", 28, 28, 28},
	{"gray12", 31, 31, 31},
	{"grey12", 31, 31, 31},
	{"gray13", 33, 33, 33},
	{"grey13", 33, 33, 33},
	{"gray14", 36, 36, 36},
	{"grey14", 36, 36, 36},
	{"gray15", 38, 38, 38},
	{"grey15", 38, 38, 38},
	{"gray16", 41, 41, 41},
	{"grey16", 41, 41, 41},
	{"gray17", 43, 43, 43},
	{"grey17", 43, 43, 43},
	{"gray18", 46, 46, 46},
	{"grey18", 46, 46, 46},
	{"gray19", 48, 48, 48},
	{"grey19", 48, 48, 48},
	{"gray20", 51, 51, 51},
	{"grey20", 51, 51, 51},
	{"gray21", 54, 54, 54},
	{"grey21", 54, 54, 54},
	{"gray22", 56, 56, 56},
	{"grey22", 56, 56, 56},
	{"gray23", 59, 59, 59},
	{"grey23", 59, 59, 59},
	{"gray24", 61, 61, 61},
	{"grey24", 61, 61, 61},
	{"gray25", 64, 64, 64},
	{"grey25", 64, 64, 64},
	{"gray26", 66, 66, 66},
	{"grey26", 66, 66, 66},
	{"gray27", 69, 69, 69},
	{"grey27", 69, 69, 69},
	{"gray28", 71, 71, 71},
	{"grey28", 71, 71, 71},
	{"gray29", 74, 74, 74},
	{"grey29", 74, 74, 74},
	{"gray30", 77, 77, 77},
	{"grey30", 77, 77, 77},
	{"gray31", 79, 79, 79},
	{"grey31", 79, 79, 79},
	{"gray32", 82, 82, 82},
	{"grey32", 82, 82, 82},
	{"gray33", 84, 84, 84},
	{"grey33", 84, 84, 84},
	{"gray34", 87, 87, 87},
	{"grey34", 87, 87, 87},
	{"gray35", 89, 89, 89},
	{"grey35", 89, 89, 89},
	{"gray36", 92, 92, 92},
	{"grey36", 92, 92, 92},
	{"gray37", 94, 94, 94},
	{"grey37", 94, 94, 94},
	{"gray38", 97, 97, 97},
	{"grey38", 97, 97, 97},
	{"gray39", 99, 99, 99},
	{"grey39", 99, 99, 99},
	{"gray40", 102, 102, 102},
	{"grey40", 102, 102, 102},
	{"gray41", 105, 105, 105},
	{"grey41", 105, 105, 105},
	{"gray42", 107, 107, 107},
	{"grey42", 107, 107, 107},
	{"gray43", 110, 110, 110},
	{"grey43", 110, 110, 110},
	{"gray44", 112, 112, 112},
	{"grey44", 112, 112, 112},
	{"gray45", 115, 115, 115},
	{"grey45", 115, 115, 115},
	{"gray46", 117, 117, 117},
	{"grey46", 117, 117, 117},
	{"gray47", 120, 120, 120},
	{"grey47", 120, 120, 120},
	{"gray48", 122, 122, 122},
	{"grey48", 122, 122, 122},
	{"gray49", 125, 125, 125},
	{"grey49", 125, 125, 125},
	{"gray50", 127, 127, 127},
	{"grey50", 127, 127, 127},
	{"gray51", 130, 130, 130},
	{"grey51", 130, 130, 130},
	{"gray52", 133, 133, 133},
	{"grey52", 133, 133, 133},
	{"gray53", 135, 135, 135},
	{"grey53", 135, 135, 135},
	{"gray54", 138, 138, 138},
	{"grey54", 138, 138, 138},
	{"gray55", 140, 140, 140},
	{"grey55", 140, 140, 140},
	{"gray56", 143, 143, 143},
	{"grey56", 143, 143, 143},
	{"gray57", 145, 145, 145},
	{"grey57", 145, 145, 145},
	{"gray58", 148, 148, 148},
	{"grey58", 148, 148, 148},
	{"gray59", 150, 150, 150},
	{"grey59", 150, 150, 150},
	{"gray60", 153, 153, 153},
	{"grey60", 153, 153, 153},
	{"gray61", 156, 156, 156},
	{"grey61", 156, 156, 156},
	{"gray62", 158, 158, 158},
	{"grey62", 158, 158, 158},
	{"gray63", 161, 161, 161},
	{"grey63", 161, 161, 161},
	{"gray64", 163, 163, 163},
	{"grey64", 163, 163, 163},
	{"gray65", 166, 166, 166},
	{"grey65", 166, 166, 166},
	{"gray66", 168, 168, 168},
	{"grey66", 168, 168, 168},
	{"gray67", 171, 171, 171},
	{"grey67", 171, 171, 171},
	{"gray68", 173, 173, 173},
	{"grey68", 173, 173, 173},
	{"gray69", 176, 176, 176},
	{"grey69", 176, 176, 176},
	{"gray70", 179, 179, 179},
	{"grey70", 179, 179, 179},
	{"gray71", 181, 181, 181},
	{"grey71", 181, 181, 181},
	{"gray72", 184, 184, 184},
	{"grey72", 184, 184, 184},
	{"gray73", 186, 186, 186},
	{"grey73", 186, 186, 186},
	{"gray74", 189, 189, 189},
	{"grey74", 189, 189, 189},
	{"gray75", 191, 191, 191},
	{"grey75", 191, 191, 191},
	{"gray76", 194, 194, 194},
	{"grey76", 194, 194, 194},
	{"gray77", 196, 196, 196},
	{"grey77", 196, 196, 196},
	{"gray78", 199, 199, 199},
	{"grey78", 199, 199, 199},
	{"gray79", 201, 201, 201},
	{"grey79", 201, 201, 201},
	{"gray80", 204, 204, 204},
	{"grey80", 204, 204, 204},
	{"gray81", 207, 207, 207},
	{"grey81", 207, 207, 207},
	{"gray82", 209, 209, 209},
	{"grey82", 209, 209, 209},
	{"gray83", 212, 212, 212},
	{"grey83", 212, 212, 212},
	{"gray84", 214, 214, 214},
	{"grey84", 214, 214, 214},
	{"gray85", 217, 217, 217},
	{"grey85", 217, 217, 217},
	{"gray86", 219, 219, 219},
	{"grey86", 219, 219, 219},
	{"gray87", 222, 222, 222},
	{"grey87", 222, 222, 222},
	{"gray88", 224, 224, 224},
	{"grey88", 224, 224, 224},
	{"gray89", 227, 227, 227},
	{"grey89", 227, 227, 227},
	{"gray90", 229, 229, 229},
	{"grey90", 229, 229, 229},
	{"gray91", 232, 232, 232},
	{"grey91", 232, 232, 232},
	{"gray92", 235, 235, 235},
	{"grey92", 235, 235, 235},
	{"gray93", 237, 237, 237},
	{"grey93", 237, 237, 237},
	{"gray94", 240, 240, 240},
	{"grey94", 240, 240, 240},
	{"gray95", 242, 242, 242},
	{"grey95", 242, 242, 242},
	{"gray96", 245, 245, 245},
	{"grey96", 245, 245, 245},
	{"gray97", 247, 247, 247},
	{"grey97", 247, 247, 247},
	{"gray98", 250, 250, 250},
	{"grey98", 250, 250, 250},
	{"gray99", 252, 252, 252},
	{"grey99", 252, 252, 252},
	{"gray100", 255, 255, 255},
	{"grey100", 255, 255, 255},
	{"dark grey", 169, 169, 169},
	{"DarkGrey", 169, 169, 169},
	{"dark gray", 169, 169, 169},
	{"DarkGray", 169, 169, 169},
	{"dark blue", 0, 0, 139},
	{"DarkBlue", 0, 0, 139},
	{"dark cyan", 0, 139, 139},
	{"DarkCyan", 0, 139, 139},
	{"dark magenta", 139, 0, 139},
	{"DarkMagenta", 139, 0, 139},
	{"dark red", 139, 0, 0},
	{"DarkRed", 139, 0, 0},
	{"light green", 144, 238, 144},
	{"LightGreen", 144, 238, 144},
	{"LightRed", 0xFF, 0xA0, 0xA0},
	{"Lightmagenta", 0xEE, 0x82, 0xEE},
	{NULL,	     0x00, 0x00, 0x00},
};

static int hexValue(unichar ch)
{
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	
	else if (ch >= 'a' && ch <= 'f')
		return 10 + ch - 'a';
	
	else if (ch >= 'A' && ch <= 'F')
		return 10 + ch - 'A';
	
	else
		ASSERT_MESG("Expected hex char but found %c", ch);
	
	return 0;
}

static Group* findGroup(GlobalStyle* global, NSString* name)
{
	NSUInteger index = [global.standardGroups indexOfObjectPassingTest:
		^BOOL(Group* candidate, NSUInteger index, BOOL* stop)
		{
			(void) index;
			(void) stop;
			return [name caseInsensitiveCompare:candidate.name] == NSOrderedSame;
		}
	];
	
	if (index != NSNotFound)
	{
		return global.standardGroups[index];
	}
	else
	{
		return [Group group:name description:@"ignored" parent:@"Normal"];
	}
}

// Reference for this stuff is at http://vimdoc.sourceforge.net/htmldoc/syntax.html although it doesn't
// define the grammar.
static void processLine(GlobalStyle* global, NSString* line)
{
	NSArray* parts = [line splitByChars:[NSCharacterSet whitespaceCharacterSet]];
	
	NSUInteger i = 0;
	while (i < parts.count && [parts[i] length] == 0)
		++i;

	if (i < parts.count)
	{
		// hi link Number	Constant
		if (([parts[i] isEqualToString:@"highlight"] || [parts[i] isEqualToString:@"hi"]) && [parts[i+1] isEqualToString:@"link"])
		{
			Group* group = findGroup(global, parts[i+2]);
			
			if (!group.link)
				group.link = [findGroup(global, parts[i+3]) name];
		}
		
		// hi! link MoreMsg Comment
		else if (([parts[i] isEqualToString:@"highlight!"] || [parts[i] isEqualToString:@"hi!"]) && [parts[i+1] isEqualToString:@"link"])
		{
			Group* group = findGroup(global, parts[i+2]);
			group.link = [findGroup(global, parts[i+3]) name];
		}
		
		// hi clear
		else if ([parts[i] isEqualToString:@"hi"] && [parts[i+1] isEqualToString:@"clear"])
		{
			// ignored
		}
		
		// hi comment		guifg=gray		ctermfg=gray	ctermbg=darkBlue	gui=bold
		else if ([parts[i] isEqualToString:@"highlight"] || [parts[i] isEqualToString:@"hi"] || [parts[i] isEqualToString:@":highlight"] || [parts[i] isEqualToString:@":hi"])
		{
			bool hasColor = false;
			for (NSUInteger j = i+2; j < parts.count && !hasColor; ++j)
			{
				if ([parts[j] hasPrefix:@"guifg="] || [parts[j] hasPrefix:@"guibg="] || ([parts[j] hasPrefix:@"gui="] && ![parts[j] isEqualToString:@"gui=NONE"]))
				{
					NSString* name = [parts[j] substringFromIndex:6];
					if (![name isEqualToString:@"NONE"] && ![name isEqualToString:@"bg"] && ![name isEqualToString:@"fg"])
						hasColor = true;
				}
			}
			
			if (hasColor)
			{
				Group* group = findGroup(global, parts[i+1]);
				
				ElementStyle* element = [global getElement:group.name];
				for (NSUInteger j = i+2; j < parts.count; ++j)
				{
					if ([parts[j] hasPrefix:@"guifg="] && ![parts[j] isEqualToString:@"guifg=NONE"])
					{
						element.fgColor = [parts[j] substringFromIndex:6];
					}
					else if ([parts[j] hasPrefix:@"guibg="] && ![parts[j] isEqualToString:@"guibg=NONE"])
					{
						if ([group.name isEqualToString:@"Normal"])
							global.bgColor = [parts[j] substringFromIndex:6];
						else
							element.bgColor = [parts[j] substringFromIndex:6];
					}
					else if ([parts[j] hasPrefix:@"gui="])
					{
						element.styles = [[parts[j] substringFromIndex:4] componentsSeparatedByString:@","];
					}
				}
			}
		}

		// set background=dark
		else if ([parts[i] hasPrefix:@"set"] || [parts[i] hasPrefix:@":set"])
		{
			if ([parts[i+1] isEqualToString:@"background=dark"] || [parts[i+1] isEqualToString:@"bg=dark"])
			{
				global.bgColor = @"black";
				global.fgColor = @"white";
			}
			else if ([parts[i+1] isEqualToString:@"background=light"] || [parts[i+1] isEqualToString:@"bg=light"] || [parts[i+1] isEqualToString:@"bg&"])
			{
				global.bgColor = @"gray97";
				global.fgColor = @"black";
			}
			else
			{
				printf("   Unknown set: %s\n", STR(line));
			}
		}
		
		// " Last Change:	2003 May 02
		// if exists("syntax_on")
		// endif
		// syntax reset
		// let g:colors_name = "pablo"
		else if ([parts[i] hasPrefix:@"\""] || [parts[i] isEqualToString:@"if"] || [parts[i] isEqualToString:@"else"] || [parts[i] isEqualToString:@"elseif"] || [parts[i] isEqualToString:@"endif"] || [parts[i] isEqualToString:@"end"] || [parts[i] isEqualToString:@"syntax"] || [parts[i] isEqualToString:@"let"] || [parts[i] isEqualToString:@"runtime"] || [parts[i] isEqualToString:@"runtime!"] || [parts[i] isEqualToString:@"finish"] || [parts[i] isEqualToString:@"syn"] || [parts[i] isEqualToString:@"unlet"] || [parts[i] isEqualToString:@"echomsg"])
		{
			// these are ignored
		}

		else
		{
			printf("   Unknown line: %s\n", STR(line));
		}
	}
}

static NSColor* getColor(GlobalStyle* global, NSString* arg)
{
	NSColor* color = nil;
	
	if (arg)
	{
		if ([arg hasPrefix:@"#"])
		{
			int red   = 16*hexValue([arg characterAtIndex:1]) + hexValue([arg characterAtIndex:2]);
			int green = 16*hexValue([arg characterAtIndex:3]) + hexValue([arg characterAtIndex:4]);
			int blue  = 16*hexValue([arg characterAtIndex:5]) + hexValue([arg characterAtIndex:6]);
			
			color = [NSColor colorWithCalibratedRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1.0];
		}
		else if (([arg isEqualToString:@"fg"] || [arg isEqualToString:@"FG"]) && global)
		{
			color = getColor(nil, global.fgColor);
		}
		else if (([arg isEqualToString:@"bg"] || [arg isEqualToString:@"BG"]) && global)
		{
			color = getColor(nil, global.bgColor);
		}
		else
		{
			const char* name = arg.UTF8String;
			int i = 0;
			while (colors[i].name)
			{
				if (strcasecmp(colors[i].name, name) == 0)
				{
					color = [NSColor colorWithCalibratedRed:colors[i].red/255.0 green:colors[i].green/255.0 blue:colors[i].blue/255.0 alpha:1.0];
					break;
				}
				++i;
			}
		}
		
		if (!color)
			printf("   Unknown color: %s\n", STR(arg));
	}
	
	return color;
}

// We ignore the standout style.
static NSDictionary* getAttributes(GlobalStyle* global, NSString* name, ElementStyle* style)
{
	NSMutableDictionary* attrs = [NSMutableDictionary new];
	
	NSString* fontName;
	if ([style.styles containsObject:@"bold"] && [style.styles containsObject:@"italic"])
		fontName = @"Menlo Bold Italic";
	else if ([style.styles containsObject:@"bold"])
		fontName = @"Menlo Bold";
	else if ([style.styles containsObject:@"italic"])
		fontName = @"Menlo Italic";
	else
		fontName = @"Menlo";
	float size = 16;
	if ([name isEqualToString:@"Structure"] || [name isEqualToString:@"PreCondit"])
		size *= 1.25;
	attrs[NSFontAttributeName] = [NSFont fontWithName:fontName size:size];
	
	NSColor* fgColor = getColor(global, style.fgColor);
	if ([name isEqualToString:@"Structure"])				// TODO: not sure we really want to do this
	{
		NSShadow* shadow = [NSShadow new];
		[shadow setShadowColor:[fgColor colorWithAlphaComponent:0.2]];
		[shadow setShadowOffset:NSMakeSize(1.0, -2.02)];
		[shadow setShadowBlurRadius:1.0];
		
		attrs[NSShadowAttributeName] = shadow;
	}
	
	if ([style.styles containsObject:@"underline"])
		attrs[NSUnderlineStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleSingle];
	else if ([style.styles containsObject:@"undercurl"])
		attrs[NSUnderlineStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleDouble];

	NSColor* bgColor = getColor(global, style.bgColor);
	if ([style.styles containsObject:@"reverse"] || [style.styles containsObject:@"inverse"])
	{
		if (fgColor)
			attrs[NSBackgroundColorAttributeName] = fgColor;
		if (bgColor)
			attrs[NSForegroundColorAttributeName] = bgColor;
	}
	else
	{
		if (fgColor)
			attrs[NSForegroundColorAttributeName] = fgColor;
		if (bgColor)
			attrs[NSBackgroundColorAttributeName] = bgColor;
	}
	
	return attrs;
}

static void addLine(NSMutableAttributedString* text, GlobalStyle* global, NSString* line, NSString* name, ElementStyle* style)
{
	NSUInteger loc = text.length;
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:line];
	[text appendAttributedString:str];
	NSRange range = NSMakeRange(loc, line.length);
	
	NSDictionary* attrs = getAttributes(global, name, style);
	[text setAttributes:attrs range:range];
}

static void addComment(NSMutableAttributedString* text, NSString* path, GlobalStyle* global)
{
	ElementStyle* comment = [ElementStyle new];
	comment.fgColor = @"#EF122E";
	comment.styles = @[@"italic"];
	
	NSArray* args = [[NSProcessInfo processInfo] arguments];
	NSString* line = [NSString stringWithFormat:@"# Generated by %@\n# Original file was at %@\n\n", [args componentsJoinedByString:@" "], path];
	addLine(text, global, line, @"Comment", comment);
}

static bool addSpecialMissingElement(NSMutableAttributedString* text, NSString* name, GlobalStyle* global)
{
	if ([name isEqualToString:@"Argument"])
	{
		ElementStyle* style = global.elements[@"Constant"];
		if (style)
		{
			// Argument is Mimsy specific
			style = [style addStyle:@"italic"];
			style = [style removeStyle:@"bold"];
			addLine(text, global, @"Argument: formal argument\n", name, style);
			return true;
		}
	}
	else if ([name isEqualToString:@"DocComment"])
	{
		ElementStyle* style = global.elements[@"Comment"];
		if (style)
		{
			// DocComment is Mimsy specific
			style = [style addStyle:@"bold"];
			addLine(text, global, @"DocComment: comment used to generate documentation\n", name, style);
			return true;
		}
	}
	// Attribute is also Mimsy specific but there doesn't seem to be an obvious way to synthesize it.
	else if ([name isEqualToString:@"Character"])
	{
		ElementStyle* style = global.elements[@"String"];
		if (style)
		{
			// Treat Character like String if it is missing
			addLine(text, global, @"Character: a character constant: 'c', '\\n'\n", name, style);
			return true;
		}
	}
	else if ([name isEqualToString:@"Function"])
	{
		ElementStyle* style = global.elements[@"Identifier"];
		if (!style)
			style = global.elements[@"Normal"];

		// Function is really nice to have, so we'll add it if it's missing
		style = [style addStyle:@"bold"];
		addLine(text, global, @"Function: function name (also: methods for classes)\n", name, style);
		return true;
	}
	else if ([name isEqualToString:@"Error"])
	{
		// Red should work with pretty much every background.
		ElementStyle* style = global.elements[@"Normal"];
		style = [style changeFg:@"red"];
		addLine(text, global, @"Error: any erroneous construct\n", name, style);
		return true;
	}
	else if ([name isEqualToString:@"Warning"])
	{
		// Light salmon will probably work with pretty much every background.
		ElementStyle* style = global.elements[@"Normal"];
		style = [style changeFg:@"light salmon"];
		addLine(text, global, @"Warning: a problem which may not be an error\n", name, style);
		return true;
	}
	else if ([name isEqualToString:@"Underlined"])
	{
		// Underlining is always OK.
		ElementStyle* style = global.elements[@"Normal"];
		style = [style addStyle:@"underline"];
		addLine(text, global, @"Underlined: text that stands out, HTML links\n", name, style);
		return true;
	}
	
	return false;
}

static ElementStyle* findMissingElement(GlobalStyle* global, Group* group)
{
	ElementStyle* element = nil;
	
	NSUInteger nesting = 0;
	while (group)
	{
		element = global.elements[group.name];
		if (element)
			break;
		
		if (group.link)
			group = findGroup(global, group.link);
		else if (group.parent)
			group = findGroup(global, group.parent);
		else
			break;
		
		++nesting;
		assert(nesting < 100);
	}
	
	return element;
}

static void addMissingElement(NSMutableAttributedString* text, Group* group, GlobalStyle* global)
{
	ElementStyle* element = findMissingElement(global, group);
	if (element)
	{
		NSString* line = [NSString stringWithFormat:@"%@: %@\n", group.name, group.description];
		addLine(text, global, line, group.name, element);
	}
	else
	{
		printf("   couldn't find an element for %s\n", STR(group.name));
	}
}

static NSMutableAttributedString* createText(NSString* path, GlobalStyle* global)
{
	NSMutableAttributedString* text = [NSMutableAttributedString new];
	addComment(text, path, global);
	
	for (Group* group in global.standardGroups)
	{
		if (group.name)
		{
			ElementStyle* element = global.elements[group.name];
			if (element)
			{
				NSString* line = [NSString stringWithFormat:@"%@: %@\n", group.name, group.description];
				addLine(text, global, line, group.name, element);
				element.processed = true;
			}
			else
			{
				if (!addSpecialMissingElement(text, group.name, global))
					addMissingElement(text, group, global);
			}
		}
		else
		{
			NSAttributedString* str = [[NSAttributedString alloc] initWithString:@"\n"];
			[text appendAttributedString:str];
		}
	}
	
	for (NSString* name in global.elements)
	{
		if ([global.ignoredGroups indexOfObject:name] == NSNotFound)
		{
			ElementStyle* style = global.elements[name];
			if (!style.processed)
				printf("   Unknown group: %s\n", STR(name));
		}
	}
	
	return text;
}

static NSError* saveMetadata(NSString* path, GlobalStyle* global, NSString* outDir)
{
	NSError* error = nil;
	
	NSColor* color = getColor(nil, global.bgColor);
	if (color)
	{
		NSString* fname = [[path lastPathComponent] stringByDeletingPathExtension];
		NSString* outPath = [[outDir stringByAppendingPathComponent:fname] stringByAppendingPathExtension:@"rtf"];
		NSError* error = [Metadata writeCriticalDataTo:outPath named:@"back-color" with:color];
		if (error)
		{
			NSString* reason = [error localizedFailureReason];
			printf("   FAILED writing back-color: %s\n", STR(reason));
		}
	}
	
	return error;
}

static NSError* saveFile(NSString* path, NSMutableAttributedString* text, NSString* outDir)
{
	NSError* error = nil;
	
	NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
	NSData* data = [text dataFromRange:NSMakeRange(0, text.length) documentAttributes:attrs error:&error];
	if (data)
	{
		NSString* fname = [[path lastPathComponent] stringByDeletingPathExtension];
		NSString* outPath = [[outDir stringByAppendingPathComponent:fname] stringByAppendingPathExtension:@"rtf"];
		BOOL succeed = [data writeToFile:outPath options:0 error:&error];
		if (!succeed)
		{
			NSString* reason = [error localizedFailureReason];
			printf("   FAILED writing RTF: %s\n", STR(reason));
		}
	}
	else
	{
		NSString* reason = [error localizedFailureReason];
		printf("   FAILED generating RTF: %s\n", STR(reason));
	}
	
	return error;
}

static bool hasColors(GlobalStyle* global)
{
	for (NSString* name in global.elements)
	{
		ElementStyle* style = global.elements[name];
		if (![style.fgColor isEqualToString:@"black"] || style.bgColor)
			return true;
	}
	
	return false;
}

static bool convertFile(NSString* path, NSString* outDir)
{
	NSError* error = nil;
	
	printf("Converting %s\n", STR(path));
	NSArray* lines = [Utils readLines:path outError:&error];
	if (lines)
	{
		GlobalStyle* global = [GlobalStyle new];
		for (NSString* line in lines)
		{
			processLine(global, line);
		}
		
		if (hasColors(global))
		{
			NSMutableAttributedString* text = createText(path, global);
			error = saveFile(path, text, outDir);
			if (!error)
				error = saveMetadata(path, global, outDir);
		}
		else
		{
			printf("   skipping (doesn't set gui colors)\n");
		}
	}
	else
	{
		NSString* reason = [error localizedFailureReason];
		printf("   FAILED to load the file: %s\n", STR(reason));
	}
	
	return error == nil;
}

void convertVIMFiles(NSString* vimDIR, NSString* outDir)
{
	__block int passed = 0;
	__block int failed = 0;

	NSError* error = nil;
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:outDir])
	{
		BOOL created = [fm createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:&error];
		if (!created)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't create the '%@' directory: %@", outDir, reason];
			printf("%s\n", STR(mesg));
			return;
		}
	}
	
	Glob* glob = [[Glob alloc] initWithGlob:@"*.vim"];
	[Utils enumerateDir:vimDIR glob:glob error:&error block:^(NSString* path)
		{if (convertFile(path, outDir)) ++passed; else ++failed;}];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Couldn't read VIM files from '%@': %@", vimDIR, reason];
		printf("%s\n", STR(mesg));
		return;
	}

	if (failed == 0)
		printf("Converted %d files with no errors.\n", passed);
	else
		printf("Converted %d files with %d errors.\n", passed, failed);
}
