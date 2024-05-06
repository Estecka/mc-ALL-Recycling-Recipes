#!/bin/bash

./datagen.sh --no-clobber \
&& echo >&2 "Packing..." \
&& ./pack.sh >/dev/null "ALL-Recycling-Recipes.zip" \
;
