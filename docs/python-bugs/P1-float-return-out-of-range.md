# P1: A finite Python float outside about 1e-128 to 9.2e145 cannot be returned to ObjectScript, even as %Double

Reported as: https://github.com/intersystems-community/python-bugreports/issues/25

- **Build:** IRIS for Health Community 2026.3.0AI.154.0 (container `irishealth-community:2026.3.0AI.154.0`, "IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2026.3.0AI (Build 154U)"), Embedded Python 3.12.3
- **Component:** Embedded Python, conversion of a Python `float` to an ObjectScript value (method return value and `%SYS.Python` calls)
- **Not tested:** ARM64, and other IRIS versions
- **Related:** [python-bugreports #13](https://github.com/intersystems-community/python-bugreports/issues/13) (open since 2023) shows the same root cause from the precision side: a Python `float` becomes an ObjectScript decimal (`$ListBuild` type 0x06), not a `$DOUBLE`. It does not cover the error below.

## Steps

1. In any namespace, compile:

   ```objectscript
   Class PyBug.Probe4
   {

   ClassMethod FromText(text As %String) As %Double [ Language = python ]
   {
       return float(text)
   }

   }
   ```

2. In an IRIS terminal:

   ```objectscript
   for t="9.2e145","9.3e145","1e-128","1e-129","1.7976931348623157e308","5e-324","inf" { try { write t," -> ",##class(PyBug.Probe4).FromText(t),! } catch e { write t," -> ",e.Name," ",e.Data,! } }
   write $double("1e308"),!
   ```

   The same happens with the return type `%Float`, with no declared return type, and when calling `##class(%SYS.Python).Import("builtins").float("1e308")` from ObjectScript.

## Expected

Every finite IEEE double that Python produces arrives in ObjectScript, at least when the method is declared `%Double`: ObjectScript can hold these values as `$DOUBLE` (`$double("1e308")` works). `float("inf")` and `float("nan")` are returned as `INF` and `NAN` (the returned `INF` has `$ListBuild` type 8).

## Actual

- `9.2e145` and `1e-128` come back as ObjectScript decimals (`$ListBuild` type 0x06).
- `9.3e145`, `-9.3e145`, `1e-129`, `1e-200`, `5e-324` and `1.7976931348623157e308` (the largest double) throw `<OBJECT DISPATCH> value out of range` in the caller.
- The declared return type `%Double` makes no difference; the value is converted to a decimal and fails where the ObjectScript decimal range ends.
- In the other direction there is no problem: `$double("1e308")` passed to a `%Double` argument arrives in Python as `float: 1e+308`.

So a Python method whose result is a very large or very small number (a likelihood, a product of probabilities, a physical constant) fails at the boundary even though both sides can represent the value. Workaround: return the number as text (`repr(x)`) and apply `$double()` in ObjectScript.

Reproduced on 2026-10-29 on build 154 (x86-64 container).
