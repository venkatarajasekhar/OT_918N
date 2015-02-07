
#ifndef __INTLTESTTIMEUNITTEST__
#define __INTLTESTTIMEUNITTEST__ 


#if !UCONFIG_NO_FORMATTING

#include "unicode/utypes.h"
#include "unicode/locid.h"
#include "intltest.h"

class TimeUnitTest: public IntlTest {
    void runIndexedTest( int32_t index, UBool exec, const char* &name, char* par = NULL );  

public:
    /**
     * Performs basic tests
     **/
    void testBasic();

    /**
     * Performs API tests
     **/
    void testAPI();
};

#endif /* #if !UCONFIG_NO_FORMATTING */

#endif
