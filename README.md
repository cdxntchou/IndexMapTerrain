# IndexMapTerrain

Example of using PaintContext.Gather/Scatter to implement Terrain tools that paint to custom textures.

Here the custom texture is an R8G8B8A8 index map, used as a replacement for the splatmaps.
The index map provides control of not only the material, but also the 3D texture projection, rotation, and weight.
