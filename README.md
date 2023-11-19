# ALL Recycling Recipes

Recipe generator for the eponymous datapack.

Feel free to use the generator to create and publish your own datapack, but please do so using a different name and icon.

## Usage
`datagen.sh` will generate all the recipe files. The program [`jq`](https://jqlang.github.io/jq/) for this step.

`pack.sh` will bundle the datapack into a zip file. This step is not strictly required; instead, the repository itself can be used as the datapack.

`build.sh` automatically runs all steps.


## Structure
Everything is running on the principle that blocks of a same group only differs by their suffix, so blocks will very often be identified solely by that suffix.

`materials.json` lists all materials, and their available shapes.

The recipes for each shape is defined in `datagen.sh`, in the `recipes` function.
