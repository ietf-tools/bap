%{
/*
 * Bill's ABNF parser.
 */

#include "common.h"
#include "y.tab.h"

int yylineno = 1;

char badchar;
%}

bit	[01]
digit	[0-9]
hexdig	[0-9A-Fa-f]

rulename	[A-Za-z][-0-9A-Za-z]*
wsp	[ \t]

mycrlf	(\n\r|\r\n|\r|\n)

%s SKIP

%%
\"[ !#-\177]*["\r\n]	{
			char *p;
			yylval.string = strdup(yytext + 1);
			p = &yylval.string[strlen(yylval.string) - 1];
			if (*p == '"')
				*p = '\0';
			return CHARVAL;
			}
\<[ -=?-\177]*>		{
			yylval.string = strdup(yytext + 1);
			yylval.string[strlen(yylval.string) - 1] = '\0';
			return PROSEVAL;
			}
{rulename}		{ yylval.string = strdup(yytext); return RULENAME; }
%b{bit}+-{bit}+	{ yylval.range.lo = 0; yylval.range.hi = 1; return BINVALRANGE; }
%b{bit}+(\.{bit}+)*	{ yylval.string = "BIN"; return BINVAL; }
%d{digit}+-{digit}+	{ yylval.range.lo = 0; yylval.range.hi = 1; return DECVALRANGE; }
%d{digit}+(\.{digit}+)*	{ yylval.string = "DEC"; return DECVAL; }
%x{hexdig}+-{hexdig}+	{ yylval.range.lo = 0; yylval.range.hi = 1; return HEXVALRANGE; }
%x{hexdig}+(\.{hexdig}+)*	{ yylval.string = "HEX"; return HEXVAL; }
{digit}*\*{digit}*	{ yylval.range.lo = 5; yylval.range.hi = 10; return REPEAT; }
{digit}+		{ yylval.range.lo = 5; yylval.range.hi = 5; return REPEAT; }
=\/			{ return EQSLASH; }
({wsp}+|(;[^\r\n]*)|{mycrlf}{wsp}+)+	{ char *p = yytext;
				while (*p) {
					if (*p == '\r') {
						yylineno++;
						if (*(p+1) == '\n')
							p++;
					}
					if (*p == '\n') {
						yylineno++;
						if (*(p+1) == '\r')
							p++;
					}
					p++;
				}
				return CWSP; }
{mycrlf}		{ yylineno++; return CRLF; }
[][()=/]		{ return yytext[0]; }
\|			{ /* if (!permissive) BEGIN(SKIP); */ return yytext[0]; }
.			{ badchar = yytext[0]; BEGIN(SKIP); }
<SKIP>.*{mycrlf}	{ 	char buf[80];
				sprintf(buf, "Illegal character `%c' - skipping to end of line", badchar);
				yyerror(buf);
				yylineno++;
				BEGIN(INITIAL);
				return CRLF; }
%%
