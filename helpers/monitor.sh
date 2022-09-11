#!/bin/sh
./helpers/test.sh 
fswatch -o src/ test | xargs -n1 -I{} ./helpers/test.sh 
