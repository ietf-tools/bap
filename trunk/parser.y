%{
/*
 * Bill's ABNF parser.
 */

#include "common.h"
%}

%union {
	char *string;
	struct range range;
}

%token <string> CHARVAL PROSEVAL BINVAL DECVAL HEXVAL RULENAME
%token <range> BINVALRANGE DECVALRANGE HEXVALRANGE REPEAT
%token COMMENT WSP EQSLASH CRLF

%type <string> numval
%type <range> numvalrange

%%

rulelist: rules
	| rulelist rules
	;

rules:	  rule
	| starcwsp cnl
	;

starwsp:
	| WSP
	;

rule:	starwsp RULENAME definedas elements cnl { printf("Parse rule %s\n", $2); }
	| error RULENAME definedas elements cnl { printf("Error rule %s\n", $2); }

	;

definedas:	starcwsp EQSLASH starcwsp
	| starcwsp '=' starcwsp
	;

elements:	alternation starcwsp
	;

cwsp:	{ requirewsp(1); } WSP { requirewsp(0); }
	;

starcwsp:
	;

cnl:	  comment
	| CRLF
	;

comment:  COMMENT CRLF
	;

alternation:
	  concatenation
	| alternation starcwsp '/' starcwsp concatenation
	;

concatenation:
	  repetition
	| concatenation cwsp starcwsp repetition
	;

repetition:
	  element
	| REPEAT element	{ ; }
	;

numval:   BINVAL
	| DECVAL
	| HEXVAL
	;

numvalrange:
	  BINVALRANGE
	| DECVALRANGE
	| HEXVALRANGE
	;

element:
	  RULENAME		{ printf("element rule %s\n"); }
	| group	
	| option
	| CHARVAL		{ ; }
	| numval		{ ; }
	| numvalrange		{ ; }
	| PROSEVAL		{ ; }
	;

group:	'(' starcwsp alternation starcwsp ')'
	;

option:	'[' starcwsp alternation starcwsp ']'
	;

