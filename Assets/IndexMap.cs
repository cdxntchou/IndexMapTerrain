using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

// TODO: move ReadOnly to it's own file
public class ReadOnlyAttribute : PropertyAttribute
{
}

[CustomPropertyDrawer(typeof(ReadOnlyAttribute))]
public class ReadOnlyDrawer : PropertyDrawer
{
    public override float GetPropertyHeight(SerializedProperty property,
                                            GUIContent label)
    {
        return EditorGUI.GetPropertyHeight(property, label, true);
    }

    public override void OnGUI(Rect position,
                               SerializedProperty property,
                               GUIContent label)
    {
        GUI.enabled = false;
        EditorGUI.PropertyField(position, property, label, true);
        GUI.enabled = true;
    }
}


[CreateAssetMenu(fileName = "NewIndexMap", menuName = "Terrain/IndexMap", order = 1)]
public class IndexMap : ScriptableObject, ISerializationCallbackReceiver
{
    [SerializeField]
    [HideInInspector]
    private bool initialized;                   // hax

    [SerializeField]
    [HideInInspector]
    private bool persisted;                     // ultra hax

    [SerializeField]
    private Texture2D indexMap;                 // texture stored in an asset, so we can modify it...

    private RenderTexture renderTexture;
    private bool useRenderTexture;              // true if render texture contains the data

    private bool copyBack;

    private void Initialize(string context)
    {
        if (!initialized && (indexMap == null))
        {
            // initialize indexMap
            bool mipChain = false;
            bool linear = true;
            indexMap = new Texture2D(64, 64, TextureFormat.ARGB32, mipChain, linear);
            indexMap.name = "indexMap";
            indexMap.filterMode = FilterMode.Point;
            indexMap.wrapMode = TextureWrapMode.Clamp;

            // TODO: clear to default
            initialized = true;
            EditorUtility.SetDirty(this);
            Debug.Log(context + " initialized");
        }

        if (initialized && !persisted)
        {
            if (EditorUtility.IsPersistent(this))
            {
                persisted = true;
                StoreObjectInAsset(indexMap);
                Debug.Log(context + " persisted (" + indexMap + ")");
                AssetDatabase.SaveAssets();
            }
            else
            {
                Debug.Log(context + " not persistent");
            }
        }
    }

//    private void OnEnable()
//    {
//        Debug.Log("IndexMap.OnEnable (" + indexMap + ", " + initialized + ", " + persisted + ")");
//        Initialize();
//    }

//    private void Start()
//    {
//        Debug.Log("IndexMap.Start (" + indexMap + ", " + initialized + ", " + persisted + ")");
//        //        Initialize();
//    }

//    private void Awake()
//    {
//        Debug.Log("IndexMap.Awake (" + indexMap + ", " + initialized + ", " + persisted + ")");
//        Initialize();
//    }

    private void StoreObjectInAsset(UnityEngine.Object sobj)
    {
        AssetDatabase.AddObjectToAsset(sobj, this);
        // mark ourselves as dirty so we will trigger refresh
        EditorUtility.SetDirty(this);
        EditorUtility.SetDirty(sobj);
    }

    public void SetIndexMapDirty()
    {
        copyBack = true;
        EditorUtility.SetDirty(this);

        // force re-save
        //        AssetDatabase.SaveAssets();
    }

    public void OnBeforeSerialize()
    {
        if (copyBack)
        {
            if (useRenderTexture)
            {
//                Debug.Log("IndexMap copyBack!");
                CopyFromRenderTexture(renderTexture, false);
                EditorUtility.SetDirty(indexMap);
                useRenderTexture = false;
            }
            copyBack = false;
        }
//        Debug.Log("IndexMap OnBeforeSerialize " + initialized + ", " + persisted);
        Initialize("OnBeforeSerialize");
    }

    public void OnAfterDeserialize()
    {
//        Debug.Log("IndexMap OnAfterDeserialize" + initialized + ", " + persisted);
//        Initialize();
    }

    public Texture GetTexture()
    {
        if (useRenderTexture)
            return renderTexture;
        else
            return indexMap;
    }

    public RenderTexture GetRenderTexture()
    {
        if (useRenderTexture)
        {
            return renderTexture;
        }
        else
        {
            if (renderTexture == null)   // TODO : check for matching resolution, format, etc.
            {
                //                renderTexture = new RenderTexture(64, 64, 1, UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm);
                RenderTextureDescriptor desc = new RenderTextureDescriptor(64, 64, RenderTextureFormat.ARGB32, 0);
                desc.sRGB = false;
                desc.useMipMap = false;
                desc.msaaSamples = 1;
                renderTexture = new RenderTexture(desc);
                renderTexture.anisoLevel = 1;
                renderTexture.name = "indexMapRT";
                renderTexture.filterMode = FilterMode.Point;
                renderTexture.wrapMode = TextureWrapMode.Clamp;
            }
            Graphics.Blit(indexMap, renderTexture);
            useRenderTexture = true;
            return renderTexture;
        }
    }

    private void CopyFromRenderTexture(RenderTexture sourceRT, bool releaseRenderTexture = true)
    {
        // gpu copy back -- doesn't update cpu version
//        Graphics.CopyTexture(sourceRT, indexMap);

        // cpu copy back
        RenderTexture oldRT = RenderTexture.active;
        RenderTexture.active = sourceRT;
        indexMap.ReadPixels(new Rect(0, 0, sourceRT.width, sourceRT.height), 0, 0);
        indexMap.Apply();
        RenderTexture.active = oldRT;

        // restore old state, release temporary RT
        //        RenderTexture.active = oldRT;
        if (releaseRenderTexture)
        {
            RenderTexture.ReleaseTemporary(sourceRT);
        }
    }

    /*
        public void SaveAll()
        {
            // slow but sure
            EditorUtility.SetDirty(this);
            foreach (GenericLayer layer in stack)
            {
                EditorUtility.SetDirty(layer.painterLayer);
                var srts = layer.painterLayer.GetSerializableRenderTextures();
                if (srts != null)
                {
                    foreach (SerializableRenderTexture srt in srts)
                    {
                        // sometimes layers pass us null srts..  handle it
                        if (srt != null)
                        {
                            srt.PrepareForSerialization(freeRenderTextures);
                        }
                    }
                }
            }
            AssetDatabase.SaveAssets();
        }

        //    currentPainter.StoreObjectInAsset(srt.PrepareForSerialization(false));

        // Start is called before the first frame update
        void Start()
        {

        }

        // Update is called once per frame
        void Update()
        {

        }
    */

    [CustomEditor(typeof(IndexMap))]
    public class IndexMapEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            IndexMap indexMap = (IndexMap)target;

            GUI.enabled = false;
            EditorGUILayout.Toggle("Initialized", indexMap.initialized);
            EditorGUILayout.Toggle("Persisted", indexMap.persisted);
            GUILayout.Label("Texture");
            GUILayout.Label(indexMap.indexMap);
            if (indexMap.renderTexture != null)
            {
                GUILayout.Label("RenderTexture");
                GUILayout.Label(indexMap.renderTexture);
            }
            GUI.enabled = true;
            indexMap.useRenderTexture = EditorGUILayout.Toggle("UseRenderTexture", indexMap.useRenderTexture);
            indexMap.copyBack = EditorGUILayout.Toggle("CopyBack", indexMap.copyBack);
            Texture2D loadImage = (Texture2D) EditorGUILayout.ObjectField("Load From", null, typeof(Texture2D), false);
            if (loadImage != null)
            {
                Graphics.CopyTexture(loadImage, indexMap.GetRenderTexture());
                indexMap.copyBack = true;
            }
            if (EditorGUILayout.Toggle("Clear", false))
            {
                RenderTexture old = RenderTexture.active;
                RenderTexture.active = indexMap.GetRenderTexture();

                int defaultMaterial = 0;
                int upDirection = 0x77;
                float defaultWeightMod = 0.5f;

                GL.Clear(false, true, new Color(
                    (defaultMaterial + 0.25f) / 255.0f,
                    defaultWeightMod,
                    (upDirection + 0.25f) / 255.0f,
                    1.0f));                 // store scale & rotation here ?
                RenderTexture.active = old;
            }
        }
    }
}
