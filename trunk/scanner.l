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

%s NEEDWSP
%%
\"[ !#-\177]*["\r\n]	{ return CHARVAL; }
\<[ -=?-\177]*>	{ return PROSEVAL; }
;.*		;
{rulename}		{ yylval.string = yytext; return RULENAME; }
%b{bit}+-{bit}+	{ return BINVALRANGE; }
%b{bit}+(\.{bit}+)*	{ return BINVAL; }
%d{digit}+-{digit}+	{ return DECVALRANGE; }
%d{digit}+(\.{digit}+)*	{ return DECVAL; }
%x{hexdig}+-{hexdig}+	{ return HEXVALRANGE; }
%x{hexdig}+(\.{hexdig}+)*	{ return HEXVAL; }
{digit}*\*{digit}*	{ return REPEAT; }
{digit}+		{ return REPEAT; }
=\/			{ return EQSLASH; }
<NEEDWSP>{wsp}		{ return WSP; }
{mycrlf}?{wsp}+		;
{mycrlf}		{ return CRLF; }
[][{}=/]		{ return yytext[0]; }
%%

void
requirewsp(int i)
{
	if (i) {
		BEGIN NEEDWSP;
	} else {
		BEGIN 0;
	}
}
