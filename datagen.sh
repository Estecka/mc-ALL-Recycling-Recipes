#!/bin/bash

#******************************************************************************#
# # Config                                                                     #
#******************************************************************************#

set -o pipefail;

dry_run() { return 1; }
clean() { return 1; }
no_clobber() { return 1; }

while [[ $1 =~ --[a-zA-Z-]+ ]]
do
	case $1 in
	--dry)
	dry_run(){ return 0; }
	;;
	--no-clobber)
	no_clobber(){ return 0; }
	;;
	--clean)
	clean(){ return 0; }
	;;
	*)
	echo >&2 "[warn] Unsupported option: $1";
	;;
	esac
	shift;
done;


#******************************************************************************#
# # Recipes                                                                    #
#******************************************************************************#

function write_file(){
	if [ -f "$1" ]
	then
		echo >&2 "File exists: $1";
		no_clobber && return 1;
	fi;

	echo >>"$FILE_CACHE" $1;
	envsubst >"$1";
}

function cut(){
	export OUTPUT="$NAMESPACE:$OUT";
	export  INPUT="$NAMESPACE:$IN";
	write_file <./templates/cut.json "./data/$NAMESPACE/recipes/${OUT}_from_${IN}_stonecutting.json";
}

function uncraft(){
	export OUTPUT="$NAMESPACE:$OUT"
	export  INPUT="$NAMESPACE:$IN"
	write_file <"./templates/craft_$COST.json" "./data/$NAMESPACE/recipes/uncraft/${IN}_$COST.json";
}

function recipes(){
	case $1 in
	# Bark to Logs
	%s_wood|%s_hyphae)
	IN=$VAR OUT=$RAW COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft;
	;;
	# Stripping
	stripped_*)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	;;

	# Planks to Mosaic
	%s_mosaic_slab)
	IN=$RAW OUT=$VAR COUNT=2 cut;
	;;
	%s_mosaic_stairs)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	;;

	# Copper
	## Scrapping
	waxed_*|exposed_%s|weathered_%s|oxidized_%s)
	IN=$VAR OUT=$RAW COUNT=1 cut;
	;;
	## Uncutting
	%scut_copper)
	IN=$VAR OUT=$RAW COUNT=1 COST="4" uncraft;
	;;

	# Simple Shaping/Unshaping
	cobble*)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	;;
	%s_brick_fence)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=3 COST="4" uncraft;
	;;
	%s_slab|%s_bars)
	IN=$RAW OUT=$VAR COUNT=2 cut;
	IN=$VAR OUT=$RAW COUNT=1 COST="2h" uncraft;
	IN=$VAR OUT=$RAW COUNT=2 COST="4" uncraft;
	;;
	*) ## Default 1:1 recipes
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft;
	;;
	esac
}


#******************************************************************************#
# # Materials                                                                  #
#******************************************************************************#

function item_postprocess(){
	local item=$(cat)
	if [[ $item = ?(waxed_)'${copper_block}' ]]
	then copper_block='copper_block';
	else copper_block='copper';
	fi;
	export copper_block
	envsubst <<<"$item";
}

function generate(){
	export NAMESPACE=$1;
	local radical=$2;
	local raw_form=$3;
	shift 3;

	RAW=$(printf "$raw_form" "$radical" | item_postprocess) || return;
	export RAW;
	export GROUP="$NAMESPACE:$RAW";

	while [[ $# -gt 0 ]]
	do
		local var_form=$1;
		VAR=$(printf "$var_form" "$radical" | item_postprocess) || return;
		export VAR;
		shift;
		echo >&1 "$NAMESPACE:$RAW <-> $NAMESPACE:$VAR";
		dry_run || recipes "$var_form" || return;
	done;
}

function recursive_envsubst() {
	local key=$1;
	if [[ $# -gt 0 ]]
	then
		shift;
		if ! jq <./variables.json -cbr -e 'has($key)' --arg key "$key" >/dev/null
		then 
			cat;
		else
			local input=$(cat);

			jq <./variables.json -cbr '.[$key][]' --arg key "$key" \
			| while read -r value
			do
				export $key=$value;
				envsubst "\$$key" <<<$input | tr -d '\r'
			done;
		fi | recursive_envsubst "$@";
	else
		cat
	fi
}
function material_preprocessor(){
	local vars=$(envsubst -v "$1");
	recursive_envsubst $vars <<<"$1";
}

function parse(){
	jq <$1 -cb '
		to_entries[] 
		| foreach .value[] as $value ({key}; {key, raw:$value.raw, vars:$value.variants}; foreach $value.materials[] as $mat (.; .mat=$mat; .))
		| [.key, .mat, .raw//"%s", .vars[]]
	' | while read -r entry
	do
		echo "$entry" | jq -cbr '.[]' | {
			vars=();
			read -r nsp;
			read -r mat;
			read -r raw;
			while read -r v;
			do
				while read -r pv
				do vars+=("$pv");
				done < <(material_preprocessor "$v");
			done;

			dry_run || mkdir -p "./data/$nsp/recipes/uncraft";

			material_preprocessor "$mat"$'\n'"$raw" | while read -r pmat && read -r praw
			do
				generate "$nsp" "$pmat" "$praw" "${vars[@]}" || return;
			done;
		} || return;
	done;
}


#******************************************************************************#
# # Main                                                                       #
#******************************************************************************#

materials=./materials/*.json;
if [[ $# -gt 0 ]]
then materials=$@;
fi;

if clean
then
	if dry_run
	then
		find ./data/* -type f;
	else
		rm -r ./data/*;
		rm ./materials/*.json.cache;
	fi;
else for f in $materials
do
	export FILE_CACHE="$f.cache";
	dry_run || if [ "$f" -ot "$FILE_CACHE" ]
	then
		echo >&2 "$f: No changes, skipped.";
	else
		if [ -f "$FILE_CACHE" ]
		then
			rm $(cat "$FILE_CACHE");
			rm "$FILE_CACHE";
		fi
		parse "$f" || exit;
	fi;
done
fi;
