/*
 * Bill's ABNF Parser
 * $Id$
 */

struct range {
	unsigned int lo;
	unsigned int hi;
};

struct rule {
	char *name;		/* as defined or used */
	char *lowername;	/* for hash key */
	char *file;		/* filename of definition */
	int line;		/* line of definition */
	struct object *rule;	/* definition */
	int used;		/* was it referenced? */
	int predefined; /* abnf core rule? */
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
 * - List
 *   (list construct from RFC2616, Section 2.1)
 */
#define	T_ALTERNATION	1
#define	T_RULE		2
#define	T_GROUP		3
#define	T_TERMSTR	4
#define	T_TERMRANGE	5
#define	T_PROSE		6

typedef unsigned char t_tsfmts;

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
      int   islist; /* jre */
			union {
			    struct {
				    char *name;	/* for forward ref. */
				    struct rule *rule;
			    } rule;
			    struct object *group;
			    struct {
				    char *str;
				    t_tsfmts fmt;
				    t_tsfmts valid_fmts;
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

typedef struct input_file {
	char *filename;
	struct input_file *next;
} fn_list;

/* Flag definitions */

/* Flags for termstr formats. When used to indicate valid formats
 * these can be ORed together. When used to indicate a specific
 * format only one can be used at a time.
 * These values are ordered with the rightmost (and smallest) ones being
 * more "preferred" than the ones to the left. (This matters when
 * merging two strings of differing formats.)
 */
#define F_TSFMT_Q	(1<<0)
#define F_TSFMT_QI	(1<<1)
#define F_TSFMT_QS	(1<<2)
#define F_TSFMT_X	(1<<3)
#define F_TSFMT_D	(1<<4)
#define F_TSFMT_B	(1<<5)

/* masks for interesting combinations of flags */
#define M_TSFMT_QUOTED	(F_TSFMT_Q | F_TSFMT_QI | F_TSFMT_QS)
#define M_TSFMT_BINARY	(F_TSFMT_X | F_TSFMT_D | F_TSFMT_B)
#define M_TSFMT_ALL  	(M_TSFMT_QUOTED | M_TSFMT_BINARY)
#define M_TSFMT_SENSITIVE	(M_TSFMT_BINARY | F_TSFMT_QS)
#define M_TSFMT_INSENSITIVE	(F_TSFMT_Q | F_TSFMT_QI)
#define M_TSFMT_RFC7405	(F_TSFMT_QI | F_TSFMT_QS)

/* macro for selecting the most preferred fmt from a set */
#define F_TSFMT_PREFERRED(fmts) ((fmts) & (~(fmts) + 1))

/* end of flag definitions */

struct rule *findrule(char *);

void mywarn(int, const char *, ...);
#define	MYERROR		1
#define	MYWARNING	2
#define	MYFYI		3

void printobj(object *, int);
void scanreset(void);
