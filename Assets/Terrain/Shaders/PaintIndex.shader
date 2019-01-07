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

			sampler2D _NormalMap;
			float4 _NormalMap_TexelSize;      // 1/width, 1/height, width, height
			float4 _indexToNormalXform;

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
				float2 normalmapUV = i.pcUV * _indexToNormalXform.xy + _indexToNormalXform.zw;

				// out of bounds multiplier
				float oob = all(saturate(brushUV) == brushUV) ? 1.0f : 0.0f;

				float4 indexMap = tex2D(_MainTex, indexmapUV);

				float brushShape = UnpackHeightmap(tex2D(_BrushTex, brushUV));
				brushShape *= brushShape;

				// we double the strength to guarantee 100% opacity will give the correct shape
				float brushStrength = 2.0f * BRUSH_OPACITY * oob * brushShape;
				float brushThreshold = clamp(1.0f - BRUSH_OPACITY, 0.15f, 0.99f);

				// build random number for procedural random stuff
				float rand = random(indexmapUV);
				rand = bbs(rand);

				float oldMaterial = floor(indexMap.r * 255.0f + 0.5f);
				bool set = false;
				if (oldMaterial == materialIndex)
				{
					// existing material is the target material
					// increase it's weight by brushStrength
					indexMap.g = saturate(indexMap.g + brushStrength);
				}
				else
				{
					// existing material is NOT the target material
					// decrease it's weight by brushStrength (reduced if brushStrength is negative)
					indexMap.g = indexMap.g - brushStrength * (brushStrength < 0.0f ? 0.4f : 1.0f);
					if (indexMap.g <= 0.0f)
					{
						set = true;
					}
				}

				if (set)
				{
					// weight
					indexMap.g = abs(indexMap.g);

					// material index
					indexMap.r = (materialIndex + 0.25f) / 255.0;

					// projection direction -- sample normal map
					// TODO: could probably do something better by analyzing the local area to find a best-fit direction
					// this currently assumes the center sample is representative...
					float4 normalMap = tex2D(_NormalMap, normalmapUV);
					float3 normal = normalize(normalMap.xyz * 2.0f - 1.0f);

					// encode into 4:4 format for blue channel
					float2 proj = 0.5f * (normal.xz / normal.y);			// scale normal.y to 0.5, and the .xz components are the projDXY
					proj = clamp(floor(proj * 7.0f + 7.25f), 0, 15);		// [0, 15]
					float encoded = proj.y * 16.0f + proj.x;				// [0, 255]
					indexMap.b = (encoded + 0.5f) / 255.0f;

					// random rotation
					indexMap.a = lerp(ROTATE_MIN, ROTATE_MAX, rand);
					rand = bbs(rand);
				}
				else
				{
					indexMap.g = saturate(indexMap.g);
				}

				return indexMap;
            }

            ENDCG
        }

    }
    Fallback Off
}
