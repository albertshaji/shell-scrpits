#!/bin/bash

if [ -e .ct ]
then
    redshift -x >/dev/null
    rm .ct
else
    redshift -P -O 5000 >/dev/null
    touch .ct
fi
