dnl $Fenner: abnf-parser/configure.ac,v 1.2 2002/07/30 17:08:12 fenner Exp $

AC_INIT(bap, 1.0)
AC_REVISION($Revision$)

AC_PROG_CC
AC_PROG_YACC

dnl The bap -d argument only works with bison, so enable it
dnl  if we're using bison.
if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE)
fi

AC_REPLACE_FUNCS(hcreate)

AC_OUTPUT(Makefile)
