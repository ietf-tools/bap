OBJS=	parser.o scanner.o main.o

CFLAGS=	-DYYERROR_VERBOSE -DYYDEBUG
YACC=	bison -y -v

p:	${OBJS}
	cc -o $@ ${OBJS} -ll

scanner.c:	scanner.l
parser.c:	parser.y

clean:
	rm p scanner.c parser.c $(OBJS)
