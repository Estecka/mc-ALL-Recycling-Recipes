#!/bin/bash

DRY=$1
function dry_run(){
	[ "$DRY" = "--dry" ]
}

function cut(){
	export OUTPUT="$NAMESPACE:$OUT"
	export  INPUT="$NAMESPACE:$IN"
	envsubst <./templates/cut.json >"./data/$NAMESPACE/recipes/${OUT}_from_${IN}_stonecutting.json"
}

function uncraft(){
	export OUTPUT="$NAMESPACE:$OUT"
	export  INPUT="$NAMESPACE:$IN"
	envsubst <"./templates/craft_$COST.json" >"./data/$NAMESPACE/recipes/uncraft/${IN}_$COST.json"
}

function recipes(){
	case $1 in
	# Bark to Logs
	%s_wood|%s_hyphae)
	IN=$VAR OUT=$RAW COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft
	;;
	# Stripping
	stripped_%s)
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
	IN=$VAR OUT=$RAW COUNT=1 COST="4" uncraft
	;;

	# Simple Shaping/Unshaping
	%s_brick_fence)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=3 COST="4" uncraft
	;;
	%s_slab)
	IN=$RAW OUT=$VAR COUNT=2 cut;
	IN=$VAR OUT=$RAW COUNT=1 COST="2h" uncraft
	IN=$VAR OUT=$RAW COUNT=2 COST="4" uncraft
	;;
	*)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft
	;;
	esac
}

function generate(){
	export NAMESPACE=$1
	local radical=$2
	local raw_form=$3
	shift 3;

	RAW=$(printf "$raw_form" "$radical") || return;
	export RAW;
	export GROUP="$NAMESPACE:$RAW";

	dry_run || mkdir -p "./data/$NAMESPACE/recipes/uncraft";
	while [[ $# -gt 0 ]]
	do
		local var_form=$1
		VAR=$(printf "$var_form" "$radical") || return;
		export VAR;
		shift;
		echo >&2 "$NAMESPACE:$RAW <-> $NAMESPACE:$VAR"
		dry_run || recipes "$var_form";
	done;
}

function parse(){
	jq <$1 -c '
		to_entries[] 
		| foreach .value[] as $value ({key}; {key, raw:$value.raw, vars:$value.variants}; foreach $value.materials[] as $mat (.; .mat=$mat; .))
		| [.key, .mat, .raw//"%s", .vars[]]
	' | while read -r entry;
	do
		echo "$entry" | jq '.[]' -r | tr -d '\r'| {
			args=();
			while read -r a; do args+=("$a"); done
			generate "${args[@]}";
		} || return;
	done;
}

dry_run || rm -r ./data/*
for f in ./materials/*
do
	parse "$f"
done;
