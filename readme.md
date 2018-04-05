# Quake 3 BSP Renderer for iOS

This is a hobby project I've been working on, on and off since late 2015.
The project is an implementation of a simple rendering engine for Quake 3 maps,
written using Swift and the Metal GPU API.

Keep in mind that this is absolutely not an idiomatic way to write swift, a game, or anything else. It's purely a learning project so it's pretty hacky in a lot of places.

As of time of writing (2018-04-05) this doesn't have any optimizations like using the BSP's clustering system to cull geometry or even frustum culling. It still runs at 60fps on my iPhone 6S so it's not a huge issue, but I'd like to implement it eventually.

## How it works
1. Read in the `pak0.pk3` file using the `zipzap` library. The `pk3` file format is actually a zip file in disguise and it contains all of the assets necessary to render the game world. This file can be found in a retail copy of Quake 3.
2. Parse the `.bsp` file we wish to display. The BSP file for a map contains the map geometry, the lightmaps (lighting is baked in to the map), spawn points, the names of textures and shaders, and much more info used by the map.  
Some faces are bezier patches (curved surfaces described by math, like the pen-tool in graphics apps, just in 3D), so we generate the geometry for them here.
3. Parse the Shader files used by the map. Quake 3 was written before programmable graphics APIs were widespread, so there's a proprietary 'shader' language that's used in the Q3 engine. These would have translated to a bunch of fixed-function opengl calls, but instead, we parse these 'shaders' in to a bunch of data structures to generate one or more Metal shader files (C++)
4. Load all the resources in to GPU memory. This includes the map geometry and lightmaps loaded in step 2, the shaders generated in step 3, and the textures that the shaders required in step 3.
5. Now we can work with it like a normal game/3d graphics app. I'm not going to describe this because it's likely going to change.
