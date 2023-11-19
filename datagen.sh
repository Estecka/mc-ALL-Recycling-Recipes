#!/bin/bash

DRY=$1
DATA=./materials.json

function dry_run(){
	[ "$DRY" = "--dry" ]
}

function cut(){
	export OUTPUT="$ID_NAMESPACE:$OUT"
	export  INPUT="$ID_NAMESPACE:$IN"
	envsubst <./templates/cut.json >"./data/$ID_NAMESPACE/recipes/${OUT}_from_${IN}_stonecutting.json"
}

function uncraft(){
	export OUTPUT="$ID_NAMESPACE:$OUT"
	export  INPUT="$ID_NAMESPACE:$IN"
	envsubst <"./templates/craft_$COST.json" >"./data/$ID_NAMESPACE/recipes/uncraft/${IN}_$COST.json"
}

function recipes(){
	case $1 in
	_slab)
	IN=$RAW OUT=$VAR COUNT=2 cut;
	IN=$VAR OUT=$RAW COUNT=1 COST="2h" uncraft
	IN=$VAR OUT=$RAW COUNT=2 COST="4" uncraft
	;;

	_brick_fence)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=3 COST="4" uncraft
	;;

	*)
	IN=$RAW OUT=$VAR COUNT=1 cut;
	IN=$VAR OUT=$RAW COUNT=4 COST="4" uncraft
	;;
	esac
}

function idsplit(){
	if [[ "$1" =~ ^(.+):(.+)$ ]]
	then
		ID_NAMESPACE=${BASH_REMATCH[1]}
		ID_PATH=${BASH_REMATCH[2]}
		return 0;
	else
		return 1;
	fi;
}

function generate(){
	radical=$1;
	raw_suffix=$2
	var_suffix=$3
	idsplit "$radical" || return 1;

	RAW="$ID_PATH$raw_suffix";
	VAR="$ID_PATH$var_suffix";


	echo >&2 "$ID_NAMESPACE:$ID_PATH $raw_suffix <- $var_suffix"
	export ID_NAMESPACE;
	export VAR;
	export RAW;
	export GROUP="$ID_NAMESPACE:$RAW";
	dry_run && return 0;
	mkdir -p "./data/$ID_NAMESPACE/recipes/uncraft"
	recipes "$var_suffix";
}

dry_run || rm -r ./data
jq <$DATA -c 'to_entries | .[] | [.key, .value.raw, .value.derivatives[]]' |
while read -r entry;
do
	echo "$entry" | jq '.[]' -r | tr -d '\r'| {
		read -r base;
		read -r raw;
		while read -r var;
		do
			generate "$base" "$raw" "$var";
		done;
	};
done;
