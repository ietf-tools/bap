%{
/*
 * Bill's ABNF parser.
 */

#include "common.h"
#include "y.tab.h"
%}

bit	[01]
digit	[0-9]
hexdig	[0-9A-Fa-f]

rulename	[A-Za-z][-0-9A-Za-z]*
wsp	[ \t]

mycrlf	(\n\r|\r\n|\r|\n)

%%
\"[ !#-\177]*["\r\n]	{ return CHARVAL; }
\<[ -=?-\177]*>	{ return PROSEVAL; }
{rulename}		{ yylval.string = strdup(yytext); return RULENAME; }
%b{bit}+-{bit}+	{ return BINVALRANGE; }
%b{bit}+(\.{bit}+)*	{ return BINVAL; }
%d{digit}+-{digit}+	{ return DECVALRANGE; }
%d{digit}+(\.{digit}+)*	{ return DECVAL; }
%x{hexdig}+-{hexdig}+	{ return HEXVALRANGE; }
%x{hexdig}+(\.{hexdig}+)*	{ return HEXVAL; }
{digit}*\*{digit}*	{ return REPEAT; }
{digit}+		{ return REPEAT; }
=\/			{ return EQSLASH; }
({wsp}+|(;[^\r\n]*)|{mycrlf}{wsp}+)+	{ return CWSP; }
{mycrlf}		{ return CRLF; }
[][()=/]		{ return yytext[0]; }
.			{ return yytext[0]; }
%%
