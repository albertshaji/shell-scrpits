#!/bin/bash

while true
do
    w=$(cat /usr/share/dict/british-english | dmenu)
    [ -n "$w" ] &&
    grep -qw "$w" /usr/share/dict/british-english &&
    {
        echo "$w" >> $WORDS
        sdcv -n -u 'WordNet' -u 'Moby Thesaurus II' $w |
        dmenu -l 20
    } || break
done
