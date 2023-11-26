# ALL Recycling Recipes

Recipe generator for the eponymous datapack.

Feel free to use the generator to create and publish your own datapack, but please do so using a different name and icon.

## Usage
`datagen.sh` will generate all the recipe files. The program [`jq`](https://jqlang.github.io/jq/) is required for this step.
- `--dry` Simulates recipes generation, without actually making any modification to the file system.
- `--clean` Removes all generated data and caches. Does nothing with dry.
- `--no-clobber` Causes the script to immediately fail if it would overwrite an existing file.

`pack.sh` will bundle the datapack into a zip file. This step is not strictly required; instead, the repository itself can be used as the datapack.

`build.sh` automatically runs all steps.


## Structure

### Materials-recipe association

The folder `materials/` contains jsons that define all pairings between raw materials and variants. Each json is cached separately, so subsequent builds will not regenerate recipes for jsons that have not been modified.  

The root object must contains two objects: `recipes` and `items`.

#### Items
`items` is a dictionary. Each key is the namespaces for the items. The same namespace is used for all items, and the recipe files.

Each value is an array of object with three components:
- `materials` An array of materials that share some identical recipes.
Materials are processed separately.
Each material is used as a base to compose the name of the corresponding raw item and variants.
- `raw` Optional, defaults to `"%s"`. Indicates how to compose the name of the raw items, by adding a prefix and a suffix to each material: the `%s` in the string is substitued with the name of the material.
- `variants` An array of strings. Composes the name of multiple variants for the raw item. The `%s` is substitued with the material corresponding material. Recipes for each pair of raw and variant items will be selected based on the on the variant's format, with the unsubstitued `%s`.

The notion of "raw" and "variants", do not inherently define the input and output of a recipe. Recipes may both turn raw into variants, and variants into raw.

#### Recipes
`recipes` is a dictionnary.

Each key is a pattern that will be matched against an item's *variant*.
Only **the first matching pattern** in the list will be selcted for any given variants.
A single pattern can be made to match multiple different variants, using [Bash's Pattern Matching](https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html) syntax.
A `%s` in a patterns will **not** be substitued with anything, but will match the literal `%s` in the variant's format. 

Each value is an array of recipes, that will all be generated for the matched variants. Recipes are represented by an array of strings; the first item is the recipe type, the following parameters depends on the recipe type:
- **`"cut"`** and **`"uncut"`** are stonecutter recipes. `"uncut"` produces the raw item, `"cut"` takes it as input.
	1. (int) The amount of resulting items.
- **`"uncraft"`** is a crating grid recipes, that produces the raw material.
	1. (string) A shorthand for the crafting pattern. The recipe will use the corresponding "`craft_`*`.json`" json file in `./templates/`
	2. (int) The amount of resulting items.

### Pre-processed variables

`variables.json` contains a list of variables that can be used in the `materials` and `variants` strings. When a string contains such variables, it will be duplicated into to every possible combination of every possible values of those variables.

The variable `${copper_block}` is a hardcoded exception, and is instead **post-processed**. Depending on what is appropriate for the final item name, it will become either `copper` or `copper_block`. (Because the _block disappears upon oxidation. Thanks mojang.)

## Example
```json
{
	"materials": [
		"${any_oxidation_}"
	],
	"raw": "%s_${copper_block}",
	"variants":[
		"${waxed_}%scut_copper"
	]
}
```
is, after pre-processing, equivalent to
```json
{
	"materials": [
		"",
		"exposed_",
		"weathered_",
		"oxidized_"
	],
	"raw": "%s_${copper_block}",
	"variants":[
		"%scut_copper",
		"waxed_%scut_copper"
	]
}
```
which is, after post-processing, equivalent to
```json
{
	"materials": [
		""
	],
	"raw": "copper_block",
	"variants":[
		"%cut_copper"
		"waxed_%scut_copper"
	]
},
{
	"materials": [
		"exposed_",
		"weathered_",
		"oxidized_"
	],
	"raw": "%s_copper",
	"variants":[
		"%scut_copper"
		"waxed_%scut_copper"
	]
}
```
which will generate recipes of type `%scut_copper` for:
```
    copper_block <-> cut_copper
  exposed_copper <-> exposed_cut_copper
weathered_copper <-> weathered_cut_copper
 oxidized_copper <-> oxidized_cut_copper

```
and recipes of type `waxed_%scut_copper` for
```
    copper_block <-> waxed_cut_copper
  exposed_copper <-> waxed_exposed_cut_copper
weathered_copper <-> waxed_weathered_cut_copper
 oxidized_copper <-> waxed_oxidized_cut_copper
```
