#ifndef LOCBASED_H
#define LOCBASED_H

#include "unicode/locid.h"
#include "unicode/uobject.h"

#define U_LOCALE_BASED(varname, objname) \
  LocaleBased varname((objname).validLocale, (objname).actualLocale);

U_NAMESPACE_BEGIN

class U_COMMON_API LocaleBased : public UMemory {

 public:

    /**
     * Construct a LocaleBased wrapper around the two pointers.  These
     * will be aliased for the lifetime of this object.
     */
    inline LocaleBased(char* validAlias, char* actualAlias);

    /**
     * Construct a LocaleBased wrapper around the two const pointers.
     * These will be aliased for the lifetime of this object.
     */
    inline LocaleBased(const char* validAlias, const char* actualAlias);

    /**
     * Return locale meta-data for the service object wrapped by this
     * object.  Either the valid or the actual locale may be
     * retrieved.
     * @param type either ULOC_VALID_LOCALE or ULOC_ACTUAL_LOCALE
     * @param status input-output error code
     * @return the indicated locale
     */
    Locale getLocale(ULocDataLocaleType type, UErrorCode& status) const;

    /**
     * Return the locale ID for the service object wrapped by this
     * object.  Either the valid or the actual locale may be
     * retrieved.
     * @param type either ULOC_VALID_LOCALE or ULOC_ACTUAL_LOCALE
     * @param status input-output error code
     * @return the indicated locale ID
     */
    const char* getLocaleID(ULocDataLocaleType type, UErrorCode& status) const;

    /**
     * Set the locale meta-data for the service object wrapped by this
     * object.  If either parameter is zero, it is ignored.
     * @param valid the ID of the valid locale
     * @param actual the ID of the actual locale
     */
    void setLocaleIDs(const char* valid, const char* actual);

 private:

    char* valid;
    
    char* actual;
};

inline LocaleBased::LocaleBased(char* validAlias, char* actualAlias) :
    valid(validAlias), actual(actualAlias) {
}

inline LocaleBased::LocaleBased(const char* validAlias,
                                const char* actualAlias) :
    // ugh: cast away const
    valid((char*)validAlias), actual((char*)actualAlias) {
}

U_NAMESPACE_END

#endif