Posted as: https://github.com/intersystems-community/python-bugreports/issues/25

A finite Python float outside about 1e-128 to 9.2e145 cannot be returned to ObjectScript, even as %Double — caller gets <OBJECT DISPATCH> value out of range

A [Language = python] ClassMethod declared to return %Double that returns an ordinary, finite Python float fails at the method-call boundary with <OBJECT DISPATCH> value out of range when the value is larger than about 9.2e145 or smaller than about 1e-128 in magnitude. This includes the largest double (1.7976931348623157e308) and the smallest subnormal (5e-324). Both sides can hold these values: ObjectScript has $DOUBLE ($double("1e308") works), and passing $double("1e308") into a %Double argument arrives in Python as float 1e+308. Only the Python-to-ObjectScript direction fails. The returned float seems to be converted to an ObjectScript decimal rather than to $DOUBLE, whatever the declared return type: a returned float has $ListBuild type 6, the same as a decimal, while $double(0.1) has type 9. The limits above are where the decimal range ends. float('inf') is returned fine, as INF (type 8). Issue #13 shows the same decimal conversion from the precision side; this report is about values that cannot cross at all.

Reproduction:

Class PyBug.Probe4
{
ClassMethod FromText(text As %String) As %Double [ Language = python ]
{
    return float(text)
}
}

for t="9.2e145","9.3e145","1e-128","1e-129","1.7976931348623157e308","5e-324","inf" { try { write t," -> ",##class(PyBug.Probe4).FromText(t),! } catch e { write t," -> ",e.Name," ",e.Data,! } }
write $double("1e308"),!

Output (the case name is printed twice on the failing lines because the write had already started when the call threw):

9.2e145 -> 92000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9.3e145 -> 9.3e145 -> <OBJECT DISPATCH> value out of range
1e-128 -> .00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001
1e-129 -> 1e-129 -> <OBJECT DISPATCH> value out of range
1.7976931348623157e308 -> 1.7976931348623157e308 -> <OBJECT DISPATCH> value out of range
5e-324 -> 5e-324 -> <OBJECT DISPATCH> value out of range
inf -> INF
100000000000000001090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

The same error comes from the return type %Float, from a method with no declared return type, and from a direct call:

write ##class(%SYS.Python).Import("builtins").float("1e308")
// <OBJECT DISPATCH> value out of range

The type of what comes back:

for t="0.1","9.2e145","inf" { set r=##class(PyBug.Probe4).FromText(t) write t," -> $ListBuild type ",$ascii($listbuild(r),2),! }
write "$double(0.1) -> $ListBuild type ",$ascii($listbuild($double("0.1")),2),!
// 0.1 -> $ListBuild type 6
// 9.2e145 -> $ListBuild type 6
// inf -> $ListBuild type 8
// $double(0.1) -> $ListBuild type 9

Expected: every finite IEEE double produced by Python arrives in ObjectScript, at least when the method is declared %Double (as a $DOUBLE, the way float('inf') already comes back as INF), or, if that is not possible, a documented limit. Not a runtime error for valid finite values that ObjectScript itself can represent. Workaround for now: return repr(x) as %String and apply $double() in ObjectScript.

Environment:
IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2026.3.0AI (Build 154U) Thu Sep 24 2026 10:04:49 EDT
Python version 3.12.3 (main, Aug 31 2026, 10:18:26) [GCC 13.3.0] — Embedded Python, executing inside IRIS via a Language = python class method (container irishealth-community:2026.3.0AI.154.0). Not tested on ARM64.
