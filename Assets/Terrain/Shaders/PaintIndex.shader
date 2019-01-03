Shader "Hidden/TerrainEngine/PaintIndex"
{
	Properties
	{
		_MainTex("Texture", any) = "" {} 
	}

    SubShader
    {
		ZTest Always Cull Off ZWrite Off
//		Blend SrcAlpha OneMinusSrcAlpha

        CGINCLUDE
            // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
            #pragma exclude_renderers gles

            #include "UnityCG.cginc"
			#include "TerrainTool.cginc"

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;      // 1/width, 1/height, width, height

            sampler2D _BrushTex;
			float4 _BrushParams;
			#define BRUSH_OPACITY       (_BrushParams.x)

			// TODO: this needs to be a PaintContext index map, to cross borders
			sampler2D _IndexMap;
			float4 _IndexMap_ST;
			float4 _IndexMap_TexelSize;

//			UNITY_DECLARE_TEX2DARRAY(_AlbedoArray);

			// TODO: put this function in a single location
			half ApplyDetailContrast(half weight, half detail)
			{
				float detailContrast = 2.0f;
				float result = max(0.1f * weight, detailContrast * (weight + detail) + 1.0f - (detail + detailContrast));
				return pow(result, 4.0);// *result * result;
			}

			struct appdata_t {
				float4 vertex : POSITION;
				float2 pcUV : TEXCOORD0;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				float2 pcUV : TEXCOORD0;
			};

			v2f vert(appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.pcUV = v.pcUV;
				return o;
			}
        ENDCG

        Pass    // 0 paint index
        {
            Name "Paint Index"

			ColorMask RGBA

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment PaintIndexMap

			float materialIndex;
			float4 _xformParams;
			#define ROTATE_MIN (_xformParams.x)
			#define ROTATE_MAX (_xformParams.y)

			float4 _randoms;
			#define RANDOM0				(_randoms.x)
			#define RANDOM1				(_randoms.y)
			#define RANDOM2				(_randoms.z)
			#define RANDOM3				(_randoms.w)

			float bbs(float input)
			{
				return frac(dot(input*input, 251.0f));
			}

			float random(float2 input)
			{
				float4 a = frac(input.xyxy * (2.0f * (0.5f + _randoms)) + input.yxyx);
				float v = frac(dot(a*a, 251.0f));
				return bbs(v);
			}

            float4 PaintIndexMap(v2f i) : SV_Target
            {
                float2 brushUV = PaintContextUVToBrushUV(i.pcUV);
				float2 indexmapUV = i.pcUV;

				// out of bounds multiplier
				float oob = all(saturate(brushUV) == brushUV) ? 1.0f : 0.0f;

				float4 indexMap = tex2D(_MainTex, indexmapUV);

                float brushStrength = oob * UnpackHeightmap(tex2D(_BrushTex, brushUV));
				float brushThreshold = clamp(1.0f - BRUSH_OPACITY, 0.15f, 0.99f);

				if (brushStrength > brushThreshold)
				{
					indexMap.r = (materialIndex + 0.25f) / 255.0;

					// build random number for procedural random stuff
					float rand = random(indexmapUV);
					rand = bbs(rand);

					// random rotation
					indexMap.a = lerp(ROTATE_MIN, ROTATE_MAX, rand);
					rand = bbs(rand);
				}

				return indexMap;
            }

            ENDCG
        }

    }
    Fallback Off
}
