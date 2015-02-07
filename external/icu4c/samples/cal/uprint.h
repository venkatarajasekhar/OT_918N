
#ifndef UPRINT_H
#define UPRINT_H 1

#include <stdio.h>

#include "unicode/utypes.h"

/* Print a ustring to the specified FILE* in the default codepage */
U_CFUNC void uprint(const UChar *s, FILE *f, UErrorCode *status);

#endif /* ! UPRINT_H */
