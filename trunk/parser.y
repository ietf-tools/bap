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
%token CWSP EQSLASH CRLF

%type <string> numval
%type <range> numvalrange

%%

rulelist: rules
	| rulelist rules
	;

rules:	  rule
	| starcwsp CRLF
	;

rule:	RULENAME definedas elements starcwsp CRLF { printf("Parse rule %s\n", $1); }

	;

definedas:	starcwsp EQSLASH starcwsp
	| starcwsp '=' starcwsp
	;

cwsp:	  CWSP
	;

starcwsp:
	| CWSP
	;

elements:
	  repetition
	| elements cwsp repetition
	| elements starcwsp '/' starcwsp repetition
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
	  RULENAME		{ printf("element rule %s\n", $1); }
	| group	
	| option
	| CHARVAL		{ ; }
	| numval		{ ; }
	| numvalrange		{ ; }
	| PROSEVAL		{ ; }
	;

group:	'(' starcwsp elements starcwsp ')'
	;

option:	'[' starcwsp elements starcwsp ']'
	;

