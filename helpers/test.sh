#!/bin/sh
clear;

`dfx cache show`/moc -r --hide-warnings `vessel sources 2>>/dev/null` test/test.mo 2>> tmp.err.log >> tmp.output.log
`dfx cache show`/moc -r --hide-warnings `vessel sources 2>>/dev/null` test/withjazz.mo 2>> tmp.err.log >> tmp.output.log


cat tmp.output.log
cat tmp.err.log
rm -f tmp.output.log
rm -f tmp.err.log
