#!/bin/bash

DRY=$1
DATA=./materials_test.json

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
	%s_slab)
	IN=$RAW OUT=$VAR COUNT=2 cut;
	IN=$VAR OUT=$RAW COUNT=1 COST="2h" uncraft
	IN=$VAR OUT=$RAW COUNT=2 COST="4" uncraft
	;;

	%s_brick_fence)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=3 COST="4" uncraft
	;;

	*)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft
	;;
	esac
}

function generate(){
	export NAMESPACE=$1
	local radical=$2
	local raw_form=$3
	shift 3;

	export RAW=$(printf "$raw_form" "$radical");
	export GROUP="$NAMESPACE:$RAW";

	dry_run || mkdir -p "./data/$NAMESPACE/recipes/uncraft";
	while [[ $# -gt 0 ]]
	do
		local var_form=$1
		export VAR=$(printf "$var_form" "$radical");
		shift;
		echo >&2 "$NAMESPACE:$RAW <-> $NAMESPACE:$VAR"
		dry_run || recipes "$var_form";
	done;
}

dry_run || rm -r ./data

jq <$DATA -c '
	to_entries[] 
	| foreach .value[] as $value ({key}; {key, raw:$value.raw, vars:$value.variants}; foreach $value.materials[] as $mat (.; .mat=$mat; .))
	| [.key, .mat, .raw, .vars[]]
' | while read -r entry;
do
	echo "$entry" | jq '.[]' -r | tr -d '\r'| {
		args=();
		while read -r a; do args+=("$a"); done
		generate "${args[@]}";
	};
done;
