package CodeGeneratorJS;

use File::stat;

my $module = "";
my $outputDir = "";
my $writeDependencies = 0;

my @headerContentHeader = ();
my @headerContent = ();
my %headerIncludes = ();

my @implContentHeader = ();
my @implContent = ();
my %implIncludes = ();
my @depsContent = ();
my $numCachedAttributes = 0;
my $currentCachedAttribute = 0;

# Default .h template
my $headerTemplate = << "EOF";
EOF

# Default constructor
sub new
{
    my $object = shift;
    my $reference = { };

    $codeGenerator = shift;
    $outputDir = shift;
    shift; # $useLayerOnTop
    shift; # $preprocessor
    $writeDependencies = shift;

    bless($reference, $object);
    return $reference;
}

sub finish
{
    my $object = shift;

    # Commit changes!
    $object->WriteData();
}

sub leftShift($$) {
    my ($value, $distance) = @_;
    return (($value << $distance) & 0xFFFFFFFF);
}

# Params: 'domClass' struct
sub GenerateInterface
{
    my $object = shift;
    my $dataNode = shift;
    my $defines = shift;

    # Start actual generation
    $object->GenerateHeader($dataNode);
    $object->GenerateImplementation($dataNode);

    my $name = $dataNode->name;

    # Open files for writing
    my $headerFileName = "$outputDir/JS$name.h";
    my $implFileName = "$outputDir/JS$name.cpp";
    my $depsFileName = "$outputDir/JS$name.dep";

    # Remove old dependency file.
    unlink($depsFileName);

    open($IMPL, ">$implFileName") || die "Couldn't open file $implFileName";
    open($HEADER, ">$headerFileName") || die "Couldn't open file $headerFileName";
    if (@depsContent) {
        open($DEPS, ">$depsFileName") || die "Couldn't open file $depsFileName";
    }
}

# Params: 'idlDocument' struct
sub GenerateModule
{
    my $object = shift;
    my $dataNode = shift;

    $module = $dataNode->module;
}

sub GetParentClassName
{
    my $dataNode = shift;

    return $dataNode->extendedAttributes->{"LegacyParent"} if $dataNode->extendedAttributes->{"LegacyParent"};
    return "DOMObjectWithGlobalPointer" if (@{$dataNode->parents} eq 0);
    return "JS" . $codeGenerator->StripModule($dataNode->parents(0));
}

sub GetVisibleClassName
{
    my $className = shift;

    return "DOMException" if $className eq "DOMCoreException";
    return $className;
}

sub AvoidInclusionOfType
{
    my $type = shift;

    # Special case: SVGRect.h / SVGPoint.h / SVGNumber.h / SVGMatrix.h do not exist.
    return 1 if $type eq "SVGRect" or $type eq "SVGPoint" or $type eq "SVGNumber" or $type eq "SVGMatrix";
    return 0;
}

sub IndexGetterReturnsStrings
{
    my $type = shift;

    return 1 if $type eq "CSSStyleDeclaration" or $type eq "MediaList" or $type eq "CSSVariablesDeclaration";
    return 0;
}

sub AddIncludesForType
{
    my $type = $codeGenerator->StripModule(shift);

    # When we're finished with the one-file-per-class
    # reorganization, we won't need these special cases.
    if ($codeGenerator->IsPrimitiveType($type) or AvoidInclusionOfType($type)
        or $type eq "DOMString" or $type eq "DOMObject" or $type eq "Array") {
    } elsif ($type =~ /SVGPathSeg/) {
        $joinedName = $type;
        $joinedName =~ s/Abs|Rel//;
        $implIncludes{"${joinedName}.h"} = 1;
    } elsif ($type eq "XPathNSResolver") {
        $implIncludes{"JSXPathNSResolver.h"} = 1;
        $implIncludes{"JSCustomXPathNSResolver.h"} = 1;
    } else {
        # default, include the same named file
        $implIncludes{"${type}.h"} = 1;
    }

    # additional includes (things needed to compile the bindings but not the header)

    if ($type eq "CanvasRenderingContext2D") {
        $implIncludes{"CanvasGradient.h"} = 1;
        $implIncludes{"CanvasPattern.h"} = 1;
        $implIncludes{"CanvasStyle.h"} = 1;
    }

    if ($type eq "CanvasGradient" or $type eq "XPathNSResolver" or $type eq "MessagePort") {
        $implIncludes{"PlatformString.h"} = 1;
    }

    if ($type eq "Document") {
        $implIncludes{"NodeFilter.h"} = 1;
    }
}

sub AddIncludesForSVGAnimatedType
{
    my $type = shift;
    $type =~ s/SVGAnimated//;

    if ($type eq "Point" or $type eq "Rect") {
        $implIncludes{"Float$type.h"} = 1;
    } elsif ($type eq "String") {
        $implIncludes{"PlatformString.h"} = 1;
    }
}

sub AddClassForwardIfNeeded
{
    my $implClassName = shift;

    # SVGAnimatedLength/Number/etc. are typedefs to SVGAnimatedTemplate, so don't use class forwards for them!
    push(@headerContent, "class $implClassName;\n\n") unless $codeGenerator->IsSVGAnimatedType($implClassName);
}

sub IsSVGTypeNeedingContextParameter
{
    my $implClassName = shift;

    return 0 unless $implClassName =~ /SVG/;
    return 0 if $implClassName =~ /Element/;
    my @noContextNeeded = ("SVGPaint", "SVGColor", "SVGDocument", "SVGZoomEvent");
    foreach (@noContextNeeded) {
        return 0 if $implClassName eq $_;
    }
    return 1;
}

sub HashValueForClassAndName
{
    my $class = shift;
    my $name = shift;

    # SVG Filter enums live in WebCore namespace (platform/graphics/)
    if ($class =~ /^SVGFE*/ or $class =~ /^SVGComponentTransferFunctionElement$/) {
        return "WebCore::$name";
    }

    return "${class}::$name";
}

sub hashTableAccessor
{
    my $noStaticTables = shift;
    my $className = shift;
    if ($noStaticTables) {
        return "get${className}Table(exec)";
    } else {
        return "&${className}Table";
    }
}

sub prototypeHashTableAccessor
{
    my $noStaticTables = shift;
    my $className = shift;
    if ($noStaticTables) {
        return "get${className}PrototypeTable(exec)";
    } else {
        return "&${className}PrototypeTable";
    }
}

sub GenerateGetOwnPropertySlotBody
{
    my ($dataNode, $interfaceName, $className, $implClassName, $hasAttributes, $inlined) = @_;

    my $namespaceMaybe = ($inlined ? "JSC::" : "");

    my @getOwnPropertySlotImpl = ();

    if ($interfaceName eq "NamedNodeMap" or $interfaceName eq "HTMLCollection" or $interfaceName eq "HTMLAllCollection") {
        push(@getOwnPropertySlotImpl, "    ${namespaceMaybe}JSValue proto = prototype();\n");
        push(@getOwnPropertySlotImpl, "    if (proto.isObject() && static_cast<${namespaceMaybe}JSObject*>(asObject(proto))->hasProperty(exec, propertyName))\n");
        push(@getOwnPropertySlotImpl, "        return false;\n\n");
    }

    my $manualLookupGetterGeneration = sub {
        my $requiresManualLookup = $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasNameGetter"};
        if ($requiresManualLookup) {
            push(@getOwnPropertySlotImpl, "    const ${namespaceMaybe}HashEntry* entry = ${className}Table.entry(exec, propertyName);\n");
            push(@getOwnPropertySlotImpl, "    if (entry) {\n");
            push(@getOwnPropertySlotImpl, "        slot.setCustom(this, entry->propertyGetter());\n");
            push(@getOwnPropertySlotImpl, "        return true;\n");
            push(@getOwnPropertySlotImpl, "    }\n");
        }
    };

    if (!$dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        &$manualLookupGetterGeneration();
    }

    if ($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
        push(@getOwnPropertySlotImpl, "    bool ok;\n");
        push(@getOwnPropertySlotImpl, "    unsigned index = propertyName.toUInt32(&ok, false);\n");

        # If the item function returns a string then we let the ConvertNullStringTo handle the cases
        # where the index is out of range.
        if (IndexGetterReturnsStrings($implClassName)) {
            push(@getOwnPropertySlotImpl, "    if (ok) {\n");
        } else {
            push(@getOwnPropertySlotImpl, "    if (ok && index < static_cast<$implClassName*>(impl())->length()) {\n");
        }
        if ($dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
            push(@getOwnPropertySlotImpl, "        slot.setValue(getByIndex(exec, index));\n");
        } else {
            push(@getOwnPropertySlotImpl, "        slot.setCustomIndex(this, index, indexGetter);\n");
        }
        push(@getOwnPropertySlotImpl, "        return true;\n");
        push(@getOwnPropertySlotImpl, "    }\n");
    }

    if ($dataNode->extendedAttributes->{"HasNameGetter"} || $dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        push(@getOwnPropertySlotImpl, "    if (canGetItemsForName(exec, static_cast<$implClassName*>(impl()), propertyName)) {\n");
        push(@getOwnPropertySlotImpl, "        slot.setCustom(this, nameGetter);\n");
        push(@getOwnPropertySlotImpl, "        return true;\n");
        push(@getOwnPropertySlotImpl, "    }\n");
        if ($inlined) {
            $headerIncludes{"AtomicString.h"} = 1;
        } else {
            $implIncludes{"AtomicString.h"} = 1;
        }
    }

    if ($dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        &$manualLookupGetterGeneration();
    }

    if ($dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"}) {
        push(@getOwnPropertySlotImpl, "    if (getOwnPropertySlotDelegate(exec, propertyName, slot))\n");
        push(@getOwnPropertySlotImpl, "        return true;\n");
    }

    if ($hasAttributes) {
        if ($inlined) {
            die "Cannot inline if NoStaticTables is set." if ($dataNode->extendedAttributes->{"NoStaticTables"});
            push(@getOwnPropertySlotImpl, "    return ${namespaceMaybe}getStaticValueSlot<$className, Base>(exec, s_info.staticPropHashTable, this, propertyName, slot);\n");
        } else {
            push(@getOwnPropertySlotImpl, "    return ${namespaceMaybe}getStaticValueSlot<$className, Base>(exec, " . hashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, slot);\n");
        }
    } else {
        push(@getOwnPropertySlotImpl, "    return Base::getOwnPropertySlot(exec, propertyName, slot);\n");
    }

    return @getOwnPropertySlotImpl;
}

sub GenerateGetOwnPropertyDescriptorBody
{
    my ($dataNode, $interfaceName, $className, $implClassName, $hasAttributes, $inlined) = @_;
    
    my $namespaceMaybe = ($inlined ? "JSC::" : "");
    
    my @getOwnPropertyDescriptorImpl = ();
    if ($dataNode->extendedAttributes->{"CheckDomainSecurity"}) {
        if ($interfaceName eq "DOMWindow") {
            push(@implContent, "    if (!static_cast<$className*>(thisObject)->allowsAccessFrom(exec))\n");
        } else {
            push(@implContent, "    if (!allowsAccessFromFrame(exec, static_cast<$className*>(thisObject)->impl()->frame()))\n");
        }
        push(@implContent, "        return false;\n");
    }
    
    if ($interfaceName eq "NamedNodeMap" or $interfaceName eq "HTMLCollection" or $interfaceName eq "HTMLAllCollection") {
        push(@getOwnPropertyDescriptorImpl, "    ${namespaceMaybe}JSValue proto = prototype();\n");
        push(@getOwnPropertyDescriptorImpl, "    if (proto.isObject() && static_cast<${namespaceMaybe}JSObject*>(asObject(proto))->hasProperty(exec, propertyName))\n");
        push(@getOwnPropertyDescriptorImpl, "        return false;\n\n");
    }
    
    my $manualLookupGetterGeneration = sub {
        my $requiresManualLookup = $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasNameGetter"};
        if ($requiresManualLookup) {
            push(@getOwnPropertyDescriptorImpl, "    const ${namespaceMaybe}HashEntry* entry = ${className}Table.entry(exec, propertyName);\n");
            push(@getOwnPropertyDescriptorImpl, "    if (entry) {\n");
            push(@getOwnPropertyDescriptorImpl, "        PropertySlot slot;\n");
            push(@getOwnPropertyDescriptorImpl, "        slot.setCustom(this, entry->propertyGetter());\n");
            push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(slot.getValue(exec, propertyName), entry->attributes());\n");
            push(@getOwnPropertyDescriptorImpl, "        return true;\n");
            push(@getOwnPropertyDescriptorImpl, "    }\n");
        }
    };
    
    if (!$dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        &$manualLookupGetterGeneration();
    }
    
    if ($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
        push(@getOwnPropertyDescriptorImpl, "    bool ok;\n");
        push(@getOwnPropertyDescriptorImpl, "    unsigned index = propertyName.toUInt32(&ok, false);\n");
        push(@getOwnPropertyDescriptorImpl, "    if (ok && index < static_cast<$implClassName*>(impl())->length()) {\n");
        if ($dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
            # Assume that if there's a setter, the index will be writable
            if ($dataNode->extendedAttributes->{"HasIndexSetter"} || $dataNode->extendedAttributes->{"HasCustomIndexSetter"}) {
                push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(getByIndex(exec, index), ${namespaceMaybe}DontDelete);\n");
            } else {
                push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(getByIndex(exec, index), ${namespaceMaybe}DontDelete | ${namespaceMaybe}ReadOnly);\n");
            }
        } else {
            push(@getOwnPropertyDescriptorImpl, "        ${namespaceMaybe}PropertySlot slot;\n");
            push(@getOwnPropertyDescriptorImpl, "        slot.setCustomIndex(this, index, indexGetter);\n");
            # Assume that if there's a setter, the index will be writable
            if ($dataNode->extendedAttributes->{"HasIndexSetter"} || $dataNode->extendedAttributes->{"HasCustomIndexSetter"}) {
                push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(slot.getValue(exec, propertyName), ${namespaceMaybe}DontDelete);\n");
            } else {
                push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(slot.getValue(exec, propertyName), ${namespaceMaybe}DontDelete | ${namespaceMaybe}ReadOnly);\n");
            }
        }
        push(@getOwnPropertyDescriptorImpl, "        return true;\n");
        push(@getOwnPropertyDescriptorImpl, "    }\n");
    }
    
    if ($dataNode->extendedAttributes->{"HasNameGetter"} || $dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        push(@getOwnPropertyDescriptorImpl, "    if (canGetItemsForName(exec, static_cast<$implClassName*>(impl()), propertyName)) {\n");
        push(@getOwnPropertyDescriptorImpl, "        ${namespaceMaybe}PropertySlot slot;\n");
        push(@getOwnPropertyDescriptorImpl, "        slot.setCustom(this, nameGetter);\n");
        push(@getOwnPropertyDescriptorImpl, "        descriptor.setDescriptor(slot.getValue(exec, propertyName), ReadOnly | DontDelete | DontEnum);\n");
        push(@getOwnPropertyDescriptorImpl, "        return true;\n");
        push(@getOwnPropertyDescriptorImpl, "    }\n");
        if ($inlined) {
            $headerIncludes{"AtomicString.h"} = 1;
        } else {
            $implIncludes{"AtomicString.h"} = 1;
        }
    }
    
    if ($dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        &$manualLookupGetterGeneration();
    }
    
    if ($dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"}) {
        push(@getOwnPropertyDescriptorImpl, "    if (getOwnPropertyDescriptorDelegate(exec, propertyName, descriptor))\n");
        push(@getOwnPropertyDescriptorImpl, "        return true;\n");
    }
    
    if ($hasAttributes) {
        if ($inlined) {
            die "Cannot inline if NoStaticTables is set." if ($dataNode->extendedAttributes->{"NoStaticTables"});
            push(@getOwnPropertyDescriptorImpl, "    return ${namespaceMaybe}getStaticValueDescriptor<$className, Base>(exec, s_info.staticPropHashTable, this, propertyName, descriptor);\n");
        } else {
            push(@getOwnPropertyDescriptorImpl, "    return ${namespaceMaybe}getStaticValueDescriptor<$className, Base>(exec, " . hashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, descriptor);\n");
        }
    } else {
        push(@getOwnPropertyDescriptorImpl, "    return Base::getOwnPropertyDescriptor(exec, propertyName, descriptor);\n");
    }
    
    return @getOwnPropertyDescriptorImpl;
}

my %usesToJSNewlyCreated = (
    "CDATASection" => 1,
    "Element" => 1,
    "Node" => 1,
    "Text" => 1,
    "Touch" => 1,
    "TouchList" => 1
);

sub GenerateHeader
{
    my $object = shift;
    my $dataNode = shift;

    my $interfaceName = $dataNode->name;
    my $className = "JS$interfaceName";
    my $implClassName = $interfaceName;
    my @ancestorInterfaceNames = ();
    my %structureFlags = ();

    # We only support multiple parents with SVG (for now).
    if (@{$dataNode->parents} > 1) {
        die "A class can't have more than one parent" unless $interfaceName =~ /SVG/;
        $codeGenerator->AddMethodsConstantsAndAttributesFromParentClasses($dataNode, \@ancestorInterfaceNames);
    }

    my $hasLegacyParent = $dataNode->extendedAttributes->{"LegacyParent"};
    my $hasRealParent = @{$dataNode->parents} > 0;
    my $hasParent = $hasLegacyParent || $hasRealParent;
    my $parentClassName = GetParentClassName($dataNode);
    my $conditional = $dataNode->extendedAttributes->{"Conditional"};
    my $eventTarget = $dataNode->extendedAttributes->{"EventTarget"};
    my $needsMarkChildren = $dataNode->extendedAttributes->{"CustomMarkFunction"} || $dataNode->extendedAttributes->{"EventTarget"};
    
    # - Add default header template
    @headerContentHeader = split("\r", $headerTemplate);

    # - Add header protection
    push(@headerContentHeader, "\n#ifndef $className" . "_h");
    push(@headerContentHeader, "\n#define $className" . "_h\n\n");

    my $conditionalString;
    if ($conditional) {
        $conditionalString = "ENABLE(" . join(") && ENABLE(", split(/&/, $conditional)) . ")";
        push(@headerContentHeader, "#if ${conditionalString}\n\n");
    }

    if ($hasParent) {
        $headerIncludes{"$parentClassName.h"} = 1;
    } else {
        $headerIncludes{"JSDOMBinding.h"} = 1;
        $headerIncludes{"<runtime/JSGlobalObject.h>"} = 1;
        $headerIncludes{"<runtime/ObjectPrototype.h>"} = 1;
    }

    if ($dataNode->extendedAttributes->{"CustomCall"}) {
        $headerIncludes{"<runtime/CallData.h>"} = 1;
    }

    if ($dataNode->extendedAttributes->{"InlineGetOwnPropertySlot"}) {
        $headerIncludes{"<runtime/Lookup.h>"} = 1;
        $headerIncludes{"<wtf/AlwaysInline.h>"} = 1;
    }

    if ($hasParent && $dataNode->extendedAttributes->{"GenerateNativeConverter"}) {
        $headerIncludes{"$implClassName.h"} = 1;
    }

    $headerIncludes{"SVGElement.h"} = 1 if $className =~ /^JSSVG/;

    # Get correct pass/store types respecting PODType flag
    my $podType = $dataNode->extendedAttributes->{"PODType"};
    my $implType = $podType ? "JSSVGPODTypeWrapper<$podType> " : $implClassName;
    $headerIncludes{"$podType.h"} = 1 if $podType and $podType ne "float";

    $headerIncludes{"JSSVGPODTypeWrapper.h"} = 1 if $podType;

    my $numConstants = @{$dataNode->constants};
    my $numAttributes = @{$dataNode->attributes};
    my $numFunctions = @{$dataNode->functions};

    push(@headerContent, "\nnamespace WebCore {\n\n");

    # Implementation class forward declaration
    AddClassForwardIfNeeded($implClassName) unless $podType;
    AddClassForwardIfNeeded("JSDOMWindowShell") if $interfaceName eq "DOMWindow";

    # Class declaration
    push(@headerContent, "class $className : public $parentClassName {\n");
    push(@headerContent, "    typedef $parentClassName Base;\n");
    push(@headerContent, "public:\n");

    # Constructor
    if ($interfaceName eq "DOMWindow") {
        push(@headerContent, "    $className(NonNullPassRefPtr<JSC::Structure>, PassRefPtr<$implType>, JSDOMWindowShell*);\n");
    } elsif ($dataNode->extendedAttributes->{"IsWorkerContext"}) {
        push(@headerContent, "    $className(NonNullPassRefPtr<JSC::Structure>, PassRefPtr<$implType>);\n");
    } else {
        push(@headerContent, "    $className(NonNullPassRefPtr<JSC::Structure>, JSDOMGlobalObject*, PassRefPtr<$implType>);\n");
    }

    # Destructor
    push(@headerContent, "    virtual ~$className();\n") if (!$hasParent or $eventTarget or $interfaceName eq "DOMWindow");

    # Prototype
    push(@headerContent, "    static JSC::JSObject* createPrototype(JSC::ExecState*, JSC::JSGlobalObject*);\n") unless ($dataNode->extendedAttributes->{"ExtendsDOMGlobalObject"});

    $implIncludes{"${className}Custom.h"} = 1 if $dataNode->extendedAttributes->{"CustomHeader"} || $dataNode->extendedAttributes->{"CustomPutFunction"} || $dataNode->extendedAttributes->{"DelegatingPutFunction"};

    my $hasGetter = $numAttributes > 0 
                 || !($dataNode->extendedAttributes->{"OmitConstructor"}
                 || $dataNode->extendedAttributes->{"CustomConstructor"})
                 || $dataNode->extendedAttributes->{"HasIndexGetter"}
                 || $dataNode->extendedAttributes->{"HasCustomIndexGetter"}
                 || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}
                 || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"}
                 || $dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"}
                 || $dataNode->extendedAttributes->{"HasNameGetter"}
                 || $dataNode->extendedAttributes->{"HasOverridingNameGetter"};

    # Getters
    if ($hasGetter) {
        push(@headerContent, "    virtual bool getOwnPropertySlot(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertySlot&);\n");
        push(@headerContent, "    virtual bool getOwnPropertyDescriptor(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertyDescriptor&);\n");
        push(@headerContent, "    virtual bool getOwnPropertySlot(JSC::ExecState*, unsigned propertyName, JSC::PropertySlot&);\n") if ($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) && !$dataNode->extendedAttributes->{"HasOverridingNameGetter"};
        push(@headerContent, "    bool getOwnPropertySlotDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::PropertySlot&);\n") if $dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"};
        push(@headerContent, "    bool getOwnPropertyDescriptorDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::PropertyDescriptor&);\n") if $dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"};
        $structureFlags{"JSC::OverridesGetOwnPropertySlot"} = 1;
    }

    # Check if we have any writable properties
    my $hasReadWriteProperties = 0;
    foreach (@{$dataNode->attributes}) {
        if ($_->type !~ /^readonly\ attribute$/) {
            $hasReadWriteProperties = 1;
        }
    }

    my $hasSetter = $hasReadWriteProperties
                 || $dataNode->extendedAttributes->{"CustomPutFunction"}
                 || $dataNode->extendedAttributes->{"DelegatingPutFunction"}
                 || $dataNode->extendedAttributes->{"HasCustomIndexSetter"};

    # Getters
    if ($hasSetter) {
        push(@headerContent, "    virtual void put(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSValue, JSC::PutPropertySlot&);\n");
        push(@headerContent, "    virtual void put(JSC::ExecState*, unsigned propertyName, JSC::JSValue);\n") if $dataNode->extendedAttributes->{"HasCustomIndexSetter"};
        push(@headerContent, "    bool putDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::JSValue, JSC::PutPropertySlot&);\n") if $dataNode->extendedAttributes->{"DelegatingPutFunction"};
    }

    # Class info
    push(@headerContent, "    virtual const JSC::ClassInfo* classInfo() const { return &s_info; }\n");
    push(@headerContent, "    static const JSC::ClassInfo s_info;\n\n");

    # Structure ID
    if ($interfaceName eq "DOMWindow") {
        $structureFlags{"JSC::ImplementsHasInstance"} = 1;
        $structureFlags{"JSC::NeedsThisConversion"} = 1;
    }
    push(@headerContent,
        "    static PassRefPtr<JSC::Structure> createStructure(JSC::JSValue prototype)\n" .
        "    {\n" .
        "        return JSC::Structure::create(prototype, JSC::TypeInfo(JSC::ObjectType, StructureFlags), AnonymousSlotCount);\n" .
        "    }\n\n");

    # markChildren function
    if ($needsMarkChildren) {
        push(@headerContent, "    virtual void markChildren(JSC::MarkStack&);\n\n");
        $structureFlags{"JSC::OverridesMarkChildren"} = 1;
    }

    # Custom pushEventHandlerScope function
    push(@headerContent, "    virtual void pushEventHandlerScope(JSC::ExecState*, JSC::ScopeChain&) const;\n\n") if $dataNode->extendedAttributes->{"CustomPushEventHandlerScope"};

    # Custom call functions
    push(@headerContent, "    virtual JSC::CallType getCallData(JSC::CallData&);\n\n") if $dataNode->extendedAttributes->{"CustomCall"};

    # Custom deleteProperty function
    push(@headerContent, "    virtual bool deleteProperty(JSC::ExecState*, const JSC::Identifier&);\n") if $dataNode->extendedAttributes->{"CustomDeleteProperty"};

    # Custom getPropertyNames function exists on DOMWindow
    if ($interfaceName eq "DOMWindow") {
        push(@headerContent, "    virtual void getPropertyNames(JSC::ExecState*, JSC::PropertyNameArray&, JSC::EnumerationMode mode = JSC::ExcludeDontEnumProperties);\n");
        $structureFlags{"JSC::OverridesGetPropertyNames"} = 1;
    }

    # Custom defineProperty function exists on DOMWindow
    push(@headerContent, "    virtual bool defineOwnProperty(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertyDescriptor&, bool shouldThrow);\n") if $interfaceName eq "DOMWindow";

    # Custom getOwnPropertyNames function
    if ($dataNode->extendedAttributes->{"CustomGetPropertyNames"} || $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
        push(@headerContent, "    virtual void getOwnPropertyNames(JSC::ExecState*, JSC::PropertyNameArray&, JSC::EnumerationMode mode = JSC::ExcludeDontEnumProperties);\n");
        $structureFlags{"JSC::OverridesGetPropertyNames"} = 1;       
    }

    # Custom defineGetter function
    push(@headerContent, "    virtual void defineGetter(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSObject* getterFunction, unsigned attributes);\n") if $dataNode->extendedAttributes->{"CustomDefineGetter"};

    # Custom defineSetter function
    push(@headerContent, "    virtual void defineSetter(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSObject* setterFunction, unsigned attributes);\n") if $dataNode->extendedAttributes->{"CustomDefineSetter"};

    # Custom lookupGetter function
    push(@headerContent, "    virtual JSC::JSValue lookupGetter(JSC::ExecState*, const JSC::Identifier& propertyName);\n") if $dataNode->extendedAttributes->{"CustomLookupGetter"};

    # Custom lookupSetter function
    push(@headerContent, "    virtual JSC::JSValue lookupSetter(JSC::ExecState*, const JSC::Identifier& propertyName);\n") if $dataNode->extendedAttributes->{"CustomLookupSetter"};

    # Override toBoolean to return false for objects that want to 'MasqueradesAsUndefined'.
    if ($dataNode->extendedAttributes->{"MasqueradesAsUndefined"}) {
        push(@headerContent, "    virtual bool toBoolean(JSC::ExecState*) const { return false; };\n");
        $structureFlags{"JSC::MasqueradesAsUndefined"} = 1;
    }

    # Constructor object getter
    push(@headerContent, "    static JSC::JSValue getConstructor(JSC::ExecState*, JSC::JSGlobalObject*);\n") if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"}));

    my $numCustomFunctions = 0;
    my $numCustomAttributes = 0;

    # Attribute and function enums
    if ($numAttributes > 0) {
        foreach (@{$dataNode->attributes}) {
            my $attribute = $_;
            $numCustomAttributes++ if $attribute->signature->extendedAttributes->{"Custom"} || $attribute->signature->extendedAttributes->{"JSCCustom"};
            $numCustomAttributes++ if $attribute->signature->extendedAttributes->{"CustomGetter"} || $attribute->signature->extendedAttributes->{"JSCCustomGetter"};
            $numCustomAttributes++ if $attribute->signature->extendedAttributes->{"CustomSetter"} || $attribute->signature->extendedAttributes->{"JSCCustomSetter"};
            if ($attribute->signature->extendedAttributes->{"CachedAttribute"}) {
                push(@headerContent, "    static const unsigned " . $attribute->signature->name . "Slot = $numCachedAttributes + Base::AnonymousSlotCount;\n");
                $numCachedAttributes++;
            }
        }
    }

    if ($numCachedAttributes > 0) {
        push(@headerContent, "    using $parentClassName" . "::putAnonymousValue;\n");
        push(@headerContent, "    using $parentClassName" . "::getAnonymousValue;\n");
    }
    if ($numCustomAttributes > 0) {
        push(@headerContent, "\n    // Custom attributes\n");

        foreach my $attribute (@{$dataNode->attributes}) {
            if ($attribute->signature->extendedAttributes->{"Custom"} || $attribute->signature->extendedAttributes->{"JSCCustom"}) {
                push(@headerContent, "    JSC::JSValue " . $codeGenerator->WK_lcfirst($attribute->signature->name) . "(JSC::ExecState*) const;\n");
                if ($attribute->type !~ /^readonly/) {
                    push(@headerContent, "    void set" . $codeGenerator->WK_ucfirst($attribute->signature->name) . "(JSC::ExecState*, JSC::JSValue);\n");
                }
            } elsif ($attribute->signature->extendedAttributes->{"CustomGetter"} || $attribute->signature->extendedAttributes->{"JSCCustomGetter"}) {
                push(@headerContent, "    JSC::JSValue " . $codeGenerator->WK_lcfirst($attribute->signature->name) . "(JSC::ExecState*) const;\n");
            } elsif ($attribute->signature->extendedAttributes->{"CustomSetter"} || $attribute->signature->extendedAttributes->{"JSCCustomSetter"}) {
                if ($attribute->type !~ /^readonly/) {
                    push(@headerContent, "    void set" . $codeGenerator->WK_ucfirst($attribute->signature->name) . "(JSC::ExecState*, JSC::JSValue);\n");
                }
            }
        }
    }

    foreach my $function (@{$dataNode->functions}) {
        $numCustomFunctions++ if $function->signature->extendedAttributes->{"Custom"} || $function->signature->extendedAttributes->{"JSCCustom"};
    }

    if ($numCustomFunctions > 0) {
        push(@headerContent, "\n    // Custom functions\n");
        foreach my $function (@{$dataNode->functions}) {
            if ($function->signature->extendedAttributes->{"Custom"} || $function->signature->extendedAttributes->{"JSCCustom"}) {
                my $functionImplementationName = $function->signature->extendedAttributes->{"ImplementationFunction"} || $codeGenerator->WK_lcfirst($function->signature->name);
                push(@headerContent, "    JSC::JSValue " . $functionImplementationName . "(JSC::ExecState*, const JSC::ArgList&);\n");
            }
        }
    }

    if (!$hasParent) {
        # Extra space after JSSVGPODTypeWrapper<> to make RefPtr<Wrapper<> > compile.
        my $implType = $podType ? "JSSVGPODTypeWrapper<$podType> " : $implClassName;
        push(@headerContent, "    $implType* impl() const { return m_impl.get(); }\n\n");
        push(@headerContent, "private:\n");
        push(@headerContent, "    RefPtr<$implType> m_impl;\n");
    } elsif ($dataNode->extendedAttributes->{"GenerateNativeConverter"}) {
        push(@headerContent, "    $implClassName* impl() const\n");
        push(@headerContent, "    {\n");
        push(@headerContent, "        return static_cast<$implClassName*>(Base::impl());\n");
        push(@headerContent, "    }\n");
    }
    
    # anonymous slots
    if ($numCachedAttributes) {
        push(@headerContent, "public:\n");
        push(@headerContent, "    static const unsigned AnonymousSlotCount = $numCachedAttributes + Base::AnonymousSlotCount;\n");
    }

    # structure flags
    push(@headerContent, "protected:\n");
    push(@headerContent, "    static const unsigned StructureFlags = ");
    foreach my $structureFlag (keys %structureFlags) {
        push(@headerContent, $structureFlag . " | ");
    }
    push(@headerContent, "Base::StructureFlags;\n");

    # Index getter
    if ($dataNode->extendedAttributes->{"HasIndexGetter"}) {
        push(@headerContent, "    static JSC::JSValue indexGetter(JSC::ExecState*, const JSC::Identifier&, const JSC::PropertySlot&);\n");
    }
    if ($dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
        push(@headerContent, "    JSC::JSValue getByIndex(JSC::ExecState*, unsigned index);\n");
        
    }
    
    # Index setter
    if ($dataNode->extendedAttributes->{"HasCustomIndexSetter"}) {
        push(@headerContent, "    void indexSetter(JSC::ExecState*, unsigned index, JSC::JSValue);\n");
    }
    # Name getter
    if ($dataNode->extendedAttributes->{"HasNameGetter"} || $dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
        push(@headerContent, "private:\n");
        push(@headerContent, "    static bool canGetItemsForName(JSC::ExecState*, $implClassName*, const JSC::Identifier&);\n");
        push(@headerContent, "    static JSC::JSValue nameGetter(JSC::ExecState*, const JSC::Identifier&, const JSC::PropertySlot&);\n");
    }

    push(@headerContent, "};\n\n");

    if ($dataNode->extendedAttributes->{"InlineGetOwnPropertySlot"} && !$dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"}) {
        push(@headerContent, "ALWAYS_INLINE bool ${className}::getOwnPropertySlot(JSC::ExecState* exec, const JSC::Identifier& propertyName, JSC::PropertySlot& slot)\n");
        push(@headerContent, "{\n");
        push(@headerContent, GenerateGetOwnPropertySlotBody($dataNode, $interfaceName, $className, $implClassName, $numAttributes > 0, 1));
        push(@headerContent, "}\n\n");
        push(@headerContent, "ALWAYS_INLINE bool ${className}::getOwnPropertyDescriptor(JSC::ExecState* exec, const JSC::Identifier& propertyName, JSC::PropertyDescriptor& descriptor)\n");
        push(@headerContent, "{\n");
        push(@headerContent, GenerateGetOwnPropertyDescriptorBody($dataNode, $interfaceName, $className, $implClassName, $numAttributes > 0, 1));
        push(@headerContent, "}\n\n");
    }

    if (!$hasParent || $dataNode->extendedAttributes->{"GenerateToJS"} || $dataNode->extendedAttributes->{"CustomToJS"}) {
        if ($podType) {
            push(@headerContent, "JSC::JSValue toJS(JSC::ExecState*, JSDOMGlobalObject*, JSSVGPODTypeWrapper<$podType>*, SVGElement*);\n");
        } elsif (IsSVGTypeNeedingContextParameter($implClassName)) {
            push(@headerContent, "JSC::JSValue toJS(JSC::ExecState*, JSDOMGlobalObject*, $implType*, SVGElement* context);\n");
        } else {
            push(@headerContent, "JSC::JSValue toJS(JSC::ExecState*, JSDOMGlobalObject*, $implType*);\n");
        }
    }
    if (!$hasParent || $dataNode->extendedAttributes->{"GenerateNativeConverter"}) {
        if ($podType) {
            push(@headerContent, "$podType to${interfaceName}(JSC::JSValue);\n");
        } elsif ($interfaceName eq "NodeFilter") {
            push(@headerContent, "PassRefPtr<NodeFilter> toNodeFilter(JSC::JSValue);\n");
        } else {
            push(@headerContent, "$implClassName* to${interfaceName}(JSC::JSValue);\n");
        }
    }
    if ($usesToJSNewlyCreated{$interfaceName}) {
        push(@headerContent, "JSC::JSValue toJSNewlyCreated(JSC::ExecState*, JSDOMGlobalObject*, $interfaceName*);\n");
    }
    
    push(@headerContent, "\n");

    # Add prototype declaration.
    %structureFlags = ();
    push(@headerContent, "class ${className}Prototype : public JSC::JSObject {\n");
    push(@headerContent, "    typedef JSC::JSObject Base;\n");
    push(@headerContent, "public:\n");
    if ($interfaceName eq "DOMWindow") {
        push(@headerContent, "    void* operator new(size_t);\n");
    } elsif ($dataNode->extendedAttributes->{"IsWorkerContext"}) {
        push(@headerContent, "    void* operator new(size_t, JSC::JSGlobalData*);\n");
    } else {
        push(@headerContent, "    static JSC::JSObject* self(JSC::ExecState*, JSC::JSGlobalObject*);\n");
    }
    push(@headerContent, "    virtual const JSC::ClassInfo* classInfo() const { return &s_info; }\n");
    push(@headerContent, "    static const JSC::ClassInfo s_info;\n");
    if ($numFunctions > 0 || $numConstants > 0 || $dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"}) {
        push(@headerContent, "    virtual bool getOwnPropertySlot(JSC::ExecState*, const JSC::Identifier&, JSC::PropertySlot&);\n");
        push(@headerContent, "    virtual bool getOwnPropertyDescriptor(JSC::ExecState*, const JSC::Identifier&, JSC::PropertyDescriptor&);\n");
        push(@headerContent, "    bool getOwnPropertySlotDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::PropertySlot&);\n") if $dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"};
        push(@headerContent, "    bool getOwnPropertyDescriptorDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::PropertyDescriptor&);\n") if $dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"};
        $structureFlags{"JSC::OverridesGetOwnPropertySlot"} = 1;
    }
    if ($dataNode->extendedAttributes->{"CustomMarkFunction"} or $needsMarkChildren) {
        $structureFlags{"JSC::OverridesMarkChildren"} = 1;
    }
    push(@headerContent,
        "    static PassRefPtr<JSC::Structure> createStructure(JSC::JSValue prototype)\n" .
        "    {\n" .
        "        return JSC::Structure::create(prototype, JSC::TypeInfo(JSC::ObjectType, StructureFlags), AnonymousSlotCount);\n" .
        "    }\n");
    if ($dataNode->extendedAttributes->{"DelegatingPrototypePutFunction"}) {
        push(@headerContent, "    virtual void put(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSValue, JSC::PutPropertySlot&);\n");
        push(@headerContent, "    bool putDelegate(JSC::ExecState*, const JSC::Identifier&, JSC::JSValue, JSC::PutPropertySlot&);\n");
    }

    # Custom defineGetter function
    push(@headerContent, "    virtual void defineGetter(JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSObject* getterFunction, unsigned attributes);\n") if $dataNode->extendedAttributes->{"CustomPrototypeDefineGetter"};

    push(@headerContent, "    ${className}Prototype(NonNullPassRefPtr<JSC::Structure> structure) : JSC::JSObject(structure) { }\n");

    # structure flags
    push(@headerContent, "protected:\n");
    push(@headerContent, "    static const unsigned StructureFlags = ");
    foreach my $structureFlag (keys %structureFlags) {
        push(@headerContent, $structureFlag . " | ");
    }
    push(@headerContent, "Base::StructureFlags;\n");

    push(@headerContent, "};\n\n");

    if ($numFunctions > 0) {
        push(@headerContent,"// Functions\n\n");
        foreach my $function (@{$dataNode->functions}) {
            my $functionName = $codeGenerator->WK_lcfirst($className) . "PrototypeFunction" . $codeGenerator->WK_ucfirst($function->signature->name);
            push(@headerContent, "JSC::JSValue JSC_HOST_CALL ${functionName}(JSC::ExecState*, JSC::JSObject*, JSC::JSValue, const JSC::ArgList&);\n");
        }
    }

    if ($numAttributes > 0 || !($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
        push(@headerContent,"// Attributes\n\n");
        foreach my $attribute (@{$dataNode->attributes}) {
            my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($attribute->signature->name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
            push(@headerContent, "JSC::JSValue ${getter}(JSC::ExecState*, const JSC::Identifier&, const JSC::PropertySlot&);\n");
            unless ($attribute->type =~ /readonly/) {
                my $setter = "setJS" . $interfaceName . $codeGenerator->WK_ucfirst($attribute->signature->name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
                push(@headerContent, "void ${setter}(JSC::ExecState*, JSC::JSObject*, JSC::JSValue);\n");
            }
        }
        
        if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
            my $getter = "js" . $interfaceName . "Constructor";
            push(@headerContent, "JSC::JSValue ${getter}(JSC::ExecState*, const JSC::Identifier&, const JSC::PropertySlot&);\n");
        }
    }

    if ($numConstants > 0) {
        push(@headerContent,"// Constants\n\n");
        foreach my $constant (@{$dataNode->constants}) {
            my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($constant->name);
            push(@headerContent, "JSC::JSValue ${getter}(JSC::ExecState*, const JSC::Identifier&, const JSC::PropertySlot&);\n");
        }
    }

    push(@headerContent, "\n} // namespace WebCore\n\n");
    push(@headerContent, "#endif // ${conditionalString}\n\n") if $conditional;
    push(@headerContent, "#endif\n");

    # - Generate dependencies.
    if ($writeDependencies && @ancestorInterfaceNames) {
        push(@depsContent, "$className.h : ", join(" ", map { "$_.idl" } @ancestorInterfaceNames), "\n");
        push(@depsContent, map { "$_.idl :\n" } @ancestorInterfaceNames); 
    }
}

sub GenerateImplementation
{
    my ($object, $dataNode) = @_;

    my $interfaceName = $dataNode->name;
    my $className = "JS$interfaceName";
    my $implClassName = $interfaceName;

    my $hasLegacyParent = $dataNode->extendedAttributes->{"LegacyParent"};
    my $hasRealParent = @{$dataNode->parents} > 0;
    my $hasParent = $hasLegacyParent || $hasRealParent;
    my $parentClassName = GetParentClassName($dataNode);
    my $conditional = $dataNode->extendedAttributes->{"Conditional"};
    my $visibleClassName = GetVisibleClassName($interfaceName);
    my $eventTarget = $dataNode->extendedAttributes->{"EventTarget"};
    my $needsMarkChildren = $dataNode->extendedAttributes->{"CustomMarkFunction"} || $dataNode->extendedAttributes->{"EventTarget"};

    # - Add default header template
    @implContentHeader = split("\r", $headerTemplate);

    push(@implContentHeader, "\n#include \"config.h\"\n");
    my $conditionalString;
    if ($conditional) {
        $conditionalString = "ENABLE(" . join(") && ENABLE(", split(/&/, $conditional)) . ")";
        push(@implContentHeader, "\n#if ${conditionalString}\n\n");
    }
    push(@implContentHeader, "#include \"$className.h\"\n\n");

    AddIncludesForSVGAnimatedType($interfaceName) if $className =~ /^JSSVGAnimated/;

    $implIncludes{"<wtf/GetPtr.h>"} = 1;
    $implIncludes{"<runtime/PropertyNameArray.h>"} = 1 if $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"};

    AddIncludesForType($interfaceName);

    @implContent = ();

    push(@implContent, "\nusing namespace JSC;\n\n");
    push(@implContent, "namespace WebCore {\n\n");

    push(@implContent, "ASSERT_CLASS_FITS_IN_CELL($className);\n\n");

    # - Add all attributes in a hashtable definition
    my $numAttributes = @{$dataNode->attributes};
    $numAttributes++ if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"}));

    if ($numAttributes > 0) {
        my $hashSize = $numAttributes;
        my $hashName = $className . "Table";

        my @hashKeys = ();
        my @hashSpecials = ();
        my @hashValue1 = ();
        my @hashValue2 = ();
        my %conditionals = ();

        my @entries = ();

        foreach my $attribute (@{$dataNode->attributes}) {
            my $name = $attribute->signature->name;
            push(@hashKeys, $name);

            my @specials = ();
            push(@specials, "DontDelete") unless $attribute->signature->extendedAttributes->{"Deletable"};
            push(@specials, "DontEnum") if $attribute->signature->extendedAttributes->{"DontEnum"};
            push(@specials, "ReadOnly") if $attribute->type =~ /readonly/;
            my $special = (@specials > 0) ? join("|", @specials) : "0";
            push(@hashSpecials, $special);

            my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($attribute->signature->name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
            push(@hashValue1, $getter);
    
            if ($attribute->type =~ /readonly/) {
                push(@hashValue2, "0");
            } else {
                my $setter = "setJS" . $interfaceName . $codeGenerator->WK_ucfirst($attribute->signature->name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
                push(@hashValue2, $setter);
            }

            my $conditional = $attribute->signature->extendedAttributes->{"Conditional"};
            if ($conditional) {
                $conditionals{$name} = $conditional;
            }
        }

        if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
            push(@hashKeys, "constructor");
            my $getter = "js" . $interfaceName . "Constructor";
            push(@hashValue1, $getter);
            push(@hashValue2, "0");
            push(@hashSpecials, "DontEnum|ReadOnly"); # FIXME: Setting the constructor should be possible.
        }

        $object->GenerateHashTable($hashName, $hashSize,
                                   \@hashKeys, \@hashSpecials,
                                   \@hashValue1, \@hashValue2,
                                   \%conditionals);
    }

    my $numConstants = @{$dataNode->constants};
    my $numFunctions = @{$dataNode->functions};

    # - Add all constants
    if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
        $hashSize = $numConstants;
        $hashName = $className . "ConstructorTable";

        @hashKeys = ();
        @hashValue1 = ();
        @hashValue2 = ();
        @hashSpecials = ();

        # FIXME: we should not need a function for every constant.
        foreach my $constant (@{$dataNode->constants}) {
            push(@hashKeys, $constant->name);
            my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($constant->name);
            push(@hashValue1, $getter);
            push(@hashValue2, "0");
            push(@hashSpecials, "DontDelete|ReadOnly");
        }

        $object->GenerateHashTable($hashName, $hashSize,
                                   \@hashKeys, \@hashSpecials,
                                   \@hashValue1, \@hashValue2);

        my $protoClassName;
        $protoClassName = "${className}Prototype";

        push(@implContent, constructorFor($className, $protoClassName, $interfaceName, $visibleClassName, $dataNode->extendedAttributes->{"CanBeConstructed"}));
    }

    # - Add functions and constants to a hashtable definition
    $hashSize = $numFunctions + $numConstants;
    $hashName = $className . "PrototypeTable";

    @hashKeys = ();
    @hashValue1 = ();
    @hashValue2 = ();
    @hashSpecials = ();

    # FIXME: we should not need a function for every constant.
    foreach my $constant (@{$dataNode->constants}) {
        push(@hashKeys, $constant->name);
        my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($constant->name);
        push(@hashValue1, $getter);
        push(@hashValue2, "0");
        push(@hashSpecials, "DontDelete|ReadOnly");
    }

    foreach my $function (@{$dataNode->functions}) {
        my $name = $function->signature->name;
        push(@hashKeys, $name);

        my $value = $codeGenerator->WK_lcfirst($className) . "PrototypeFunction" . $codeGenerator->WK_ucfirst($name);
        push(@hashValue1, $value);

        my $numParameters = @{$function->parameters};
        push(@hashValue2, $numParameters);

        my @specials = ();
        push(@specials, "DontDelete") unless $function->signature->extendedAttributes->{"Deletable"};
        push(@specials, "DontEnum") if $function->signature->extendedAttributes->{"DontEnum"};
        push(@specials, "Function");
        my $special = (@specials > 0) ? join("|", @specials) : "0";
        push(@hashSpecials, $special);
    }

    $object->GenerateHashTable($hashName, $hashSize,
                               \@hashKeys, \@hashSpecials,
                               \@hashValue1, \@hashValue2);

    if ($dataNode->extendedAttributes->{"NoStaticTables"}) {
        push(@implContent, "static const HashTable* get${className}PrototypeTable(ExecState* exec)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return getHashTableForGlobalData(exec->globalData(), &${className}PrototypeTable);\n");
        push(@implContent, "}\n");
        push(@implContent, "const ClassInfo ${className}Prototype::s_info = { \"${visibleClassName}Prototype\", 0, 0, get${className}PrototypeTable };\n\n");
    } else {
        push(@implContent, "const ClassInfo ${className}Prototype::s_info = { \"${visibleClassName}Prototype\", 0, &${className}PrototypeTable, 0 };\n\n");
    }
    if ($interfaceName eq "DOMWindow") {
        push(@implContent, "void* ${className}Prototype::operator new(size_t size)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return JSDOMWindow::commonJSGlobalData()->heap.allocate(size);\n");
        push(@implContent, "}\n\n");
    } elsif ($dataNode->extendedAttributes->{"IsWorkerContext"}) {
        push(@implContent, "void* ${className}Prototype::operator new(size_t size, JSGlobalData* globalData)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return globalData->heap.allocate(size);\n");
        push(@implContent, "}\n\n");
    } else {
        push(@implContent, "JSObject* ${className}Prototype::self(ExecState* exec, JSGlobalObject* globalObject)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return getDOMPrototype<${className}>(exec, globalObject);\n");
        push(@implContent, "}\n\n");
    }
    if ($numConstants > 0 || $numFunctions > 0 || $dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"}) {
        push(@implContent, "bool ${className}Prototype::getOwnPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)\n");
        push(@implContent, "{\n");

        if ($dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"}) {
            push(@implContent, "    if (getOwnPropertySlotDelegate(exec, propertyName, slot))\n");
            push(@implContent, "        return true;\n");
        }

        if ($numConstants eq 0 && $numFunctions eq 0) {
            push(@implContent, "    return Base::getOwnPropertySlot(exec, propertyName, slot);\n");        
        } elsif ($numConstants eq 0) {
            push(@implContent, "    return getStaticFunctionSlot<JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, slot);\n");
        } elsif ($numFunctions eq 0) {
            push(@implContent, "    return getStaticValueSlot<${className}Prototype, JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, slot);\n");
        } else {
            push(@implContent, "    return getStaticPropertySlot<${className}Prototype, JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, slot);\n");
        }
        push(@implContent, "}\n\n");

        push(@implContent, "bool ${className}Prototype::getOwnPropertyDescriptor(ExecState* exec, const Identifier& propertyName, PropertyDescriptor& descriptor)\n");
        push(@implContent, "{\n");
        
        if ($dataNode->extendedAttributes->{"DelegatingPrototypeGetOwnPropertySlot"}) {
            push(@implContent, "    if (getOwnPropertyDescriptorDelegate(exec, propertyName, descriptor))\n");
            push(@implContent, "        return true;\n");
        }
        
        if ($numConstants eq 0 && $numFunctions eq 0) {
            push(@implContent, "    return Base::getOwnPropertyDescriptor(exec, propertyName, descriptor);\n");        
        } elsif ($numConstants eq 0) {
            push(@implContent, "    return getStaticFunctionDescriptor<JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, descriptor);\n");
        } elsif ($numFunctions eq 0) {
            push(@implContent, "    return getStaticValueDescriptor<${className}Prototype, JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, descriptor);\n");
        } else {
            push(@implContent, "    return getStaticPropertyDescriptor<${className}Prototype, JSObject>(exec, " . prototypeHashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, propertyName, descriptor);\n");
        }
        push(@implContent, "}\n\n");
    }

    if ($dataNode->extendedAttributes->{"DelegatingPrototypePutFunction"}) {
        push(@implContent, "void ${className}Prototype::put(ExecState* exec, const Identifier& propertyName, JSValue value, PutPropertySlot& slot)\n");
        push(@implContent, "{\n");
        push(@implContent, "    if (putDelegate(exec, propertyName, value, slot))\n");
        push(@implContent, "        return;\n");
        push(@implContent, "    Base::put(exec, propertyName, value, slot);\n");
        push(@implContent, "}\n\n");
    }

    # - Initialize static ClassInfo object
    if ($numAttributes > 0 && $dataNode->extendedAttributes->{"NoStaticTables"}) {
        push(@implContent, "static const HashTable* get${className}Table(ExecState* exec)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return getHashTableForGlobalData(exec->globalData(), &${className}Table);\n");
        push(@implContent, "}\n");
    }
    push(@implContent, "const ClassInfo $className" . "::s_info = { \"${visibleClassName}\", ");
    if ($hasParent) {
        push(@implContent, "&" . $parentClassName . "::s_info, ");
    } else {
        push(@implContent, "0, ");
    }

    if ($numAttributes > 0 && !$dataNode->extendedAttributes->{"NoStaticTables"}) {
        push(@implContent, "&${className}Table");
    } else {
        push(@implContent, "0");
    }
    if ($numAttributes > 0 && $dataNode->extendedAttributes->{"NoStaticTables"}) {
        push(@implContent, ", get${className}Table ");
    } else {
        push(@implContent, ", 0 ");
    }
    push(@implContent, "};\n\n");

    # Get correct pass/store types respecting PODType flag
    my $podType = $dataNode->extendedAttributes->{"PODType"};
    my $implType = $podType ? "JSSVGPODTypeWrapper<$podType> " : $implClassName;

    # Constructor
    if ($interfaceName eq "DOMWindow") {
        AddIncludesForType("JSDOMWindowShell");
        push(@implContent, "${className}::$className(NonNullPassRefPtr<Structure> structure, PassRefPtr<$implType> impl, JSDOMWindowShell* shell)\n");
        push(@implContent, "    : $parentClassName(structure, impl, shell)\n");
    } elsif ($dataNode->extendedAttributes->{"IsWorkerContext"}) {
        AddIncludesForType($interfaceName);
        push(@implContent, "${className}::$className(NonNullPassRefPtr<Structure> structure, PassRefPtr<$implType> impl)\n");
        push(@implContent, "    : $parentClassName(structure, impl)\n");
    } else {
        push(@implContent, "${className}::$className(NonNullPassRefPtr<Structure> structure, JSDOMGlobalObject* globalObject, PassRefPtr<$implType> impl)\n");
        if ($hasParent) {
            push(@implContent, "    : $parentClassName(structure, globalObject, impl)\n");
        } else {
            push(@implContent, "    : $parentClassName(structure, globalObject)\n");
            push(@implContent, "    , m_impl(impl)\n");
        }
    }
    push(@implContent, "{\n");
    if ($numCachedAttributes > 0) {
        push(@implContent, "    for (unsigned i = Base::AnonymousSlotCount; i < AnonymousSlotCount; i++)\n");
        push(@implContent, "        putAnonymousValue(i, JSValue());\n");
    }
    push(@implContent, "}\n\n");

    # Destructor
    if (!$hasParent || $eventTarget) {
        push(@implContent, "${className}::~$className()\n");
        push(@implContent, "{\n");

        if ($eventTarget) {
            $implIncludes{"RegisteredEventListener.h"} = 1;
            push(@implContent, "    impl()->invalidateJSEventListeners(this);\n");
        }

        if (!$dataNode->extendedAttributes->{"ExtendsDOMGlobalObject"}) {
            if ($interfaceName eq "Node") {
                 push(@implContent, "    forgetDOMNode(this, impl(), impl()->document());\n");
            } else {
                push(@implContent, "    forgetDOMObject(this, impl());\n");
            }

            push(@implContent, "    JSSVGContextCache::forgetWrapper(this);\n") if IsSVGTypeNeedingContextParameter($implClassName);
        }

        push(@implContent, "}\n\n");
    }

    if ($needsMarkChildren && !$dataNode->extendedAttributes->{"CustomMarkFunction"}) {
        push(@implContent, "void ${className}::markChildren(MarkStack& markStack)\n");
        push(@implContent, "{\n");
        push(@implContent, "    Base::markChildren(markStack);\n");
        push(@implContent, "    impl()->markJSEventListeners(markStack);\n");
        push(@implContent, "}\n\n");
    }

    if (!$dataNode->extendedAttributes->{"ExtendsDOMGlobalObject"}) {
        push(@implContent, "JSObject* ${className}::createPrototype(ExecState* exec, JSGlobalObject* globalObject)\n");
        push(@implContent, "{\n");
        if ($hasParent && $parentClassName ne "JSC::DOMNodeFilter") {
            push(@implContent, "    return new (exec) ${className}Prototype(${className}Prototype::createStructure(${parentClassName}Prototype::self(exec, globalObject)));\n");
        } else {
            push(@implContent, "    return new (exec) ${className}Prototype(${className}Prototype::createStructure(globalObject->objectPrototype()));\n");
        }
        push(@implContent, "}\n\n");
    }

    my $hasGetter = $numAttributes > 0 
                 || !($dataNode->extendedAttributes->{"OmitConstructor"} 
                 || $dataNode->extendedAttributes->{"CustomConstructor"})
                 || $dataNode->extendedAttributes->{"HasIndexGetter"}
                 || $dataNode->extendedAttributes->{"HasCustomIndexGetter"}
                 || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}
                 || $dataNode->extendedAttributes->{"DelegatingGetOwnPropertySlot"}
                 || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"}
                 || $dataNode->extendedAttributes->{"HasNameGetter"}
                 || $dataNode->extendedAttributes->{"HasOverridingNameGetter"};

    # Attributes
    if ($hasGetter) {
        if (!$dataNode->extendedAttributes->{"InlineGetOwnPropertySlot"} && !$dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"}) {
            push(@implContent, "bool ${className}::getOwnPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)\n");
            push(@implContent, "{\n");
            push(@implContent, GenerateGetOwnPropertySlotBody($dataNode, $interfaceName, $className, $implClassName, $numAttributes > 0, 0));
            push(@implContent, "}\n\n");
            push(@implContent, "bool ${className}::getOwnPropertyDescriptor(ExecState* exec, const Identifier& propertyName, PropertyDescriptor& descriptor)\n");
            push(@implContent, "{\n");
            push(@implContent, GenerateGetOwnPropertyDescriptorBody($dataNode, $interfaceName, $className, $implClassName, $numAttributes > 0, 0));
            push(@implContent, "}\n\n");
        }

        if (($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) 
                && !$dataNode->extendedAttributes->{"HasOverridingNameGetter"}) {
            push(@implContent, "bool ${className}::getOwnPropertySlot(ExecState* exec, unsigned propertyName, PropertySlot& slot)\n");
            push(@implContent, "{\n");
            push(@implContent, "    if (propertyName < static_cast<$implClassName*>(impl())->length()) {\n");
            if ($dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
                push(@implContent, "        slot.setValue(getByIndex(exec, propertyName));\n");
            } else {
                push(@implContent, "        slot.setCustomIndex(this, propertyName, indexGetter);\n");
            }
            push(@implContent, "        return true;\n");
            push(@implContent, "    }\n");
            push(@implContent, "    return getOwnPropertySlot(exec, Identifier::from(exec, propertyName), slot);\n");
            push(@implContent, "}\n\n");
        }
        
        if ($numAttributes > 0) {
            foreach my $attribute (@{$dataNode->attributes}) {
                my $name = $attribute->signature->name;
                my $type = $codeGenerator->StripModule($attribute->signature->type);
                my $getFunctionName = "js" . $interfaceName .  $codeGenerator->WK_ucfirst($attribute->signature->name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
                my $implGetterFunctionName = $codeGenerator->WK_lcfirst($name);

                my $conditional = $attribute->signature->extendedAttributes->{"Conditional"};
                if ($conditional) {
                    $conditionalString = "ENABLE(" . join(") && ENABLE(", split(/&/, $conditional)) . ")";
                    push(@implContent, "#if ${conditionalString}\n");
                }

                push(@implContent, "JSValue ${getFunctionName}(ExecState* exec, const Identifier&, const PropertySlot& slot)\n");
                push(@implContent, "{\n");
                push(@implContent, "    ${className}* castedThis = static_cast<$className*>(asObject(slot.slotBase()));\n");

                my $implClassNameForValueConversion = "";
                if (!$podType and ($codeGenerator->IsSVGAnimatedType($implClassName) or $attribute->type !~ /^readonly/)) {
                    $implClassNameForValueConversion = $implClassName;
                }

                if ($dataNode->extendedAttributes->{"CheckDomainSecurity"} && 
                        !$attribute->signature->extendedAttributes->{"DoNotCheckDomainSecurity"} &&
                        !$attribute->signature->extendedAttributes->{"DoNotCheckDomainSecurityOnGet"}) {
                    push(@implContent, "    if (!castedThis->allowsAccessFrom(exec))\n");
                    push(@implContent, "        return jsUndefined();\n");
                }

                if ($attribute->signature->extendedAttributes->{"Custom"} || $attribute->signature->extendedAttributes->{"JSCCustom"} || $attribute->signature->extendedAttributes->{"CustomGetter"} || $attribute->signature->extendedAttributes->{"JSCCustomGetter"}) {
                    push(@implContent, "    return castedThis->$implGetterFunctionName(exec);\n");
                } elsif ($attribute->signature->extendedAttributes->{"CheckNodeSecurity"}) {
                    $implIncludes{"JSDOMBinding.h"} = 1;
                    push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(castedThis->impl());\n");
                    push(@implContent, "    return checkNodeSecurity(exec, imp->$implGetterFunctionName()) ? " . NativeToJSValue($attribute->signature, 0, $implClassName, $implClassNameForValueConversion, "imp->$implGetterFunctionName()", "castedThis") . " : jsUndefined();\n");
                } elsif ($attribute->signature->extendedAttributes->{"CheckFrameSecurity"}) {
                    $implIncludes{"Document.h"} = 1;
                    $implIncludes{"JSDOMBinding.h"} = 1;
                    push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(castedThis->impl());\n");
                    push(@implContent, "    return checkNodeSecurity(exec, imp->contentDocument()) ? " . NativeToJSValue($attribute->signature,  0, $implClassName, $implClassNameForValueConversion, "imp->$implGetterFunctionName()", "castedThis") . " : jsUndefined();\n");
                } elsif ($type eq "EventListener") {
                    $implIncludes{"EventListener.h"} = 1;
                    push(@implContent, "    UNUSED_PARAM(exec);\n");
                    push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(castedThis->impl());\n");
                    push(@implContent, "    if (EventListener* listener = imp->$implGetterFunctionName()) {\n");
                    push(@implContent, "        if (const JSEventListener* jsListener = JSEventListener::cast(listener)) {\n");
                    if ($implClassName eq "Document" || $implClassName eq "WorkerContext" || $implClassName eq "SharedWorkerContext" || $implClassName eq "DedicatedWorkerContext") {
                        push(@implContent, "            if (JSObject* jsFunction = jsListener->jsFunction(imp))\n");
                    } else {
                        push(@implContent, "            if (JSObject* jsFunction = jsListener->jsFunction(imp->scriptExecutionContext()))\n");
                    }
                    push(@implContent, "                return jsFunction;\n");
                    push(@implContent, "        }\n");
                    push(@implContent, "    }\n");
                    push(@implContent, "    return jsNull();\n");
                } elsif ($attribute->signature->type =~ /Constructor$/) {
                    my $constructorType = $codeGenerator->StripModule($attribute->signature->type);
                    $constructorType =~ s/Constructor$//;
                    # Constructor attribute is only used by DOMWindow.idl, so it's correct to pass castedThis as the global object
                    # Once DOMObjects have a back-pointer to the globalObject we can pass castedThis->globalObject()
                    push(@implContent, "    return JS" . $constructorType . "::getConstructor(exec, castedThis);\n");
                } elsif (!@{$attribute->getterExceptions}) {
                    push(@implContent, "    UNUSED_PARAM(exec);\n");
                    my $cacheIndex = 0;
                    if ($attribute->signature->extendedAttributes->{"CachedAttribute"}) {
                        $cacheIndex = $currentCachedAttribute;
                        $currentCachedAttribute++;
                        push(@implContent, "    if (JSValue cachedValue = castedThis->getAnonymousValue(" . $className . "::" . $attribute->signature->name . "Slot))\n");
                        push(@implContent, "        return cachedValue;\n");
                    }
                    if ($podType) {
                        push(@implContent, "    $podType imp(*castedThis->impl());\n");
                        if ($podType eq "float") { # Special case for JSSVGNumber
                            push(@implContent, "    JSValue result =  " . NativeToJSValue($attribute->signature, 0, $implClassName, "", "imp", "castedThis") . ";\n");
                        } else {
                            push(@implContent, "    JSValue result =  " . NativeToJSValue($attribute->signature, 0, $implClassName, "", "imp.$implGetterFunctionName()", "castedThis") . ";\n");
                        }
                    } else {
                        push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(castedThis->impl());\n");
                        my $value;
                        my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
                        my $reflectURL = $attribute->signature->extendedAttributes->{"ReflectURL"};
                        if ($reflect || $reflectURL) {
                            my $contentAttributeName = (($reflect || $reflectURL) eq "1") ? $name : ($reflect || $reflectURL);
                            my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
                            $implIncludes{"${namespace}.h"} = 1;
                            my $getAttributeFunctionName = $reflectURL ? "getURLAttribute" : "getAttribute";
                            $value = "imp->$getAttributeFunctionName(${namespace}::${contentAttributeName}Attr)"
                        } else {
                            $value = "imp->$implGetterFunctionName()";
                        }
                        my $jsType = NativeToJSValue($attribute->signature, 0, $implClassName, $implClassNameForValueConversion, $value, "castedThis");
                        if ($codeGenerator->IsSVGAnimatedType($type)) {
                            push(@implContent, "    RefPtr<$type> obj = $jsType;\n");
                            push(@implContent, "    JSValue result =  toJS(exec, castedThis->globalObject(), obj.get(), imp);\n");
                        } else {
                            push(@implContent, "    JSValue result = $jsType;\n");
                        }
                    }
                    
                    push(@implContent, "    castedThis->putAnonymousValue(" . $className . "::" . $attribute->signature->name . "Slot, result);\n") if ($attribute->signature->extendedAttributes->{"CachedAttribute"});
                    push(@implContent, "    return result;\n");

                } else {
                    push(@implContent, "    ExceptionCode ec = 0;\n");                    
                    if ($podType) {
                        push(@implContent, "    $podType imp(*castedThis->impl());\n");
                        push(@implContent, "    JSC::JSValue result = " . NativeToJSValue($attribute->signature, 0, $implClassName, "", "imp.$implGetterFunctionName(ec)", "castedThis") . ";\n");
                    } else {
                        push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(castedThis->impl());\n");
                        push(@implContent, "    JSC::JSValue result = " . NativeToJSValue($attribute->signature, 0, $implClassName, $implClassNameForValueConversion, "imp->$implGetterFunctionName(ec)", "castedThis") . ";\n");
                    }

                    push(@implContent, "    setDOMException(exec, ec);\n");
                    push(@implContent, "    return result;\n");
                }

                push(@implContent, "}\n");

                if ($conditional) {
                    push(@implContent, "#endif\n");
                }

                push(@implContent, "\n");
            }

            if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
                my $constructorFunctionName = "js" . $interfaceName . "Constructor";

                push(@implContent, "JSValue ${constructorFunctionName}(ExecState* exec, const Identifier&, const PropertySlot& slot)\n");
                push(@implContent, "{\n");
                push(@implContent, "    ${className}* domObject = static_cast<$className*>(asObject(slot.slotBase()));\n");
                push(@implContent, "    return ${className}::getConstructor(exec, domObject->globalObject());\n");
                push(@implContent, "}\n");
            }
        }

        # Check if we have any writable attributes
        my $hasReadWriteProperties = 0;
        foreach my $attribute (@{$dataNode->attributes}) {
            $hasReadWriteProperties = 1 if $attribute->type !~ /^readonly/;
        }

        my $hasSetter = $hasReadWriteProperties
                     || $dataNode->extendedAttributes->{"DelegatingPutFunction"}
                     || $dataNode->extendedAttributes->{"HasCustomIndexSetter"};

        if ($hasSetter) {
            if (!$dataNode->extendedAttributes->{"CustomPutFunction"}) {
                push(@implContent, "void ${className}::put(ExecState* exec, const Identifier& propertyName, JSValue value, PutPropertySlot& slot)\n");
                push(@implContent, "{\n");
                if ($dataNode->extendedAttributes->{"HasCustomIndexSetter"}) {
                    push(@implContent, "    bool ok;\n");
                    push(@implContent, "    unsigned index = propertyName.toUInt32(&ok, false);\n");
                    push(@implContent, "    if (ok) {\n");
                    push(@implContent, "        indexSetter(exec, index, value);\n");
                    push(@implContent, "        return;\n");
                    push(@implContent, "    }\n");
                }
                if ($dataNode->extendedAttributes->{"DelegatingPutFunction"}) {
                    push(@implContent, "    if (putDelegate(exec, propertyName, value, slot))\n");
                    push(@implContent, "        return;\n");
                }

                if ($hasReadWriteProperties) {
                    push(@implContent, "    lookupPut<$className, Base>(exec, propertyName, value, " . hashTableAccessor($dataNode->extendedAttributes->{"NoStaticTables"}, $className) . ", this, slot);\n");
                } else {
                    push(@implContent, "    Base::put(exec, propertyName, value, slot);\n");
                }
                push(@implContent, "}\n\n");
            }

            if ($dataNode->extendedAttributes->{"HasCustomIndexSetter"}) {
                push(@implContent, "void ${className}::put(ExecState* exec, unsigned propertyName, JSValue value)\n");
                push(@implContent, "{\n");
                push(@implContent, "    indexSetter(exec, propertyName, value);\n");
                push(@implContent, "    return;\n");
                push(@implContent, "}\n\n");
            }

            if ($hasReadWriteProperties) {
                foreach my $attribute (@{$dataNode->attributes}) {
                    if ($attribute->type !~ /^readonly/) {
                        my $name = $attribute->signature->name;
                        my $type = $codeGenerator->StripModule($attribute->signature->type);
                        my $putFunctionName = "setJS" . $interfaceName .  $codeGenerator->WK_ucfirst($name) . ($attribute->signature->type =~ /Constructor$/ ? "Constructor" : "");
                        my $implSetterFunctionName = $codeGenerator->WK_ucfirst($name);

                        push(@implContent, "void ${putFunctionName}(ExecState* exec, JSObject* thisObject, JSValue value)\n");
                        push(@implContent, "{\n");

                        if ($dataNode->extendedAttributes->{"CheckDomainSecurity"} && !$attribute->signature->extendedAttributes->{"DoNotCheckDomainSecurity"}) {
                            if ($interfaceName eq "DOMWindow") {
                                push(@implContent, "    if (!static_cast<$className*>(thisObject)->allowsAccessFrom(exec))\n");
                            } else {
                                push(@implContent, "    if (!allowsAccessFromFrame(exec, static_cast<$className*>(thisObject)->impl()->frame()))\n");
                            }
                            push(@implContent, "        return;\n");
                        }

                        if ($attribute->signature->extendedAttributes->{"Custom"} || $attribute->signature->extendedAttributes->{"JSCCustom"} || $attribute->signature->extendedAttributes->{"CustomSetter"} || $attribute->signature->extendedAttributes->{"JSCCustomSetter"}) {
                            push(@implContent, "    static_cast<$className*>(thisObject)->set$implSetterFunctionName(exec, value);\n");
                        } elsif ($type eq "EventListener") {
                            $implIncludes{"JSEventListener.h"} = 1;
                            push(@implContent, "    UNUSED_PARAM(exec);\n");
                            push(@implContent, "    $implClassName* imp = static_cast<$implClassName*>(static_cast<$className*>(thisObject)->impl());\n");
                            push(@implContent, "    imp->set$implSetterFunctionName(createJSAttributeEventListener(exec, value, thisObject));\n");
                        } elsif ($attribute->signature->type =~ /Constructor$/) {
                            my $constructorType = $attribute->signature->type;
                            $constructorType =~ s/Constructor$//;
                            $implIncludes{"JS" . $constructorType . ".h"} = 1;
                            push(@implContent, "    // Shadowing a built-in constructor\n");
                            push(@implContent, "    static_cast<$className*>(thisObject)->putDirect(Identifier(exec, \"$name\"), value);\n");
                        } elsif ($attribute->signature->extendedAttributes->{"Replaceable"}) {
                            push(@implContent, "    // Shadowing a built-in object\n");
                            push(@implContent, "    static_cast<$className*>(thisObject)->putDirect(Identifier(exec, \"$name\"), value);\n");
                        } else {
                            push(@implContent, "    $className* castedThisObj = static_cast<$className*>(thisObject);\n");
                            push(@implContent, "    $implType* imp = static_cast<$implType*>(castedThisObj->impl());\n");
                            if ($podType) {
                                push(@implContent, "    $podType podImp(*imp);\n");
                                if ($podType eq "float") { # Special case for JSSVGNumber
                                    push(@implContent, "    podImp = " . JSValueToNative($attribute->signature, "value") . ";\n");
                                } else {
                                    push(@implContent, "    podImp.set$implSetterFunctionName(" . JSValueToNative($attribute->signature, "value") . ");\n");
                                }
                                push(@implContent, "    imp->commitChange(podImp, castedThisObj);\n");
                            } else {
                                my $nativeValue = JSValueToNative($attribute->signature, "value");
                                push(@implContent, "    ExceptionCode ec = 0;\n") if @{$attribute->setterExceptions};
                                my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
                                my $reflectURL = $attribute->signature->extendedAttributes->{"ReflectURL"};
                                if ($reflect || $reflectURL) {
                                    my $contentAttributeName = (($reflect || $reflectURL) eq "1") ? $name : ($reflect || $reflectURL);
                                    my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
                                    $implIncludes{"${namespace}.h"} = 1;
                                    push(@implContent, "    imp->setAttribute(${namespace}::${contentAttributeName}Attr, $nativeValue");
                                } else {
                                    push(@implContent, "    imp->set$implSetterFunctionName($nativeValue");
                                }
                                push(@implContent, ", ec") if @{$attribute->setterExceptions};
                                push(@implContent, ");\n");
                                push(@implContent, "    setDOMException(exec, ec);\n") if @{$attribute->setterExceptions};
                                if (IsSVGTypeNeedingContextParameter($implClassName)) {
                                    push(@implContent, "    JSSVGContextCache::propagateSVGDOMChange(castedThisObj, imp->associatedAttributeName());\n");
                                }
                            }
                        }
                        
                        push(@implContent, "}\n\n");
                    }
                }
            }
        }
    }

    if (($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) && !$dataNode->extendedAttributes->{"CustomGetPropertyNames"}) {
        push(@implContent, "void ${className}::getOwnPropertyNames(ExecState* exec, PropertyNameArray& propertyNames, EnumerationMode mode)\n");
        push(@implContent, "{\n");
        if ($dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"HasCustomIndexGetter"} || $dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
            push(@implContent, "    for (unsigned i = 0; i < static_cast<${implClassName}*>(impl())->length(); ++i)\n");
            push(@implContent, "        propertyNames.add(Identifier::from(exec, i));\n");
        }
        push(@implContent, "     Base::getOwnPropertyNames(exec, propertyNames, mode);\n");
        push(@implContent, "}\n\n");
    }

    if (!($dataNode->extendedAttributes->{"OmitConstructor"} || $dataNode->extendedAttributes->{"CustomConstructor"})) {
        push(@implContent, "JSValue ${className}::getConstructor(ExecState* exec, JSGlobalObject* globalObject)\n{\n");
        push(@implContent, "    return getDOMConstructor<${className}Constructor>(exec, static_cast<JSDOMGlobalObject*>(globalObject));\n");
        push(@implContent, "}\n\n");
    }

    # Functions
    if ($numFunctions > 0) {
        foreach my $function (@{$dataNode->functions}) {
            AddIncludesForType($function->signature->type);

            my $functionName = $codeGenerator->WK_lcfirst($className) . "PrototypeFunction" . $codeGenerator->WK_ucfirst($function->signature->name);
            my $functionImplementationName = $function->signature->extendedAttributes->{"ImplementationFunction"} || $codeGenerator->WK_lcfirst($function->signature->name);

            push(@implContent, "JSValue JSC_HOST_CALL ${functionName}(ExecState* exec, JSObject*, JSValue thisValue, const ArgList& args)\n");
            push(@implContent, "{\n");
            push(@implContent, "    UNUSED_PARAM(args);\n");

            $implIncludes{"<runtime/Error.h>"} = 1;

            if ($interfaceName eq "DOMWindow") {
                push(@implContent, "    $className* castedThisObj = toJSDOMWindow(thisValue.toThisObject(exec));\n");
                push(@implContent, "    if (!castedThisObj)\n");
                push(@implContent, "        return throwError(exec, TypeError);\n");
            } elsif ($dataNode->extendedAttributes->{"IsWorkerContext"}) {
                push(@implContent, "    $className* castedThisObj = to${className}(thisValue.toThisObject(exec));\n");
                push(@implContent, "    if (!castedThisObj)\n");
                push(@implContent, "        return throwError(exec, TypeError);\n");
            } else {
                push(@implContent, "    if (!thisValue.inherits(&${className}::s_info))\n");
                push(@implContent, "        return throwError(exec, TypeError);\n");
                push(@implContent, "    $className* castedThisObj = static_cast<$className*>(asObject(thisValue));\n");
            }

            if ($dataNode->extendedAttributes->{"CheckDomainSecurity"} && 
                !$function->signature->extendedAttributes->{"DoNotCheckDomainSecurity"}) {
                push(@implContent, "    if (!castedThisObj->allowsAccessFrom(exec))\n");
                push(@implContent, "        return jsUndefined();\n");
            }

            # Special case for JSSVGLengthList / JSSVGTransformList / JSSVGPointList / JSSVGNumberList
            # Instead of having JSSVG*Custom.cpp implementations for the SVGList interface for all of these
            # classes, we directly forward the calls to JSSVGPODListCustom, which centralizes the otherwise
            # duplicated code for the JSSVG*List classes mentioned above.
            my $svgPODListType;
            if ($implClassName =~ /SVG.*List/) {
                $svgPODListType = $implClassName;
                $svgPODListType =~ s/List$//;
                $svgPODListType = "" unless $codeGenerator->IsPodType($svgPODListType);
                
                # Ignore additional (non-SVGList) SVGTransformList methods, that are not handled through JSSVGPODListCustom
                $svgPODListType = "" if $functionImplementationName =~ /createSVGTransformFromMatrix/;
                $svgPODListType = "" if $functionImplementationName =~ /consolidate/;
            }

            if ($function->signature->extendedAttributes->{"Custom"} || $function->signature->extendedAttributes->{"JSCCustom"}) {
                push(@implContent, "    return castedThisObj->" . $functionImplementationName . "(exec, args);\n");
            } elsif ($svgPODListType) {
                $implIncludes{"JS${svgPODListType}.h"} = 1;
                $implIncludes{"JSSVGPODListCustom.h"} = 1;
                push(@implContent, "    return JSSVGPODListCustom::$functionImplementationName<$className, " . GetNativeType($svgPODListType)
                                 . ">(castedThisObj, exec, args, to" . $svgPODListType . ");\n");
            } else {
                push(@implContent, "    $implType* imp = static_cast<$implType*>(castedThisObj->impl());\n");
                push(@implContent, "    $podType podImp(*imp);\n") if $podType;

                my $numParameters = @{$function->parameters};

                if ($function->signature->extendedAttributes->{"RequiresAllArguments"}) {
                        push(@implContent, "    if (args.size() < $numParameters)\n");
                        push(@implContent, "        return jsUndefined();\n");
                }

                if (@{$function->raisesExceptions}) {
                    push(@implContent, "    ExceptionCode ec = 0;\n");
                }

                if ($function->signature->extendedAttributes->{"SVGCheckSecurityDocument"}) {
                    push(@implContent, "    if (!checkNodeSecurity(exec, imp->getSVGDocument(" . (@{$function->raisesExceptions} ? "ec" : "") .")))\n");
                    push(@implContent, "        return jsUndefined();\n");
                    $implIncludes{"JSDOMBinding.h"} = 1;
                }

                my $paramIndex = 0;
                my $functionString = ($podType ? "podImp." : "imp->") . $functionImplementationName . "(";

                my $hasOptionalArguments = 0;

                if ($function->signature->extendedAttributes->{"CustomArgumentHandling"}) {
                    push(@implContent, "    ScriptCallStack callStack(exec, args, $numParameters);\n");
                    $implIncludes{"ScriptCallStack.h"} = 1;
                }

                foreach my $parameter (@{$function->parameters}) {
                    if (!$hasOptionalArguments && $parameter->extendedAttributes->{"Optional"}) {
                        push(@implContent, "\n    int argsCount = args.size();\n");
                        $hasOptionalArguments = 1;
                    }

                    if ($hasOptionalArguments) {
                        push(@implContent, "    if (argsCount < " . ($paramIndex + 1) . ") {\n");
                        GenerateImplementationFunctionCall($function, $functionString, $paramIndex, "    " x 2, $podType, $implClassName);
                        push(@implContent, "    }\n\n");
                    }

                    my $name = $parameter->name;
                    
                    if ($parameter->type eq "XPathNSResolver") {
                        push(@implContent, "    RefPtr<XPathNSResolver> customResolver;\n");
                        push(@implContent, "    XPathNSResolver* resolver = toXPathNSResolver(args.at($paramIndex));\n");
                        push(@implContent, "    if (!resolver) {\n");
                        push(@implContent, "        customResolver = JSCustomXPathNSResolver::create(exec, args.at($paramIndex));\n");
                        push(@implContent, "        if (exec->hadException())\n");
                        push(@implContent, "            return jsUndefined();\n");
                        push(@implContent, "        resolver = customResolver.get();\n");
                        push(@implContent, "    }\n");
                    } else {
                        push(@implContent, "    " . GetNativeTypeFromSignature($parameter) . " $name = " . JSValueToNative($parameter, "args.at($paramIndex)") . ";\n");

                        # If a parameter is "an index" and it's negative it should throw an INDEX_SIZE_ERR exception.
                        # But this needs to be done in the bindings, because the type is unsigned and the fact that it
                        # was negative will be lost by the time we're inside the DOM.
                        if ($parameter->extendedAttributes->{"IsIndex"}) {
                            $implIncludes{"ExceptionCode.h"} = 1;
                            push(@implContent, "    if ($name < 0) {\n");
                            push(@implContent, "        setDOMException(exec, INDEX_SIZE_ERR);\n");
                            push(@implContent, "        return jsUndefined();\n");
                            push(@implContent, "    }\n");
                        }
                    }

                    $functionString .= ", " if $paramIndex;

                    if ($parameter->type eq "NodeFilter") {
                        $functionString .= "$name.get()";
                    } else {
                        $functionString .= $name;
                    }
                    $paramIndex++;
                }

                if ($function->signature->extendedAttributes->{"NeedsUserGestureCheck"}) {
                    $functionString .= ", " if $paramIndex;
                    $functionString .= "processingUserGesture(exec)";
                    $paramIndex++;
                }

                push(@implContent, "\n");
                GenerateImplementationFunctionCall($function, $functionString, $paramIndex, "    ", $podType, $implClassName);
            }
            push(@implContent, "}\n\n");
        }
    }

    if ($numConstants > 0) {
        push(@implContent, "// Constant getters\n\n");

        foreach my $constant (@{$dataNode->constants}) {
            my $getter = "js" . $interfaceName . $codeGenerator->WK_ucfirst($constant->name);

            # FIXME: this casts into int to match our previous behavior which turned 0xFFFFFFFF in -1 for NodeFilter.SHOW_ALL
            push(@implContent, "JSValue ${getter}(ExecState* exec, const Identifier&, const PropertySlot&)\n");
            push(@implContent, "{\n");
            push(@implContent, "    return jsNumber(exec, static_cast<int>(" . $constant->value . "));\n");
            push(@implContent, "}\n\n");
        }
    }

    if ($dataNode->extendedAttributes->{"HasIndexGetter"}) {
        push(@implContent, "\nJSValue ${className}::indexGetter(ExecState* exec, const Identifier&, const PropertySlot& slot)\n");
        push(@implContent, "{\n");
        push(@implContent, "    ${className}* thisObj = static_cast<$className*>(asObject(slot.slotBase()));\n");
        if (IndexGetterReturnsStrings($implClassName)) {
            $implIncludes{"KURL.h"} = 1;
            push(@implContent, "    return jsStringOrNull(exec, thisObj->impl()->item(slot.index()));\n");
        } else {
            push(@implContent, "    return toJS(exec, thisObj->globalObject(), static_cast<$implClassName*>(thisObj->impl())->item(slot.index()));\n");
        }
        push(@implContent, "}\n");
        if ($interfaceName eq "HTMLCollection" or $interfaceName eq "HTMLAllCollection") {
            $implIncludes{"JSNode.h"} = 1;
            $implIncludes{"Node.h"} = 1;
        }
    }
    
    if ($dataNode->extendedAttributes->{"HasNumericIndexGetter"}) {
        push(@implContent, "\nJSValue ${className}::getByIndex(ExecState* exec, unsigned index)\n");
        push(@implContent, "{\n");
        push(@implContent, "    return jsNumber(exec, static_cast<$implClassName*>(impl())->item(index));\n");
        push(@implContent, "}\n");
        if ($interfaceName eq "HTMLCollection" or $interfaceName eq "HTMLAllCollection") {
            $implIncludes{"JSNode.h"} = 1;
            $implIncludes{"Node.h"} = 1;
        }
    }

    if ((!$hasParent or $dataNode->extendedAttributes->{"GenerateToJS"}) and !$dataNode->extendedAttributes->{"CustomToJS"}) {
        if ($podType) {
            push(@implContent, "JSC::JSValue toJS(JSC::ExecState* exec, JSDOMGlobalObject* globalObject, JSSVGPODTypeWrapper<$podType>* object, SVGElement* context)\n");
        } elsif (IsSVGTypeNeedingContextParameter($implClassName)) {
            push(@implContent, "JSC::JSValue toJS(JSC::ExecState* exec, JSDOMGlobalObject* globalObject, $implType* object, SVGElement* context)\n");
        } else {
            push(@implContent, "JSC::JSValue toJS(JSC::ExecState* exec, JSDOMGlobalObject* globalObject, $implType* object)\n");
        }
        push(@implContent, "{\n");
        if ($podType) {
            push(@implContent, "    return getDOMObjectWrapper<$className, JSSVGPODTypeWrapper<$podType> >(exec, globalObject, object, context);\n");
        } elsif (IsSVGTypeNeedingContextParameter($implClassName)) {
            push(@implContent, "    return getDOMObjectWrapper<$className>(exec, globalObject, object, context);\n");
        } else {
            push(@implContent, "    return getDOMObjectWrapper<$className>(exec, globalObject, object);\n");
        }
        push(@implContent, "}\n");
    }

    if ((!$hasParent or $dataNode->extendedAttributes->{"GenerateNativeConverter"}) and !$dataNode->extendedAttributes->{"CustomNativeConverter"}) {
        if ($podType) {
            push(@implContent, "$podType to${interfaceName}(JSC::JSValue value)\n");
        } else {
            push(@implContent, "$implClassName* to${interfaceName}(JSC::JSValue value)\n");
        }

        push(@implContent, "{\n");

        push(@implContent, "    return value.inherits(&${className}::s_info) ? " . ($podType ? "($podType) *" : "") . "static_cast<$className*>(asObject(value))->impl() : ");
        if ($podType and $podType ne "float") {
            push(@implContent, "$podType();\n}\n");
        } else {
            push(@implContent, "0;\n}\n");
        }
    }

    push(@implContent, "\n}\n");

    push(@implContent, "\n#endif // ${conditionalString}\n") if $conditional;
}

sub GenerateImplementationFunctionCall()
{
    my $function = shift;
    my $functionString = shift;
    my $paramIndex = shift;
    my $indent = shift;
    my $podType = shift;
    my $implClassName = shift;

    if ($function->signature->extendedAttributes->{"CustomArgumentHandling"}) {
        $functionString .= ", " if $paramIndex;
        ++$paramIndex;
        $functionString .= "&callStack";
    }

    if (@{$function->raisesExceptions}) {
        $functionString .= ", " if $paramIndex;
        $functionString .= "ec";
    }
    $functionString .= ")";

    if ($function->signature->type eq "void") {
        push(@implContent, $indent . "$functionString;\n");
        push(@implContent, $indent . "setDOMException(exec, ec);\n") if @{$function->raisesExceptions};
        push(@implContent, $indent . "imp->commitChange(podImp, castedThisObj);\n") if $podType;
        push(@implContent, $indent . "return jsUndefined();\n");
    } else {
        push(@implContent, "\n" . $indent . "JSC::JSValue result = " . NativeToJSValue($function->signature, 1, $implClassName, "", $functionString, "castedThisObj") . ";\n");
        push(@implContent, $indent . "setDOMException(exec, ec);\n") if @{$function->raisesExceptions};

        if ($podType and not $function->signature->extendedAttributes->{"Immutable"}) {
            # Immutable methods do not commit changes back to the instance, thus producing
            # a new instance rather than mutating existing one.
            push(@implContent, $indent . "imp->commitChange(podImp, castedThisObj);\n");
        }

        push(@implContent, $indent . "return result;\n");
    }
}

sub GetNativeTypeFromSignature
{
    my $signature = shift;
    my $type = $codeGenerator->StripModule($signature->type);

    if ($type eq "unsigned long" and $signature->extendedAttributes->{"IsIndex"}) {
        # Special-case index arguments because we need to check that they aren't < 0.
        return "int";
    }

    return GetNativeType($type);
}

my %nativeType = (
    "CompareHow" => "Range::CompareHow",
    "DOMString" => "const UString&",
    "NodeFilter" => "RefPtr<NodeFilter>",
    "SVGAngle" => "SVGAngle",
    "SVGLength" => "SVGLength",
    "SVGMatrix" => "AffineTransform",
    "SVGNumber" => "float",
    "SVGPaintType" => "SVGPaint::SVGPaintType",
    "SVGPreserveAspectRatio" => "SVGPreserveAspectRatio",
    "SVGPoint" => "FloatPoint",
    "SVGRect" => "FloatRect",
    "SVGTransform" => "SVGTransform",
    "boolean" => "bool",
    "double" => "double",
    "float" => "float",
    "long" => "int",
    "unsigned long" => "unsigned",
    "unsigned short" => "unsigned short",
    "long long" => "long long",
    "unsigned long long" => "unsigned long long",
);

sub GetNativeType
{
    my $type = shift;

    return $nativeType{$type} if exists $nativeType{$type};

    # For all other types, the native type is a pointer with same type name as the IDL type.
    return "${type}*";
}

sub JSValueToNative
{
    my $signature = shift;
    my $value = shift;

    my $type = $codeGenerator->StripModule($signature->type);

    return "$value.toBoolean(exec)" if $type eq "boolean";
    return "$value.toNumber(exec)" if $type eq "double";
    return "$value.toFloat(exec)" if $type eq "float" or $type eq "SVGNumber";
    return "$value.toInt32(exec)" if $type eq "unsigned long" or $type eq "long" or $type eq "unsigned short";
    return "static_cast<$type>($value.toInteger(exec))" if $type eq "long long" or $type eq "unsigned long long";

    return "valueToDate(exec, $value)" if $type eq "Date";
    return "static_cast<Range::CompareHow>($value.toInt32(exec))" if $type eq "CompareHow";
    return "static_cast<SVGPaint::SVGPaintType>($value.toInt32(exec))" if $type eq "SVGPaintType";

    if ($type eq "DOMString") {
        return "valueToStringWithNullCheck(exec, $value)" if $signature->extendedAttributes->{"ConvertNullToNullString"};
        return "valueToStringWithUndefinedOrNullCheck(exec, $value)" if $signature->extendedAttributes->{"ConvertUndefinedOrNullToNullString"};
        return "$value.toString(exec)";
    }

    if ($type eq "SerializedScriptValue" or $type eq "any") {
        $implIncludes{"SerializedScriptValue.h"} = 1;
        return "SerializedScriptValue::create(exec, $value)";
    }

    $implIncludes{"FloatPoint.h"} = 1 if $type eq "SVGPoint";
    $implIncludes{"FloatRect.h"} = 1 if $type eq "SVGRect";
    $implIncludes{"HTMLOptionElement.h"} = 1 if $type eq "HTMLOptionElement";
    $implIncludes{"JSCustomVoidCallback.h"} = 1 if $type eq "VoidCallback";
    $implIncludes{"Event.h"} = 1 if $type eq "Event";

    # Default, assume autogenerated type conversion routines
    $implIncludes{"JS$type.h"} = 1;
    return "to$type($value)";
}

sub NativeToJSValue
{
    my $signature = shift;
    my $inFunctionCall = shift;
    my $implClassName = shift;
    my $implClassNameForValueConversion = shift;
    my $value = shift;
    my $thisValue = shift;

    my $type = $codeGenerator->StripModule($signature->type);

    return "jsBoolean($value)" if $type eq "boolean";

    # Need to check Date type before IsPrimitiveType().
    if ($type eq "Date") {
        return "jsDateOrNull(exec, $value)";
    }
    if ($codeGenerator->IsPrimitiveType($type) or $type eq "SVGPaintType" or $type eq "DOMTimeStamp") {
        $implIncludes{"<runtime/JSNumberCell.h>"} = 1;
        return "jsNumber(exec, $value)";
    }

    if ($codeGenerator->IsStringType($type)) {
        $implIncludes{"KURL.h"} = 1;
        my $conv = $signature->extendedAttributes->{"ConvertNullStringTo"};
        if (defined $conv) {
            return "jsStringOrNull(exec, $value)" if $conv eq "Null";
            return "jsStringOrUndefined(exec, $value)" if $conv eq "Undefined";
            return "jsStringOrFalse(exec, $value)" if $conv eq "False";

            die "Unknown value for ConvertNullStringTo extended attribute";
        }
        $implIncludes{"<runtime/JSString.h>"} = 1;
        return "jsString(exec, $value)";
    }
    
    my $globalObject = "$thisValue->globalObject()";
    if ($codeGenerator->IsPodType($type)) {
        $implIncludes{"JS$type.h"} = 1;

        my $nativeType = GetNativeType($type);

        my $getter = $value;
        $getter =~ s/imp->//;
        $getter =~ s/\(\)//;

        my $setter = "set" . $codeGenerator->WK_ucfirst($getter);

        # Function calls will never return 'modifyable' POD types (ie. SVGRect getBBox()) - no need to keep track changes to the returned SVGRect
        if ($inFunctionCall eq 0
            and not $codeGenerator->IsSVGAnimatedType($implClassName)
            and $codeGenerator->IsPodTypeWithWriteableProperties($type)
            and not defined $signature->extendedAttributes->{"Immutable"}) {
            if ($codeGenerator->IsPodType($implClassName)) {
                return "toJS(exec, $globalObject, JSSVGStaticPODTypeWrapperWithPODTypeParent<$nativeType, $implClassName>::create($value, $thisValue->impl()).get(), JSSVGContextCache::svgContextForDOMObject(castedThis))";
            } else {
                return "toJS(exec, $globalObject, JSSVGStaticPODTypeWrapperWithParent<$nativeType, $implClassName>::create(imp, &${implClassName}::$getter, &${implClassName}::$setter).get(), imp)";
            }
        }

        if ($implClassNameForValueConversion eq "") {
            return "toJS(exec, $globalObject, JSSVGStaticPODTypeWrapper<$nativeType>::create($value).get(), 0 /* no context on purpose */)";
        } else {
            return "toJS(exec, $globalObject, JSSVGDynamicPODTypeWrapperCache<$nativeType, $implClassNameForValueConversion>::lookupOrCreateWrapper(imp, &${implClassNameForValueConversion}::$getter, &${implClassNameForValueConversion}::$setter).get(), JSSVGContextCache::svgContextForDOMObject(castedThis));"
        }
    }

    if ($codeGenerator->IsSVGAnimatedType($type)) {
        # Some SVGFE*Element.idl use 'operator' as attribute name, rewrite as '_operator' to avoid clashes with C/C++
        $value =~ s/operator\(\)/_operator\(\)/ if ($value =~ /operator/);
        $value =~ s/\(\)//;
        $value .= "Animated()";
    }

    if ($type eq "CSSStyleDeclaration") {
        $implIncludes{"CSSMutableStyleDeclaration.h"} = 1;
    }

    if ($type eq "NodeList") {
        $implIncludes{"NameNodeList.h"} = 1;
    }

    if ($type eq "DOMObject") {
        $implIncludes{"JSCanvasRenderingContext2D.h"} = 1;
    } elsif ($type =~ /SVGPathSeg/) {
        $implIncludes{"JS$type.h"} = 1;
        $joinedName = $type;
        $joinedName =~ s/Abs|Rel//;
        $implIncludes{"$joinedName.h"} = 1;
    } elsif ($type eq "SerializedScriptValue" or $type eq "any") {
        $implIncludes{"SerializedScriptValue.h"} = 1;
        return "$value ? $value->deserialize(exec, castedThis->globalObject()) : jsNull()";
    } else {
        # Default, include header with same name.
        $implIncludes{"JS$type.h"} = 1;
        $implIncludes{"$type.h"} = 1;
    }

    return $value if $codeGenerator->IsSVGAnimatedType($type);

    if (IsSVGTypeNeedingContextParameter($type)) {
        my $contextPtr = IsSVGTypeNeedingContextParameter($implClassName) ? "JSSVGContextCache::svgContextForDOMObject(castedThis)" : "imp";
        return "toJS(exec, $globalObject, WTF::getPtr($value), $contextPtr)";
    }

    if ($signature->extendedAttributes->{"ReturnsNew"}) {        
        return "toJSNewlyCreated(exec, $globalObject, WTF::getPtr($value))";
    }

    return "toJS(exec, $globalObject, WTF::getPtr($value))";
}

sub ceilingToPowerOf2
{
    my ($size) = @_;

    my $powerOf2 = 1;
    while ($size > $powerOf2) {
        $powerOf2 <<= 1;
    }

    return $powerOf2;
}

# Internal Helper
sub GenerateHashTable
{
    my $object = shift;

    my $name = shift;
    my $size = shift;
    my $keys = shift;
    my $specials = shift;
    my $value1 = shift;
    my $value2 = shift;
    my $conditionals = shift;

    # Generate size data for two hash tables
    # - The 'perfect' size makes a table large enough for perfect hashing
    # - The 'compact' size uses the legacy table format for smaller table sizes

    # Perfect size
    my @hashes = ();
    foreach my $key (@{$keys}) {
        push @hashes, $object->GenerateHashValue($key);
    }

    # Compact size
    my @table = ();
    my @links = ();

    my $compactSize = ceilingToPowerOf2($size * 2);

    my $maxDepth = 0;
    my $collisions = 0;
    my $numEntries = $compactSize;

    my $i = 0;
    foreach (@{$keys}) {
        my $depth = 0;
        my $h = $object->GenerateHashValue($_) % $numEntries;

        while (defined($table[$h])) {
            if (defined($links[$h])) {
                $h = $links[$h];
                $depth++;
            } else {
                $collisions++;
                $links[$h] = $compactSize;
                $h = $compactSize;
                $compactSize++;
            }
        }

        $table[$h] = $i;

        $i++;
        $maxDepth = $depth if ($depth > $maxDepth);
    }

    # Collect hashtable information
    my $perfectSize;
tableSizeLoop:
    for ($perfectSize = ceilingToPowerOf2(scalar @{$keys}); ; $perfectSize += $perfectSize) {
        my @table = ();
        my $i = 0;
        foreach my $hash (@hashes) {
            my $h = $hash % $perfectSize;
            next tableSizeLoop if defined $table[$h];
            $table[$h] = $i++;
        }
        last;
    }

    # Start outputing the hashtables
    my $nameEntries = "${name}Values";
    $nameEntries =~ s/:/_/g;

    if (($name =~ /Prototype/) or ($name =~ /Constructor/)) {
        my $type = $name;
        my $implClass;

        if ($name =~ /Prototype/) {
            $type =~ s/Prototype.*//;
            $implClass = $type; $implClass =~ s/Wrapper$//;
            push(@implContent, "/* Hash table for prototype */\n");
        } else {
            $type =~ s/Constructor.*//;
            $implClass = $type; $implClass =~ s/Constructor$//;
            push(@implContent, "/* Hash table for constructor */\n");
        }
    } else {
        push(@implContent, "/* Hash table */\n");
    }

    # Dump the hash table
    my $count = scalar @{$keys} + 1;
    push(@implContent, "\nstatic const HashTableValue $nameEntries\[$count\] =\n\{\n");
    $i = 0;
    foreach my $key (@{$keys}) {
        my $conditional;

        if ($conditionals) {
            $conditional = $conditionals->{$key};
        }
        if ($conditional) {
            my $conditionalString = "ENABLE(" . join(") && ENABLE(", split(/&/, $conditional)) . ")";
            push(@implContent, "#if ${conditionalString}\n");
        }
        push(@implContent, "    { \"$key\", @$specials[$i], (intptr_t)@$value1[$i], (intptr_t)@$value2[$i] },\n");
        if ($conditional) {
            push(@implContent, "#endif\n");
        }
        ++$i;
    }
    push(@implContent, "    { 0, 0, 0, 0 }\n");
    push(@implContent, "};\n\n");
    my $perfectSizeMask = $perfectSize - 1;
    my $compactSizeMask = $numEntries - 1;
    push(@implContent, "static JSC_CONST_HASHTABLE HashTable $name =\n");
    push(@implContent, "#if ENABLE(PERFECT_HASH_SIZE)\n");
    push(@implContent, "    { $perfectSizeMask, $nameEntries, 0 };\n");
    push(@implContent, "#else\n");
    push(@implContent, "    { $compactSize, $compactSizeMask, $nameEntries, 0 };\n");
    push(@implContent, "#endif\n\n");
}

# Internal helper
sub GenerateHashValue
{
    my $object = shift;

    @chars = split(/ */, $_[0]);

    # This hash is designed to work on 16-bit chunks at a time. But since the normal case
    # (above) is to hash UTF-16 characters, we just treat the 8-bit chars as if they
    # were 16-bit chunks, which should give matching results

    my $EXP2_32 = 4294967296;

    my $hash = 0x9e3779b9;
    my $l    = scalar @chars; #I wish this was in Ruby --- Maks
    my $rem  = $l & 1;
    $l = $l >> 1;

    my $s = 0;

    # Main loop
    for (; $l > 0; $l--) {
        $hash   += ord($chars[$s]);
        my $tmp = leftShift(ord($chars[$s+1]), 11) ^ $hash;
        $hash   = (leftShift($hash, 16)% $EXP2_32) ^ $tmp;
        $s += 2;
        $hash += $hash >> 11;
        $hash %= $EXP2_32;
    }

    # Handle end case
    if ($rem != 0) {
        $hash += ord($chars[$s]);
        $hash ^= (leftShift($hash, 11)% $EXP2_32);
        $hash += $hash >> 17;
    }

    # Force "avalanching" of final 127 bits
    $hash ^= leftShift($hash, 3);
    $hash += ($hash >> 5);
    $hash = ($hash% $EXP2_32);
    $hash ^= (leftShift($hash, 2)% $EXP2_32);
    $hash += ($hash >> 15);
    $hash = $hash% $EXP2_32;
    $hash ^= (leftShift($hash, 10)% $EXP2_32);

    # this avoids ever returning a hash code of 0, since that is used to
    # signal "hash not computed yet", using a value that is likely to be
    # effectively the same as 0 when the low bits are masked
    $hash = 0x80000000 if ($hash == 0);

    return $hash;
}

# Internal helper
sub WriteData
{
    if (defined($IMPL)) {
        # Write content to file.
        print $IMPL @implContentHeader;

        my @includes = ();
        foreach my $include (keys %implIncludes) {
            my $checkType = $include;
            $checkType =~ s/\.h//;
            next if $codeGenerator->IsSVGAnimatedType($checkType);

            $include = "\"$include\"" unless $include =~ /^["<]/; # "
            push @includes, $include;
        }
        foreach my $include (sort @includes) {
            print $IMPL "#include $include\n";
        }

        print $IMPL @implContent;
        close($IMPL);
        undef($IMPL);

        @implContentHeader = ();
        @implContent = ();
        %implIncludes = ();
    }

    if (defined($HEADER)) {
        # Write content to file.
        print $HEADER @headerContentHeader;

        my @includes = ();
        foreach my $include (keys %headerIncludes) {
            $include = "\"$include\"" unless $include =~ /^["<]/; # "
            push @includes, $include;
        }
        foreach my $include (sort @includes) {
            print $HEADER "#include $include\n";
        }

        print $HEADER @headerContent;
        close($HEADER);
        undef($HEADER);

        @headerContentHeader = ();
        @headerContent = ();
        %headerIncludes = ();
    }

    if (defined($DEPS)) {
        # Write dependency file.
        print $DEPS @depsContent;
        close($DEPS);
        undef($DEPS);

        @depsContent = ();
    }
}

sub constructorFor
{
    my $className = shift;
    my $protoClassName = shift;
    my $interfaceName = shift;
    my $visibleClassName = shift;
    my $canConstruct = shift;
    my $constructorClassName = "${className}Constructor";

my $implContent = << "EOF";
class ${constructorClassName} : public DOMConstructorObject {
public:
    ${constructorClassName}(ExecState* exec, JSDOMGlobalObject* globalObject)
        : DOMConstructorObject(${constructorClassName}::createStructure(globalObject->objectPrototype()), globalObject)
    {
        putDirect(exec->propertyNames().prototype, ${protoClassName}::self(exec, globalObject), None);
    }
    virtual bool getOwnPropertySlot(ExecState*, const Identifier&, PropertySlot&);
    virtual bool getOwnPropertyDescriptor(ExecState*, const Identifier&, PropertyDescriptor&);
    virtual const ClassInfo* classInfo() const { return &s_info; }
    static const ClassInfo s_info;

    static PassRefPtr<Structure> createStructure(JSValue proto) 
    { 
        return Structure::create(proto, TypeInfo(ObjectType, StructureFlags), AnonymousSlotCount); 
    }
    
protected:
    static const unsigned StructureFlags = OverridesGetOwnPropertySlot | ImplementsHasInstance | DOMConstructorObject::StructureFlags;
EOF

    if ($canConstruct) {
$implContent .= << "EOF";
    static JSObject* construct${interfaceName}(ExecState* exec, JSObject* constructor, const ArgList&)
    {
        return asObject(toJS(exec, static_cast<${constructorClassName}*>(constructor)->globalObject(), ${interfaceName}::create()));
    }
    virtual ConstructType getConstructData(ConstructData& constructData)
    {
        constructData.native.function = construct${interfaceName};
        return ConstructTypeHost;
    }
EOF
    }

$implContent .= << "EOF";
};

const ClassInfo ${constructorClassName}::s_info = { "${visibleClassName}Constructor", 0, &${constructorClassName}Table, 0 };

bool ${constructorClassName}::getOwnPropertySlot(ExecState* exec, const Identifier& propertyName, PropertySlot& slot)
{
    return getStaticValueSlot<${constructorClassName}, DOMObject>(exec, &${constructorClassName}Table, this, propertyName, slot);
}

bool ${constructorClassName}::getOwnPropertyDescriptor(ExecState* exec, const Identifier& propertyName, PropertyDescriptor& descriptor)
{
    return getStaticValueDescriptor<${constructorClassName}, DOMObject>(exec, &${constructorClassName}Table, this, propertyName, descriptor);
}

EOF

    $implJSCInclude{"JSNumberCell.h"} = 1; # FIXME: What is this for?

    return $implContent;
}

1;
