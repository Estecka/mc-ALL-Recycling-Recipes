# ALL Recycling Recipes

Recipe generator for the eponymous datapack.

Feel free to use the generator to create and publish your own datapack, but please do so using a different name and icon.

## Usage
`datagen.sh` will generate all the recipe files. The program [`jq`](https://jqlang.github.io/jq/) is required for this step.
- `--dry` Parses the recipe without making any modification to the file system.
- `--clean` Removes all generated and cached data before running. Does nothing in dry runs.
- `--no-clobber` Causes the script to fail if it would overwrite an existing file.

`pack.sh` will bundle the datapack into a zip file. This step is not strictly required; instead, the repository itself can be used as the datapack.

`build.sh` automatically runs all steps.


## Structure

### Materials-recipe association

The folder `materials/` contains jsons that define all pairings between raw materials and variants. Each json is cached separately, so subsequent builds will not regenerate recipes for jsons that have not been modified.  

The root objects defines the namespaces for the recipes. The same namespace is used for all items in the recipes.

For reach object inside the namespace:
- `materials` defines a group of materials that share identical recipes
- `raw` Defines the name of the source item, where `%s` is substitued with the name of the material.
- `variants` defines multiple recipes for the raw item. The `%s` is substitued with the material name to obtain the variant. The corresponding recipe(s) is selected based on the unsubstitued string (with the `%s`).  
Despite there seemingly being a notion of "raw" and "variants", the resulting recipes may actually craft the variants both **from** or **into** the raw item.  
Recipes types are hardcoded in `datagen.sh`, in the `recipes` function.

### Pre-processed variables

`variables.json` contains a list of variables that can be used in the `materials` and `variants` lists. When a string contains such variables, it will be duplicated into to every possible combination of every possible values of those variables.

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
