/*
 * Bill's ABNF Parser
 * $Fenner: abnf-parser/common.h,v 1.7 2002/08/08 05:24:45 fenner Exp $
 */

struct range {
	int lo;
	int hi;
};

struct rule {
	char *name;		/* as defined or used */
	char *lowername;	/* for hash key */
	int line;		/* line of definition */
	struct object *rule;	/* definition */
	int used;		/* was it referenced? */
	struct rule *next;	/* doubly */
	struct rule *prev;	/* linked list */
};

/*
 * Types:
 * - Alternation
 *   - left + right
 * - Rule
 *   - repetition
 *   - concatenation
 * - Terminal string
 *   - case sensitive or not
 *   - repetition
 *   - concatenation
 * - Terminal character range
 *   - repetition
 *   - concatenation
 */
#define	T_ALTERNATION	1
#define	T_RULE		2
#define	T_GROUP		3
#define	T_TERMSTR	4
#define	T_TERMRANGE	5
#define	T_PROSE		6

typedef struct object {
	int type;
	struct object *next;
	union {
		struct {
			struct object *left;
			struct object *right;
		} alternation;
		struct {
			struct range repetition;
			union {
			    struct {
				    char *name;	/* for forward ref. */
				    struct rule *rule;
			    } rule;
			    struct object *group;
			    struct {
				    char *str;
				    int flags;
			    } termstr;
			    struct {
				    unsigned int lo;
				    unsigned int hi;
			    } termrange;
			    char *proseval;
			} e;
		} e;
	} u;
} object;

#define	F_CASESENSITIVE		1	/* termstr.str is case sensitive */

struct rule *findrule(char *);

void mywarn(int, const char *, ...);
#define	MYERROR		1
#define	MYWARNING	2
#define	MYFYI		3

void printobj(object *, int);
