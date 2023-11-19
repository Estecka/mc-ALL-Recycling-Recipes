#!/bin/bash

if [ -z $1 ]
then
	file=pack.zip
else
	file="$1";
fi

rm "$file";
zip "$file" -r \
	data/ \
	pack.mcmeta \
	pack.png \
	;
