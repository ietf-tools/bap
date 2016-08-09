AC_INIT(bap, 1.4)

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
dnl
if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE, 1, [define if we're using bison])
fi

AC_PROG_LEX
if test "$ac_cv_prog_LEX" = ":"; then
        AC_ERROR([please install flex])
fi

AC_REPLACE_FUNCS(hcreate)

AC_CONFIG_HEADERS(config.h)

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([tests/baptest abnf.cgi], [chmod +x tests/baptest])
AC_OUTPUT
