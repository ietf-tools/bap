#include <stdio.h>

main()
{
#ifdef YYDEBUG
	extern int yydebug;

	yydebug = 1;
#endif
	yyparse();
}

int
yyerror(char *s)
{
	fprintf(stderr, "yyerror: %s\n", s);
}
