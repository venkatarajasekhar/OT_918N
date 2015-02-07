
#include <stdlib.h>

static const char * const text[] = {
	"Kerberos successful",
	"Kerberos principal expired",
	"Kerberos service expired",
	"Kerberos auth expired",
	"Incorrect kerberos master key version",
	"Incorrect kerberos master key version",
	"Incorrect kerberos master key version",
	"Kerberos error: byte order unknown",
	"Kerberos principal unknown",
	"Kerberos principal not unique",
	"Kerberos principal has null key",
	"Reserved krb error (11)",
	"Reserved krb error (12)",
	"Reserved krb error (13)",
	"Reserved krb error (14)",
	"Reserved krb error (15)",
	"Reserved krb error (16)",
	"Reserved krb error (17)",
	"Reserved krb error (18)",
	"Reserved krb error (19)",
	"Generic error from Kerberos KDC",
	"Can't read Kerberos ticket file",
	"Can't find Kerberos ticket or TGT",
	"Reserved krb error (23)",
	"Reserved krb error (24)",
	"Reserved krb error (25)",
	"Kerberos TGT Expired",
	"Reserved krb error (27)",
	"Reserved krb error (28)",
	"Reserved krb error (29)",
	"Reserved krb error (30)",
	"Kerberos error: Can't decode authenticator",
	"Kerberos ticket expired",
	"Kerberos ticket not yet valid",
	"Kerberos error: Repeated request",
	"The kerberos ticket isn't for us",
	"Kerberos request inconsistent",
	"Kerberos error: delta_t too big",
	"Kerberos error: incorrect net address",
	"Kerberos protocol version mismatch",
	"Kerberos error: invalid msg type",
	"Kerberos error: message stream modified",
	"Kerberos error: message out of order",
	"Kerberos error: unauthorized request",
	"Reserved krb error (44)",
	"Reserved krb error (45)",
	"Reserved krb error (46)",
	"Reserved krb error (47)",
	"Reserved krb error (48)",
	"Reserved krb error (49)",
	"Reserved krb error (50)",
	"Kerberos error: current PW is null",
	"Kerberos error: Incorrect current password",
	"Kerberos protocol error",
	"Error returned by Kerberos KDC",
	"Null Kerberos ticket returned by KDC",
	"Kerberos error: Retry count exceeded",
	"Kerberos error: Can't send request",
	"Reserved krb error (58)",
	"Reserved krb error (59)",
	"Reserved krb error (60)",
	"Kerberos error: not all tickets returned",
	"Kerberos error: incorrect password",
	"Kerberos error: Protocol Error",
	"Reserved krb error (64)",
	"Reserved krb error (65)",
	"Reserved krb error (66)",
	"Reserved krb error (67)",
	"Reserved krb error (68)",
	"Reserved krb error (69)",
	"Other error",
	"Don't have Kerberos ticket-granting ticket",
	"Reserved krb error (72)",
	"Reserved krb error (73)",
	"Reserved krb error (74)",
	"Reserved krb error (75)",
	"No ticket file found",
	"Couldn't access ticket file",
	"Couldn't lock ticket file",
	"Bad ticket file format",
	"tf_init not called first",
	"Bad Kerberos name format",
    0
};

struct error_table {
    char const * const * msgs;
    long base;
    int n_msgs;
};
struct et_list {
    struct et_list *next;
    const struct error_table * table;
};
extern struct et_list *_et_list;

const struct error_table et_krb_error_table = { text, 39525376L, 82 };

static struct et_list link = { 0, 0 };

void initialize_krb_error_table_r(struct et_list **list);
void initialize_krb_error_table(void);

void initialize_krb_error_table(void) {
    initialize_krb_error_table_r(&_et_list);
}

/* For Heimdal compatibility */
void initialize_krb_error_table_r(struct et_list **list)
{
    struct et_list *et, **end;

    for (end = list, et = *list; et; end = &et->next, et = et->next)
        if (et->table->msgs == text)
            return;
    et = malloc(sizeof(struct et_list));
    if (et == 0) {
        if (!link.table)
            et = &link;
        else
            return;
    }
    et->table = &et_krb_error_table;
    et->next = 0;
    *end = et;
}
