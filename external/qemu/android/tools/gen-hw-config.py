#!/usr/bin/env python
import  sys, os, string, re

# location of source file, relative to current program directory
relativeSourcePath = "../avd/hardware-properties.ini"

# location of target file, relative to current program directory
relativeTargetPath = "../avd/hw-config-defs.h"

def quoteStringForC(str):
    """quote a string so it can be used in C"""
    return '\\"'.join('"'+p+'"' for p in str.split('"'))

# a dictionary that maps item types as they appear in the .ini
# file into macro names in the generated C header
#
typesToMacros = { 
    'integer': 'HWCFG_INT',
    'string': 'HWCFG_STRING',
    'boolean': 'HWCFG_BOOL',
    'diskSize': 'HWCFG_DISKSIZE',
    'double': 'HWCFG_DOUBLE'
    }

# the list of macro names
macroNames = typesToMacros.values()

# target program header
targetHeader = """\
"""

# locate source and target
programDir = os.path.dirname(sys.argv[0])
if len(sys.argv) != 3:
    print "Usage: %s source target\n" % os.path.basename(sys.argv[0])
    sys.exit(1)

sourceFile = sys.argv[1]
targetFile = sys.argv[2]

# parse the source file and record items
# I would love to use Python's ConfigParser, but it doesn't
# support files without sections, or multiply defined items
#
items    = []
lastItem = None

class Item:
    def __init__(self,name):
        self.name     = name
        self.type     = type
        self.default  = None
        self.abstract = ""
        self.description = ""

    def add(self,key,val):
        if key == 'type':
            self.type = val
        elif key == 'default':
            self.default = val
        elif key == 'abstract':
            self.abstract = val
        elif key == 'description':
            self.description = val

for line in open(sourceFile):
    line = line.strip()
    # ignore empty lines and comments
    if len(line) == 0 or line[0] in ";#":
        continue
    key, value = line.split('=')

    key   = key.strip()
    value = value.strip()

    if key == 'name':
        if lastItem: items.append(lastItem)
        lastItem = Item(value)
    else:
        lastItem.add(key, value)

if lastItem:
    items.append(lastItem)

if targetFile == '--':
    out = sys.stdout
else:
    out = open(targetFile,"wb")

out.write(targetHeader)

# write guards to prevent bad compiles
for m in macroNames:
    out.write("""\
#ifndef %(macro)s
#error  %(macro)s not defined
#endif
""" % { 'macro':m })
out.write("\n")

for item in items:
    if item.type == None:
        sys.stderr.write("ignoring config item with no type '%s'\n" % item.name)
        continue

    if not typesToMacros.has_key(item.type):
        sys.stderr.write("ignoring config item with unknown type '%s': '%s'\n" % \
                (item.type, item.name))
        continue

    if item.default == None:
        sys.stderr.write("ignoring config item with no default '%s' */" % item.name)
        continue

    # convert dots into underscores
    varMacro   = typesToMacros[item.type]
    varNameStr = quoteStringForC(item.name)
    varName    = item.name.replace(".","_")
    varDefault = item.default
    varAbstract = quoteStringForC(item.abstract)
    varDesc     = quoteStringForC(item.description)

    if item.type in [ 'string', 'boolean', 'diskSize' ]:
        # quote default value for strings
        varDefault = quoteStringForC(varDefault)

    out.write("%s(\n  %s,\n  %s,\n  %s,\n  %s,\n  %s)\n\n" % \
            (varMacro,varName,varNameStr,varDefault,varAbstract,varDesc))


for m in macroNames:
    out.write("#undef %s\n" % m)

out.write("/* end of auto-generated file */\n")
out.close()
