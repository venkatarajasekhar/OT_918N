
#ifndef MSGFMT_H
#define MSGFMT_H

#include "unicode/utypes.h"

 
#if !UCONFIG_NO_FORMATTING

#include "unicode/format.h"
#include "unicode/locid.h"
#include "unicode/parseerr.h"
#include "unicode/uchar.h"

U_NAMESPACE_BEGIN

class NumberFormat;
class DateFormat;

class U_I18N_API MessageFormat : public Format {
public:
    /**
     * Enum type for kMaxFormat.
     * @obsolete ICU 3.0.  The 10-argument limit was removed as of ICU 2.6,
     * rendering this enum type obsolete.
     */
    enum EFormatNumber {
        /**
         * The maximum number of arguments.
         * @obsolete ICU 3.0.  The 10-argument limit was removed as of ICU 2.6,
         * rendering this constant obsolete.
         */
        kMaxFormat = 10
    };

    /**
     * Constructs a new MessageFormat using the given pattern and the
     * default locale.
     *
     * @param pattern   Pattern used to construct object.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @stable ICU 2.0
     */
    MessageFormat(const UnicodeString& pattern,
                  UErrorCode &status);

    /**
     * Constructs a new MessageFormat using the given pattern and locale.
     * @param pattern   Pattern used to construct object.
     * @param newLocale The locale to use for formatting dates and numbers.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @stable ICU 2.0
     */
    MessageFormat(const UnicodeString& pattern,
                  const Locale& newLocale,
                        UErrorCode& status);
    /**
     * Constructs a new MessageFormat using the given pattern and locale.
     * @param pattern   Pattern used to construct object.
     * @param newLocale The locale to use for formatting dates and numbers.
     * @param parseError Struct to recieve information on position 
     *                   of error within the pattern.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @stable ICU 2.0
     */
    MessageFormat(const UnicodeString& pattern,
                  const Locale& newLocale,
                  UParseError& parseError,
                  UErrorCode& status);
    /**
     * Constructs a new MessageFormat from an existing one.
     * @stable ICU 2.0
     */
    MessageFormat(const MessageFormat&);

    /**
     * Assignment operator.
     * @stable ICU 2.0
     */
    const MessageFormat& operator=(const MessageFormat&);

    /**
     * Destructor.
     * @stable ICU 2.0
     */
    virtual ~MessageFormat();

    /**
     * Clones this Format object polymorphically.  The caller owns the
     * result and should delete it when done.
     * @stable ICU 2.0
     */
    virtual Format* clone(void) const;

    /**
     * Returns true if the given Format objects are semantically equal.
     * Objects of different subclasses are considered unequal.
     * @param other  the object to be compared with.
     * @return       true if the given Format objects are semantically equal.
     * @stable ICU 2.0
     */
    virtual UBool operator==(const Format& other) const;

    /**
     * Sets the locale. This locale is used for fetching default number or date
     * format information.
     * @param theLocale    the new locale value to be set.
     * @stable ICU 2.0
     */
    virtual void setLocale(const Locale& theLocale);

    /**
     * Gets the locale. This locale is used for fetching default number or date
     * format information.
     * @return    the locale of the object.
     * @stable ICU 2.0
     */
    virtual const Locale& getLocale(void) const;

    /**
     * Applies the given pattern string to this message format.
     *
     * @param pattern   The pattern to be applied.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @stable ICU 2.0
     */
    virtual void applyPattern(const UnicodeString& pattern,
                              UErrorCode& status);
    /**
     * Applies the given pattern string to this message format.
     *
     * @param pattern    The pattern to be applied.
     * @param parseError Struct to recieve information on position 
     *                   of error within pattern.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @stable ICU 2.0
     */
    virtual void applyPattern(const UnicodeString& pattern,
                             UParseError& parseError,
                             UErrorCode& status);

    /**
     * Returns a pattern that can be used to recreate this object.
     *
     * @param appendTo  Output parameter to receive the pattern.
     *                  Result is appended to existing contents.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 2.0
     */
    virtual UnicodeString& toPattern(UnicodeString& appendTo) const;

    /**
     * Sets subformats.
     * See the class description about format numbering.
     * The caller should not delete the Format objects after this call.
     * <EM>The array formatsToAdopt is not itself adopted.</EM> Its
     * ownership is retained by the caller. If the call fails because
     * memory cannot be allocated, then the formats will be deleted
     * by this method, and this object will remain unchanged.
     * 
     * @stable ICU 2.0
     * @param formatsToAdopt    the format to be adopted.
     * @param count             the size of the array.
     */
    virtual void adoptFormats(Format** formatsToAdopt, int32_t count);

    /**
     * Sets subformats.
     * See the class description about format numbering.
     * Each item in the array is cloned into the internal array.
     * If the call fails because memory cannot be allocated, then this
     * object will remain unchanged.
     * 
     * @stable ICU 2.0
     * @param newFormats the new format to be set.
     * @param cnt        the size of the array.
     */
    virtual void setFormats(const Format** newFormats, int32_t cnt);


    /**
     * Sets one subformat.
     * See the class description about format numbering.
     * The caller should not delete the Format object after this call.
     * If the number is over the number of formats already set,
     * the item will be deleted and ignored.
     * @stable ICU 2.0
     * @param formatNumber     index of the subformat.
     * @param formatToAdopt    the format to be adopted.
     */
    virtual void adoptFormat(int32_t formatNumber, Format* formatToAdopt);

    /**
     * Sets one subformat.
     * See the class description about format numbering.
     * If the number is over the number of formats already set,
     * the item will be ignored.
     * @param formatNumber     index of the subformat.
     * @param format    the format to be set.
     * @stable ICU 2.0
     */
    virtual void setFormat(int32_t formatNumber, const Format& format);

    /**
     * Gets format names. This function returns formatNames in StringEnumerations
     * which can be used with getFormat() and setFormat() to export formattable 
     * array from current MessageFormat to another.  It is caller's resposibility 
     * to delete the returned formatNames.
     * @param status  output param set to success/failure code.
     * @stable ICU 4.0
     */
    virtual StringEnumeration* getFormatNames(UErrorCode& status);
    
    /**
     * Gets subformat pointer for given format name.   
     * This function supports both named and numbered
     * arguments-- if numbered, the formatName is the
     * corresponding UnicodeStrings (e.g. "0", "1", "2"...).
     * The returned Format object should not be deleted by the caller,
     * nor should the ponter of other object .  The pointer and its 
     * contents remain valid only until the next call to any method
     * of this class is made with this object. 
     * @param formatName the name or number specifying a format
     * @param status  output param set to success/failure code.
     * @stable ICU 4.0
     */
    virtual Format* getFormat(const UnicodeString& formatName, UErrorCode& status);
    
    /**
     * Sets one subformat for given format name.
     * See the class description about format name. 
     * This function supports both named and numbered
     * arguments-- if numbered, the formatName is the
     * corresponding UnicodeStrings (e.g. "0", "1", "2"...).
     * If there is no matched formatName or wrong type,
     * the item will be ignored.
     * @param formatName  Name of the subformat.
     * @param format      the format to be set.
     * @param status  output param set to success/failure code.
     * @stable ICU 4.0
     */
    virtual void setFormat(const UnicodeString& formatName, const Format& format, UErrorCode& status);
    
    /**
     * Sets one subformat for given format name.
     * See the class description about format name. 
     * This function supports both named and numbered
     * arguments-- if numbered, the formatName is the
     * corresponding UnicodeStrings (e.g. "0", "1", "2"...).
     * If there is no matched formatName or wrong type,
     * the item will be ignored.
     * The caller should not delete the Format object after this call.
     * @param formatName  Name of the subformat.
     * @param formatToAdopt  Format to be adopted.
     * @param status      output param set to success/failure code.
     * @stable ICU 4.0
     */
    virtual void adoptFormat(const UnicodeString& formatName, Format* formatToAdopt, UErrorCode& status);


    /**
     * Gets an array of subformats of this object.  The returned array
     * should not be deleted by the caller, nor should the pointers
     * within the array.  The array and its contents remain valid only
     * until the next call to any method of this class is made with
     * this object.  See the class description about format numbering.
     * @param count output parameter to receive the size of the array
     * @return an array of count Format* objects, or NULL if out of
     * memory.  Any or all of the array elements may be NULL.
     * @stable ICU 2.0
     */
    virtual const Format** getFormats(int32_t& count) const;

    /**
     * Formats the given array of arguments into a user-readable string.
     * Does not take ownership of the Formattable* array or its contents.
     *
     * @param source    An array of objects to be formatted.
     * @param count     The number of elements of 'source'.
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param ignore    Not used; inherited from base class API.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 2.0
     */
    UnicodeString& format(  const Formattable* source,
                            int32_t count,
                            UnicodeString& appendTo,
                            FieldPosition& ignore,
                            UErrorCode& status) const;

    /**
     * Formats the given array of arguments into a user-readable string
     * using the given pattern.
     *
     * @param pattern   The pattern.
     * @param arguments An array of objects to be formatted.
     * @param count     The number of elements of 'source'.
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 2.0
     */
    static UnicodeString& format(const UnicodeString& pattern,
                                 const Formattable* arguments,
                                 int32_t count,
                                 UnicodeString& appendTo,
                                 UErrorCode& status);

    /**
     * Formats the given array of arguments into a user-readable
     * string.  The array must be stored within a single Formattable
     * object of type kArray. If the Formattable object type is not of
     * type kArray, then returns a failing UErrorCode.
     *
     * @param obj       A Formattable of type kArray containing
     *                  arguments to be formatted.
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param pos       On input: an alignment field, if desired.
     *                  On output: the offsets of the alignment field.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 2.0
     */
    virtual UnicodeString& format(const Formattable& obj,
                                  UnicodeString& appendTo,
                                  FieldPosition& pos,
                                  UErrorCode& status) const;

    /**
     * Formats the given array of arguments into a user-readable
     * string.  The array must be stored within a single Formattable
     * object of type kArray. If the Formattable object type is not of
     * type kArray, then returns a failing UErrorCode.
     *
     * @param obj       The object to format
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 2.0
     */
    UnicodeString& format(const Formattable& obj,
                          UnicodeString& appendTo,
                          UErrorCode& status) const;
    

    /**
     * Formats the given array of arguments into a user-defined argument name
     * array. This function supports both named and numbered
     * arguments-- if numbered, the formatName is the
     * corresponding UnicodeStrings (e.g. "0", "1", "2"...).
     *
     * @param argumentNames argument name array
     * @param arguments An array of objects to be formatted.
     * @param count     The number of elements of 'argumentNames' and 
     *                  arguments.  The number of argumentNames and arguments
     *                  must be the same.
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code.
     * @return          Reference to 'appendTo' parameter.
     * @stable ICU 4.0
     */
    UnicodeString& format(const UnicodeString* argumentNames,
                          const Formattable* arguments,
                          int32_t count,
                          UnicodeString& appendTo,
                          UErrorCode& status) const;
    /**
     * Parses the given string into an array of output arguments.
     *
     * @param source    String to be parsed.
     * @param pos       On input, starting position for parse. On output,
     *                  final position after parse.  Unchanged if parse
     *                  fails.
     * @param count     Output parameter to receive the number of arguments
     *                  parsed.
     * @return an array of parsed arguments.  The caller owns both
     * the array and its contents.
     * @stable ICU 2.0
     */
    virtual Formattable* parse( const UnicodeString& source,
                                ParsePosition& pos,
                                int32_t& count) const;

    /**
     * Parses the given string into an array of output arguments.
     *
     * @param source    String to be parsed.
     * @param count     Output param to receive size of returned array.
     * @param status    Input/output error code.  If the
     *                  pattern cannot be parsed, set to failure code. 
     *                  If the MessageFormat is named argument, the status is 
     *                  set to U_ARGUMENT_TYPE_MISMATCH.
     * @return an array of parsed arguments.  The caller owns both
     * the array and its contents. Return NULL if status is not U_ZERO_ERROR.
     * 
     * @stable ICU 2.0
     */
    virtual Formattable* parse( const UnicodeString& source,
                                int32_t& count,
                                UErrorCode& status) const;

    /**
     * Parses the given string into an array of output arguments
     * stored within a single Formattable of type kArray.
     *
     * @param source    The string to be parsed into an object.
     * @param result    Formattable to be set to the parse result.
     *                  If parse fails, return contents are undefined.
     * @param pos       On input, starting position for parse. On output,
     *                  final position after parse.  Unchanged if parse
     *                  fails.
     * @stable ICU 2.0
     */
    virtual void parseObject(const UnicodeString& source,
                             Formattable& result,
                             ParsePosition& pos) const;

    /**
     * Convert an 'apostrophe-friendly' pattern into a standard
     * pattern.  Standard patterns treat all apostrophes as
     * quotes, which is problematic in some languages, e.g. 
     * French, where apostrophe is commonly used.  This utility
     * assumes that only an unpaired apostrophe immediately before
     * a brace is a true quote.  Other unpaired apostrophes are paired,
     * and the resulting standard pattern string is returned.
     *
     * <p><b>Note</b> it is not guaranteed that the returned pattern
     * is indeed a valid pattern.  The only effect is to convert
     * between patterns having different quoting semantics.
     *
     * @param pattern the 'apostrophe-friendly' patttern to convert
     * @param status    Input/output error code.  If the pattern
     *                  cannot be parsed, the failure code is set.
     * @return the standard equivalent of the original pattern
     * @stable ICU 3.4
     */
    static UnicodeString autoQuoteApostrophe(const UnicodeString& pattern, 
        UErrorCode& status);
    
    /**
     * Returns true if this MessageFormat uses named arguments,
     * and false otherwise.  See class description.
     *
     * @return true if named arguments are used.
     * @stable ICU 4.0
     */
    UBool usesNamedArguments() const;
    

    /**
     * This API is for ICU internal use only.
     * Please do not use it.
     *
     * Returns argument types count in the parsed pattern.
     * Used to distinguish pattern "{0} d" and "d".
     *
     * @return           The number of formattable types in the pattern
     * @internal
     */
    int32_t getArgTypeCount() const;

    /**
     * Returns a unique class ID POLYMORPHICALLY.  Pure virtual override.
     * This method is to implement a simple version of RTTI, since not all
     * C++ compilers support genuine RTTI.  Polymorphic operator==() and
     * clone() methods call this method.
     *
     * @return          The class ID for this object. All objects of a
     *                  given class have the same class ID.  Objects of
     *                  other classes have different class IDs.
     * @stable ICU 2.0
     */
    virtual UClassID getDynamicClassID(void) const;

    /**
     * Return the class ID for this class.  This is useful only for
     * comparing to a return value from getDynamicClassID().  For example:
     * <pre>
     * .   Base* polymorphic_pointer = createPolymorphicObject();
     * .   if (polymorphic_pointer->getDynamicClassID() ==
     * .      Derived::getStaticClassID()) ...
     * </pre>
     * @return          The class ID for all objects of this class.
     * @stable ICU 2.0
     */
    static UClassID U_EXPORT2 getStaticClassID(void);
    
private:

    Locale              fLocale;
    UnicodeString       fPattern;
    Format**            formatAliases; // see getFormats
    int32_t             formatAliasesCapacity;
    UProperty           idStart;
    UProperty           idContinue;

    MessageFormat(); // default constructor not implemented

    /*
     * A structure representing one subformat of this MessageFormat.
     * Each subformat has a Format object, an offset into the plain
     * pattern text fPattern, and an argument number.  The argument
     * number corresponds to the array of arguments to be formatted.
     * @internal
     */
    class Subformat;

    /**
     * A MessageFormat contains an array of subformats.  This array
     * needs to grow dynamically if the MessageFormat is modified.
     */
    Subformat* subformats;
    int32_t    subformatCount;
    int32_t    subformatCapacity;

    /**
     * A MessageFormat formats an array of arguments.  Each argument
     * has an expected type, based on the pattern.  For example, if
     * the pattern contains the subformat "{3,number,integer}", then
     * we expect argument 3 to have type Formattable::kLong.  This
     * array needs to grow dynamically if the MessageFormat is
     * modified.
     */
    Formattable::Type* argTypes;
    int32_t            argTypeCount;
    int32_t            argTypeCapacity;

    /**
      * Is true iff all argument names are non-negative numbers.
      * 
      */
    UBool isArgNumeric;

    // Variable-size array management
    UBool allocateSubformats(int32_t capacity);
    UBool allocateArgTypes(int32_t capacity);

    /**
     * Default Format objects used when no format is specified and a
     * numeric or date argument is formatted.  These are volatile
     * cache objects maintained only for performance.  They do not
     * participate in operator=(), copy constructor(), nor
     * operator==().
     */
    NumberFormat* defaultNumberFormat;
    DateFormat*   defaultDateFormat;

    /**
     * Method to retrieve default formats (or NULL on failure).
     * These are semantically const, but may modify *this.
     */
    const NumberFormat* getDefaultNumberFormat(UErrorCode&) const;
    const DateFormat*   getDefaultDateFormat(UErrorCode&) const;

    /**
     * Finds the word s, in the keyword list and returns the located index.
     * @param s the keyword to be searched for.
     * @param list the list of keywords to be searched with.
     * @return the index of the list which matches the keyword s.
     */
    static int32_t findKeyword( const UnicodeString& s,
                                const UChar * const *list);

    /**
     * Formats the array of arguments and copies the result into the
     * result buffer, updates the field position.
     *
     * @param arguments The formattable objects array.
     * @param cnt       The array count.
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     * @param status    Field position status.
     * @param recursionProtection
     *                  Initially zero. Bits 0..9 are used to indicate
     *                  that a parameter has already been seen, to
     *                  avoid recursion.  Currently unused.
     * @param success   The error code status.
     * @return          Reference to 'appendTo' parameter.
     */
    UnicodeString&  format( const Formattable* arguments,
                            int32_t cnt,
                            UnicodeString& appendTo,
                            FieldPosition& status,
                            int32_t recursionProtection,
                            UErrorCode& success) const;
    
    UnicodeString&  format( const Formattable* arguments, 
                            const UnicodeString *argumentNames,
                            int32_t cnt,
                            UnicodeString& appendTo,
                            FieldPosition& status,
                            int32_t recursionProtection,
                            UErrorCode& success) const;

    void             makeFormat(int32_t offsetNumber,
                                UnicodeString* segments,
                                UParseError& parseError,
                                UErrorCode& success);

    /**
     * Convenience method that ought to be in NumberFormat
     */
    NumberFormat* createIntegerFormat(const Locale& locale, UErrorCode& status) const;

    /**
     * Checks the range of the source text to quote the special
     * characters, { and ' and copy to target buffer.
     * @param source
     * @param start the text offset to start the process of in the source string
     * @param end the text offset to end the process of in the source string
     * @param appendTo  Output parameter to receive result.
     *                  Result is appended to existing contents.
     */
    static void copyAndFixQuotes(const UnicodeString& appendTo, int32_t start, int32_t end, UnicodeString& target);

    /**
     * Returns array of argument types in the parsed pattern 
     * for use in C API.  Only for the use of umsg_vformat().  Not
     * for public consumption.
     * @param listCount  Output parameter to receive the size of array
     * @return           The array of formattable types in the pattern
     * @internal
     */
    const Formattable::Type* getArgTypeList(int32_t& listCount) const {
        listCount = argTypeCount;
        return argTypes; 
    }
    
    /**
     * Returns FALSE if the argument name is not legal.
     * @param  argName   argument name.
     * @return TRUE if the argument name is legal, otherwise return FALSE.
     */
    UBool isLegalArgName(const UnicodeString& argName) const;
    
    friend class MessageFormatAdapter; // getFormatTypeList() access
};

inline UnicodeString&
MessageFormat::format(const Formattable& obj,
                      UnicodeString& appendTo,
                      UErrorCode& status) const {
    return Format::format(obj, appendTo, status);
}
U_NAMESPACE_END

#endif /* #if !UCONFIG_NO_FORMATTING */

#endif // _MSGFMT
//eof

