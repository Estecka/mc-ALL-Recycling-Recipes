#!/bin/bash

#******************************************************************************#
# # Config                                                                     #
#******************************************************************************#

set -eu -o pipefail;

dry_run() { return 1; }
clean() { return 1; }
no_clobber() { return 1; }

while [[ $# -gt 0 ]] && [[ $1 =~ --[a-zA-Z-]+ ]]
do
	case $1 in
	--dry|--dry-run)
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

	echo >&1 "$1";
	if ! dry_run
	then
		echo >>"$RECIPE_LOG" "$1";
		envsubst >"$1";
	fi
}

function cut(){
	local IN=$1 OUT=$2;
	export COUNT=$3;
	export OUTPUT="$NAMESPACE:$OUT";
	export  INPUT="$NAMESPACE:$IN";
	write_file <./templates/cut.json "$OVERLAY/data/$NAMESPACE/recipes/${OUT}_from_${IN}_stonecutting.json";
}

function uncraft(){
	local IN=$1 OUT=$2;
	export COST=$3 COUNT=$4;
	export OUTPUT="$NAMESPACE:$OUT"
	export  INPUT="$NAMESPACE:$IN"
	write_file <"./templates/craft_$COST.json" "$OVERLAY/data/$NAMESPACE/recipes/uncraft/${IN}_$COST.json";
}

function recipes(){
	for recipe in "${RECIPES[@]}"
	do {
		read -r -d ';' pattern;
		[[ "$1" = $pattern ]] || continue;
		local IFS=','
		while read -r -d ';' type args
		do case "$type" in
			cut)
			cut "$RAW" "$VAR" $args;
			;;
			uncut)
			cut "$VAR" "$RAW" $args;
			;;
			uncraft)
			uncraft "$VAR" "$RAW" $args;
		esac
		done;
		return 0;
	} <<<"$recipe;"
	done;
	echo >&2 "No recipe found for \"$1\" in $FILE";
	return 1;
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
	envsubst "\$copper_block"<<<"$item";
}

function generate(){
	export NAMESPACE=$1;
	local radical=$2;
	local raw_form=$3;
	shift 3;

	RAW=$(printf "$raw_form" "$radical" | item_postprocess | sed -E 's/[()]*//g;t');
	export RAW;
	export GROUP="$NAMESPACE:$RAW";

	while [[ $# -gt 0 ]]
	do
		local var_form=$1;
		VAR=$(printf "$var_form" "$radical" | item_postprocess | sed -E 's/\([^()]*\)//g;t');
		export VAR;
		shift;
		# echo >&1 "$NAMESPACE:$RAW <-> $NAMESPACE:$VAR";
		recipes "$var_form";
	done;
}

function recursive_envsubst() {
	if [[ $# -gt 0 ]]
	then
		local key=$1;
		shift;
		if ! jq <"$OVERLAY/variables.json" -cbr -e 'has($key)' --arg key "$key" >/dev/null
		then 
			cat;
		else
			local input=$(cat);

			jq <"$OVERLAY/variables.json" -cbr '.[$key][]' --arg key "$key" \
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
		.recipes,
		(
			.items | to_entries[] 
			| foreach .value[] as $value ({key}; {key, raw:$value.raw, vars:$value.variants}; foreach $value.materials[] as $mat (.; .mat=$mat; .))
			| [.key, .mat, .raw//"%s", .vars[]]
		)
	' | {
		read -r r;
		readarray -t -d $'\n' RECIPES < <(jq -cbr 'to_entries[] | [.key, (.value[]|join(",")), "" ] | join(";")' <<<"$r");
		export RECIPES;

		while read -r entry
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

				dry_run || mkdir -p "$OVERLAY/data/$nsp/recipes/uncraft";

				material_preprocessor "$mat"$'\n'"$raw" | while read -r pmat && read -r praw
				do
					generate "$nsp" "$pmat" "$praw" "${vars[@]}";
				done;
			};
		done;
		unset RECIPES;
	};
}


#******************************************************************************#
# # Main                                                                       #
#******************************************************************************#

materials=./materials/*.json" "./*/materials/*.json;
if [[ $# -gt 0 ]]
then materials=$@;
fi;

if clean
then
	if dry_run
	then
		find ./materials/*.json.cache ./*/materials/*.json.cache;
		find ./data/* ./*/data -type f;
	else
		rm -f ./materials/*.json.cache ./*/materials/*.json.cache;
		rm -rf ./data/* ./*/data/*;
	fi;
else 
	for f in $materials
	do
		export FILE="$f"
		export RECIPE_CACHE="$f.cache";
		export RECIPE_LOG="$f.cache.tmp";
		export OVERLAY="$(dirname $(dirname $f))";

		if [ "$f" -ot "$RECIPE_CACHE" ]
		then
			echo >&2 "No changes, skipped: $f";
		else
			dry_run || for c in $RECIPE_CACHE $RECIPE_LOG
			do if [ -f "$c" ]
			then
				rm -f $(cat "$c");
				rm "$c";
			fi
			done;
			parse "$f";
			dry_run || mv "$RECIPE_LOG" "$RECIPE_CACHE";
		fi;
	done

	dry_run || for d in ./hardcoded_data ./*/hardcoded_data
	do if [ -d "$d" ]
	then
		cp -ruv "$d" -T "$(dirname $d)/data";
	fi
	done;
fi;

