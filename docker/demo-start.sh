#!/usr/bin/env bash
# Runs after IRIS starts (iris-main -a, see start-iris.sh): applies the MYOWN_DEMO_* settings of
# the environment (demo account, synthetic targets, reset task). IRIS reads the demo password
# from the environment itself; it is never printed or written by this script.
iris session IRIS -U MYOWN <<'SCRIPT'
set sc=##class(MyOwn.Demo.Setup).Apply() if 'sc write "MyOwn demo setup failed: ",$System.Status.GetErrorText(sc),!
halt
SCRIPT
