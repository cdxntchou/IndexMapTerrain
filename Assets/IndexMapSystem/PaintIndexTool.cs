using UnityEngine;
using UnityEditor;
using System;
using UnityEngine.Experimental.TerrainAPI;
using UnityEditor.ShortcutManagement;

namespace UnityEditor.Experimental.TerrainAPI
{
//    [FilePathAttribute("Library/TerrainTools/PaintIndex", FilePathAttribute.Location.ProjectFolder)]
    internal class PaintIndexTool : TerrainPaintTool<PaintIndexTool>
    {
        const string toolName = "Paint Index";

        //         MaterialEditor m_TemplateMaterialEditor = null;
        //         [SerializeField]
        //         bool m_ShowMaterialEditor = false;

        //        [SerializeField]
        //        TerrainLayer m_SelectedTerrainLayer = null;
        //        TerrainLayerInspector m_SelectedTerrainLayerInspector = null;

        [SerializeField]
        int materialIndex = 0;

        [SerializeField]
        bool randomRotation;

        [SerializeField]
        float minRotation;

        [SerializeField]
        float maxRotation;

        [SerializeField]
        float fixedRotation;

        //        [SerializeField]
        //        bool m_ShowLayerEditor = false;

        [Shortcut("Terrain/Paint Index", typeof(TerrainToolShortcutContext))]
        static void SelectShortcut(ShortcutArguments args)
        {
            TerrainToolShortcutContext context = (TerrainToolShortcutContext)args.context;
            context.SelectPaintTool<PaintIndexTool>();
        }

        public override string GetName()
        {
            return toolName;
        }

        public override string GetDesc()
        {
            return "Paints the selected index onto the terrain texture";
        }

        static Material paintMaterial;
        private Material GetPaintMaterial()
        {
            if (paintMaterial == null)
            {
                paintMaterial = new Material(Shader.Find("Hidden/TerrainEngine/PaintIndex"));
            }
            return paintMaterial;
        }

        public static Texture TerrainToIndexMapTexture(PaintContext.ITerrainContext context)
        {
            Texture result = null;
            MaterialManager mgr = context.terrain.GetComponent<MaterialManager>();
            if (mgr != null)
            {
                IndexMap indexMap = mgr.GetIndexMap();
                result = indexMap.GetTexture();
            }
            return result;
        }

        public static RenderTexture TerrainToIndexMapRenderTexture(PaintContext.ITerrainContext context)
        {
            RenderTexture result = null;
            MaterialManager mgr = context.terrain.GetComponent<MaterialManager>();
            if (mgr != null)
            {
                IndexMap indexMap = mgr.GetIndexMap();
                result = indexMap.GetRenderTexture();
            }
            return result;
        }

        public override bool OnPaint(Terrain terrain, IOnPaint editContext)
        {
            MaterialManager mgr = terrain.GetComponent<MaterialManager>();
            if (mgr != null)
            {
                //                IndexMap indexMap = mgr.GetIndexMap();
                //                RenderTexture rt= indexMap.GetTempRenderTexture(true);
                paintInProgress = true;
                BrushTransform brushXform = TerrainPaintUtility.CalculateBrushTransform(terrain, editContext.uv, editContext.brushSize, 0.0f);

                PaintContext indexCtx = PaintContext.CreateFromBounds(terrain, brushXform.GetBrushXYBounds(), 64, 64, 1);
                indexCtx.CreateRenderTargets(RenderTextureFormat.ARGB32);

                PaintContext normalCtx = TerrainPaintUtility.CollectNormals(terrain, brushXform.GetBrushXYBounds(), 2);

                Material blitMaterial = TerrainPaintUtility.GetBlitMaterial();
                indexCtx.Gather(
                    TerrainToIndexMapTexture,
                    blitMaterial,
                    new Color(0.0f, 0.0f, 0.0f, 0.0f),
                    null,       // before
                    null);      // after

                // render source -> dest here
                //                RenderTexture.active = ctx.oldRenderTexture;

                Material paintMaterial = GetPaintMaterial();

                float brushStrength = Event.current.shift ? -editContext.brushStrength : editContext.brushStrength;
                Vector4 brushParams = new Vector4(
                    brushStrength,
                    0.0f,
                    0.0f, 0.0f);
                paintMaterial.SetTexture("_BrushTex", editContext.brushTexture);
                paintMaterial.SetVector("_BrushParams", brushParams);
                paintMaterial.SetFloat("materialIndex", materialIndex);
                paintMaterial.SetTexture("_NormalMap", normalCtx.sourceRenderTexture);

                Vector4 indexToNormalXform;
                TerrainPaintUtility.BuildTransformPaintContextUVToPaintContextUV(
                    indexCtx,
                    normalCtx,
                    out indexToNormalXform);
                paintMaterial.SetVector("_indexToNormalXform", indexToNormalXform);

                Vector4 xformParams = new Vector4();
                xformParams.x = (randomRotation ? minRotation : fixedRotation) / 360.0f;
                xformParams.y = (randomRotation ? maxRotation : fixedRotation) / 360.0f;
                paintMaterial.SetVector("_xformParams", xformParams);

                Vector4 randoms = new Vector4(
                    UnityEngine.Random.Range(0.0f, 1.0f),
                    UnityEngine.Random.Range(0.0f, 1.0f),
                    UnityEngine.Random.Range(0.0f, 1.0f),
                    UnityEngine.Random.Range(0.0f, 1.0f));
                paintMaterial.SetVector("_randoms", randoms);

                TerrainPaintUtility.SetupTerrainToolMaterialProperties(indexCtx, brushXform, paintMaterial);
                Graphics.Blit(indexCtx.sourceRenderTexture, indexCtx.destinationRenderTexture, paintMaterial, 0);

                //  ctx.ScatterToTexture()          // we should do this ... less temp render textures
                // and users don't have to store render textures at all...
                indexCtx.Scatter(
                    TerrainToIndexMapRenderTexture,
                    blitMaterial,
                    null,
                    null);

                normalCtx.Cleanup();
                indexCtx.Cleanup();
            }

            /*
                        BrushTransform brushXform = TerrainPaintUtility.CalculateBrushTransform(terrain, editContext.uv, editContext.brushSize, 0.0f);
                        PaintContext paintContext = TerrainPaintUtility.BeginPaintTexture(terrain, brushXform.GetBrushXYBounds(), m_SelectedTerrainLayer);
                        if (paintContext == null)
                            return false;

                        Material mat = TerrainPaintUtility.GetBuiltinPaintMaterial();

                        // apply brush
                        float targetAlpha = 1.0f;       // always 1.0 now -- no subtractive painting (we assume this in the ScatterAlphaMap)
                        Vector4 brushParams = new Vector4(editContext.brushStrength, targetAlpha, 0.0f, 0.0f);
                        mat.SetTexture("_BrushTex", editContext.brushTexture);
                        mat.SetVector("_BrushParams", brushParams);

                        TerrainPaintUtility.SetupTerrainToolMaterialProperties(paintContext, brushXform, mat);

                        Graphics.Blit(paintContext.sourceRenderTexture, paintContext.destinationRenderTexture, mat, (int)TerrainPaintUtility.BuiltinPaintMaterialPasses.PaintTexture);

                        TerrainPaintUtility.EndPaintTexture(paintContext, "Terrain Paint - Texture");
            */
            return true;
        }

        static Material _brushPreviewMaterial = null;
        private Material GetBrushPreviewMaterial()
        {
            if (_brushPreviewMaterial == null)
            {
                _brushPreviewMaterial = new Material(Shader.Find("Hidden/TerrainEngine/PaintIndexPreview"));
            }
            return _brushPreviewMaterial;
        }

        bool paintInProgress;
        static Vector2 lastUV;
        float lastBrushSize;
        public override void OnSceneGUI(Terrain terrain, IOnSceneGUI editContext)
        {
            // there's probably more logic we need to handle here
            if (paintInProgress && (Event.current.type == EventType.MouseUp))
            {
                MaterialManager mgr = terrain.GetComponent<MaterialManager>();
                if (mgr != null)
                {
                    mgr.GetIndexMap().SetIndexMapDirty();
                }
                paintInProgress = false;
            }

            // We're only doing painting operations, early out if it's not a repaint
            if (Event.current.type != EventType.Repaint)
                return;

            if (editContext.hitValidTerrain)
            {
                if (lastUV != editContext.raycastHit.textureCoord)
                {
                    editContext.Repaint(RepaintFlags.UI);
                }
                lastUV = editContext.raycastHit.textureCoord;
                lastBrushSize = editContext.brushSize;
                BrushTransform brushXform = TerrainPaintUtility.CalculateBrushTransform(terrain, editContext.raycastHit.textureCoord, editContext.brushSize, 0.0f);
                PaintContext ctx = TerrainPaintUtility.BeginPaintHeightmap(terrain, brushXform.GetBrushXYBounds(), 1);
                Material brushPreviewMaterial = GetBrushPreviewMaterial();
                Vector4 brushParams = new Vector4(editContext.brushStrength, 0.0f, 0.0f, 0.0f);
                brushPreviewMaterial.SetVector("_BrushParams", brushParams);
                TerrainPaintUtilityEditor.DrawBrushPreview(ctx, TerrainPaintUtilityEditor.BrushPreview.SourceRenderTexture, editContext.brushTexture, brushXform, brushPreviewMaterial, 0);
                TerrainPaintUtility.ReleaseContextResources(ctx);
            }
        }

/*
        private void DrawFoldoutEditor(Editor editor, int controlId, ref bool visible)
        {
            Rect titleRect = Editor.DrawHeaderGUI(editor, editor.target.name);
            int id = GUIUtility.GetControlID(controlId, FocusType.Passive);

            Rect renderRect = EditorGUI.GetInspectorTitleBarObjectFoldoutRenderRect(titleRect);
            renderRect.y = titleRect.yMax - 17f; // align with bottom
            bool newVisible = EditorGUI.DoObjectFoldout(visible, titleRect, renderRect, editor.targets, id);
            // Toggle visibility
            if (newVisible != visible)
            {
                UnityEditorInternal.InternalEditorUtility.SetIsInspectorExpanded(editor.target, newVisible);
                visible = newVisible;
                Save(true);
            }

            if (newVisible)
            {
                editor.OnInspectorGUI();
                EditorGUILayout.Space();
            }
        }

        private const int kTemplateMaterialEditorControl = 67890;
        private const int kSelectedTerrainLayerEditorControl = 67891;
*/

        private MaterialManager GetManager(Terrain terrain)
        {
            return terrain.GetComponent<MaterialManager>();
        }

        public override void OnInspectorGUI(Terrain terrain, IOnInspectorGUI editContext)
        {
            GUILayout.Label("Settings", EditorStyles.boldLabel);

            EditorGUI.BeginChangeCheck();

            EditorGUILayout.Space();
            materialIndex = EditorGUILayout.IntField("Material", materialIndex);

            EditorGUILayout.BeginHorizontal();
//            EditorGUILayout.LabelField("Rotation");
            randomRotation = GUILayout.Toggle(randomRotation, "Rotation", "Button");
            if (randomRotation)
            {
                EditorGUILayout.MinMaxSlider(ref minRotation, ref maxRotation, 0.0f, 360.0f);
            }
            else
            {
                fixedRotation = EditorGUILayout.Slider(fixedRotation, 0.0f, 360.0f);
            }
            EditorGUILayout.EndHorizontal();

            MaterialManager mgr = terrain.GetComponent<MaterialManager>();
            if (mgr == null)
            {
                GUILayout.Label("Cannot find MaterialManager");
            }
            else
            {
                /*
                                GUILayout.Label("IndexMap");
                                GUILayout.Label(mgr.GetIndexMap().GetTexture());
                                GUILayout.Label("Gather");

                                if (lastBrushSize > 0.0f)
                                {
                                    BrushTransform brushXform = TerrainPaintUtility.CalculateBrushTransform(terrain, lastUV, lastBrushSize, 0.0f);
                                    PaintContext ctx = PaintContext.CreateFromBounds(terrain, brushXform.GetBrushXYBounds(), 64, 64, 1);
                                    ctx.CreateRenderTargets(RenderTextureFormat.ARGB32);

                                    Material blitMaterial = TerrainPaintUtility.GetBlitMaterial();
                                    ctx.Gather(
                                        TerrainToIndexMapTexture,
                                        blitMaterial,
                                        new Color(0.0f, 0.0f, 0.0f, 0.0f),
                                        null,       // before
                                        null);      // after

                                    RenderTexture.active = ctx.oldRenderTexture;
                                    GUILayout.Label(ctx.sourceRenderTexture);
                                    ctx.Cleanup();
                                }
                */
            }
            /*
                        EditorGUILayout.Space();
                        if (m_TemplateMaterialEditor != null && m_TemplateMaterialEditor.target != terrain.materialTemplate)
                        {
                            UnityEngine.Object.DestroyImmediate(m_TemplateMaterialEditor);
                            m_TemplateMaterialEditor = null;
                        }
                        if (m_TemplateMaterialEditor == null && terrain.materialTemplate != null)
                        {
                            m_TemplateMaterialEditor = Editor.CreateEditor(terrain.materialTemplate) as MaterialEditor;
                            m_TemplateMaterialEditor.firstInspectedEditor = true;
                        }
                        if (m_TemplateMaterialEditor != null)
                        {
                            DrawFoldoutEditor(m_TemplateMaterialEditor, kTemplateMaterialEditorControl, ref m_ShowMaterialEditor);
                            EditorGUILayout.Space();
                        }

                        int layerIndex = TerrainPaintUtility.FindTerrainLayerIndex(terrain, m_SelectedTerrainLayer);
                        layerIndex = TerrainLayerUtility.ShowTerrainLayersSelectionHelper(terrain, layerIndex);
            */

            EditorGUILayout.Space();

            if (EditorGUI.EndChangeCheck())
            {
/*
                if (layerIndex != -1)
                    m_SelectedTerrainLayer = terrain.terrainData.terrainLayers[layerIndex];
                else
                    m_SelectedTerrainLayer = null;

                if (m_SelectedTerrainLayerInspector != null)
                {
                    UnityEngine.Object.DestroyImmediate(m_SelectedTerrainLayerInspector);
                    m_SelectedTerrainLayerInspector = null;
                }
                if (m_SelectedTerrainLayer != null)
                    m_SelectedTerrainLayerInspector = Editor.CreateEditor(m_SelectedTerrainLayer) as TerrainLayerInspector;
*/
                Save(true);
            }
/*
            if (m_SelectedTerrainLayerInspector != null)
            {
                var terrainLayerCustomUI = m_TemplateMaterialEditor?.m_CustomShaderGUI as ITerrainLayerCustomUI;
                if (terrainLayerCustomUI != null)
                    m_SelectedTerrainLayerInspector.SetCustomUI(terrainLayerCustomUI, terrain);

                DrawFoldoutEditor(m_SelectedTerrainLayerInspector, kSelectedTerrainLayerEditorControl, ref m_ShowLayerEditor);
                EditorGUILayout.Space();
            }
*/
            editContext.ShowBrushesGUI(5);
        }
    }
}
