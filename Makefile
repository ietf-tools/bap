OBJS=	parser.o scanner.o main.o hcreate.o

D=	-g
CFLAGS=	-DYYERROR_VERBOSE -DYYDEBUG ${D}
YACC=	bison -y -v

p:	${OBJS}
	cc -o $@ ${D} ${OBJS} -ll

scanner.c:	scanner.l
parser.c:	parser.y

clean:
	rm p scanner.c parser.c $(OBJS)
