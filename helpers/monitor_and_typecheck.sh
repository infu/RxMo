#!/bin/sh
./helpers/local_typecheck.sh 
fswatch -o src/ test | xargs -n1 -I{} ./helpers/local_typecheck.sh 
