# IndexMapTerrain

Works in Unity 2019.4.28f1

Example of using PaintContext.Gather/Scatter to implement Terrain tools that paint to custom textures.

Here the custom texture is an R8G8B8A8 index map, used as a replacement for the splatmaps.
The index map provides control of not only the material, but also the 3D texture projection, rotation, and weight.

This lets you get very nice results on steep cliff faces:
![image](https://user-images.githubusercontent.com/28871759/136473557-81007962-fd96-415b-825f-4f7fb939eab0.png)

You can see each "index" controls the material in a local domain, and the weight controls how dominant that domain is over neighboring domains.
This gives you some control over where the transition between neighboring domains occurs.
![image](https://user-images.githubusercontent.com/28871759/136473590-a5541855-359a-4bb6-8ff1-64924424739f.png)

Each domain can be rotated independently, breaking up tiling patterns:
![image](https://user-images.githubusercontent.com/28871759/136473630-be9b3c9b-aaa9-4b6d-ad02-37c94517fe95.png)

By changing the projection direction of each domain, and considering the projection direction in the weights for domain blending, you can achieve good looking transitions between steep cliffs and flat areas.
![image](https://user-images.githubusercontent.com/28871759/136473642-d2916104-d8a6-439c-ab36-564a230f927f.png)
