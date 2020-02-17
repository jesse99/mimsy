#import "convertVIMFiles.h"

#import "ColorCategory.h"
#import "Glob.h"
#import "Metadata.h"
#import "Utils.h"

@interface Group : NSObject
@property NSString* name;				// eg "Conditional"
@property NSString* info;           // eg "if, then, else, endif, switch, etc."
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
+ (id)group:(NSString*)name info:(NSString*)info parent:(NSString*)parent
{
	Group* group = [Group new];
	
	group.name = name;
	group.info = info;
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
		[Group group:@"Normal" info:@"normal text" parent:nil],
		[Group group:nil info:nil parent:nil],

		[Group group:@"Type" info:@"int, long, char, etc." parent:@"Normal"],
		[Group group:@"Structure" info:@"name in a struct or class declaration" parent:@"Type"],
		[Group group:@"UserType" info:@"a user defined type name" parent:@"Type"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Identifier" info:@"any variable name" parent:@"Normal"],
		[Group group:@"Argument" info:@"formal argument" parent:@"Constant"],	// think Constant parent looks a bit better
		[Group group:@"Function" info:@"function name (also: methods for classes)" parent:@"Identifier"],
		[Group group:@"Macro" info:@"name of a macro: NDEBUG, __FILE, MIN, etc" parent:@"Identifier"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Statement" info:@"any statement" parent:@"Normal"],
		[Group group:@"Conditional" info:@"if, then, else, endif, switch, etc." parent:@"Statement"],
		[Group group:@"Exception" info:@"try, catch, throw" parent:@"Statement"],
		[Group group:@"Keyword" info:@"any other keyword" parent:@"Statement"],
		[Group group:@"Label" info:@"target of a goto or a case in a switch statement" parent:@"Statement"],
		[Group group:@"Operator" info:@"\"sizeof\", \"+\", \"*\", etc." parent:@"Statement"],
		[Group group:@"Repeat" info:@"for, do, while, etc." parent:@"Statement"],
		[Group group:@"StorageClass" info:@"static, register, volatile, etc." parent:@"Statement"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Constant" info:@"any constant" parent:@"Normal"],
		[Group group:@"Boolean" info:@"a boolean constant: TRUE, false, etc." parent:@"Constant"],
		[Group group:@"Character" info:@"a character constant: 'c', '\\n'" parent:@"Constant"],
		[Group group:@"Float" info:@"a floating point constant: 2.3e10" parent:@"Constant"],
		[Group group:@"Number" info:@"a number constant: 234, 0xff" parent:@"Constant"],
		[Group group:@"String" info:@"a string constant: \"this is a string\"" parent:@"Constant"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Comment" info:@"any comment" parent:@"Normal"],
		[Group group:@"DocComment" info:@"comment used to generate documentation" parent:@"Comment"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"PreProc" info:@"generic Preprocessor" parent:@"Normal"],
		[Group group:@"Define" info:@"preprocessor #define" parent:@"PreProc"],
		[Group group:@"Include" info:@"preprocessor #include" parent:@"PreProc"],
		[Group group:@"PreCondit" info:@"preprocessor #if, #else, #endif, etc." parent:@"PreProc"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Special" info:@"any special symbol" parent:@"Normal"],
		[Group group:@"Debug" info:@"debugging statements" parent:@"Special"],
		[Group group:@"Delimiter" info:@"character that needs attention" parent:@"Special"],
		[Group group:@"SpecialChar" info:@"special character in a constant" parent:@"Special"],
		[Group group:@"SpecialComment" info:@"special things inside a comment" parent:@"Special"],
		[Group group:@"Attribute" info:@"e.g. in C#, Rust, Python (decorator)" parent:@"Special"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"Error" info:@"any erroneous construct" parent:@"Normal"],
		[Group group:@"Underlined" info:@"text that stands out, HTML links" parent:@"Normal"],
		[Group group:@"Warning" info:@"a problem which may not be an error" parent:@"Normal"],
		[Group group:nil info:nil parent:nil],
	
		[Group group:@"DiffAdd" info:@"added line" parent:@"Normal"],
		[Group group:@"DiffChange" info:@"changed line" parent:@"Normal"],
		[Group group:@"DiffDelete" info:@"deleted line" parent:@"Normal"],
		[Group group:@"DiffText" info:@"changed text within a changed line" parent:@"Normal"]
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
		return [Group group:name info:@"ignored" parent:@"Normal"];
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
		if (([arg isEqualToString:@"fg"] || [arg isEqualToString:@"FG"]) && global)
		{
			color = getColor(nil, global.fgColor);
		}
		else if (([arg isEqualToString:@"bg"] || [arg isEqualToString:@"BG"]) && global)
		{
			color = getColor(nil, global.bgColor);
		}
		else
		{
			color = [NSColor colorWithVIMName:arg];
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
		size *= (float) 1.25;
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

static void addComment(NSMutableAttributedString* text, MimsyPath* path, GlobalStyle* global)
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
		NSString* line = [NSString stringWithFormat:@"%@: %@\n", group.name, group.info];
		addLine(text, global, line, group.name, element);
	}
	else
	{
		printf("   couldn't find an element for %s\n", STR(group.name));
	}
}

static NSMutableAttributedString* createText(MimsyPath* path, GlobalStyle* global)
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
				NSString* line = [NSString stringWithFormat:@"%@: %@\n", group.name, group.info];
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

static NSError* saveMetadata(MimsyPath* path, GlobalStyle* global, MimsyPath* outDir)
{
	NSError* error = nil;
	
	NSColor* color = getColor(nil, global.bgColor);
	if (color)
	{
		NSString* fname = [[path lastComponent] stringByDeletingPathExtension];
		MimsyPath* outPath = [[outDir appendWithComponent:fname] appendWithExtensionName:@"rtf"];
		NSError* error = [Metadata writeCriticalDataTo:outPath named:@"back-color" with:color];
		if (error)
		{
			NSString* reason = [error localizedFailureReason];
			printf("   FAILED writing back-color: %s\n", STR(reason));
		}
	}
	
	return error;
}

static NSError* saveFile(MimsyPath* path, NSMutableAttributedString* text, MimsyPath* outDir)
{
	NSError* error = nil;
	
	NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
	NSData* data = [text dataFromRange:NSMakeRange(0, text.length) documentAttributes:attrs error:&error];
	if (data)
	{
		NSString* fname = [[path lastComponent] stringByDeletingPathExtension];
		MimsyPath* outPath = [[outDir appendWithComponent:fname] appendWithExtensionName:@"rtf"];
		BOOL succeed = [data writeToFile:outPath.asString options:0 error:&error];
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

static bool convertFile(MimsyPath* path, MimsyPath* outDir)
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

void convertVIMFiles(MimsyPath* vimDIR, MimsyPath* outDir)
{
	__block int passed = 0;
	__block int failed = 0;

	NSError* error = nil;
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:outDir.asString])
	{
		BOOL created = [fm createDirectoryAtPath:outDir.asString withIntermediateDirectories:YES attributes:nil error:&error];
		if (!created)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't create the '%@' directory: %@", outDir, reason];
			printf("%s\n", STR(mesg));
			return;
		}
	}
	
	Glob* glob = [[Glob alloc] initWithGlob:@"*.vim"];
	[Utils enumerateDir:vimDIR glob:glob error:&error block:^(MimsyPath* path)
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
