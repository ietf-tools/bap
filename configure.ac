dnl $Fenner: abnf-parser/configure.ac,v 1.8 2005/02/03 05:40:17 fenner Exp $
dnl
dnl Boy does modern autoconf make it hard to have a small ./configure.
dnl Sorry that it's so huge for almost no configuration.

AC_INIT(bap, 1.1)

AC_PROG_CC
AC_PROG_YACC

dnl byacc on FreeBSD 4.3 gives weird parsing problems.
dnl byacc on FreeBSD 4.10 seems fine.
if test "$ac_cv_prog_YACC" = "byacc"; then
	AC_WARN([using byacc has caused inexplicable runtime behavior;])
	AC_WARN([if you get incomprehensible errors when parsing])
	AC_WARN([grammars, install bison and try again.])
fi

dnl The bap -d argument only works with bison, so enable it
dnl  if we're using bison.
dnl if test "$ac_cv_prog_YACC" = "bison -y"; then
	dnl doesn't seem to work with bison 2.1
	dnl AC_DEFINE(YYERROR_VERBOSE, 1, [define if we're using bison])
dnl fi

AC_REPLACE_FUNCS(hcreate)

AC_CONFIG_HEADERS(config.h)

AC_OUTPUT(Makefile)
