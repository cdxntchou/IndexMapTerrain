using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class MaterialManager : MonoBehaviour
{
    [SerializeField]
    public IndexMap indexMap;

    [SerializeField]
    public Texture2DArray albedoTextures;

    [SerializeField]
    public Texture2DArray normalTextures;

    [SerializeField]
    public Material indexMaterial;

    public Material localMaterialCopy;

    Material GetTerrainMaterial()
    {
        return localMaterialCopy;
    }

    // Start is called before the first frame update
    void Start()
    {
//        Debug.Log("MaterialManager start");
    }

    private void Awake()
    {
//        Debug.Log("MaterialManager awake");
    }

    private void OnEnable()
    {
//        Debug.Log("MaterialManager OnEnable");
        UpdateTerrainMaterial();
        ApplyTerrainMaterial();
//        RenderPipeline.beginFrameRendering += RenderPipeline_beginFrameRendering;
//        Application.onBeforeRender
    }

    private void OnDisable()
    {
//        Debug.Log("MaterialManager OnDisable");
//        RenderPipeline.beginFrameRendering -= RenderPipeline_beginFrameRendering;
    }

//    private void RenderPipeline_beginFrameRendering(Camera[] obj)
//    {
//        Debug.Log("RenderPipeline.BeginFrameRendering");
//        UpdateTerrainMaterial();
//    }

//    private void Application_onBeforeRender()
//    {
//    }

    public IndexMap GetIndexMap()
    {
        return indexMap;
    }

    void UpdateTerrainMaterial()
    {
        Texture index = GetIndexMap().GetTexture();
        if (index != null)
        {
            if (localMaterialCopy == null)
            {
                localMaterialCopy = Object.Instantiate<Material>(indexMaterial);
            }

            localMaterialCopy.SetTexture("_IndexMap", index);
            localMaterialCopy.SetTexture("_AlbedoArray", albedoTextures);
            localMaterialCopy.SetTexture("_NormalArray", normalTextures);
        }
    }

    void ApplyTerrainMaterial()
    {
        Terrain terrain = GetComponent<Terrain>();
        if (terrain == null)
        {
            Debug.Log(" NO TERRAIN FOUND");
        }
        else
        {
            terrain.drawInstanced = true;
            terrain.materialType = Terrain.MaterialType.Custom;
            terrain.materialTemplate = GetTerrainMaterial();
        }
    }

//     public void OnPreCull()
//     {
//         Debug.Log("MaterialManager OnPreCull");
//     }

//     public void OnPreRender()
//     {
//         Debug.Log("MaterialManager OnPreRender");
//         UpdateTerrainMaterial();
//     }

    private void OnRenderObject()
    {
//        Debug.Log("MaterialManager OnRenderObject");
        UpdateTerrainMaterial();
    }

    // Update is called once per frame
    void Update()
    {
//        Debug.Log("MaterialManager update");
    }
}
