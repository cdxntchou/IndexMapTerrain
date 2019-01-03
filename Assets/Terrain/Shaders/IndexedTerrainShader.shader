Shader "Nature/Terrain/Indexed" 
{
    Properties
    {
        // used in fallback on old cards & base map
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)

		_IndexMap ("IndexMap", 2D) = "white" {}
		_AlbedoArray("Albedo Array", 2DArray) = "" {}
		_NormalArray("Normal Array", 2DArray) = "" {}
		_DetailContrast("Detail Contrast", Float) = 4.0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
        }

        CGPROGRAM
        #pragma surface surf Standard vertex:SplatmapVert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer addshadow fullforwardshadows
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma multi_compile_fog // needed because finalcolor oppresses fog code generation.
        #pragma target 3.0
        // needs more than 8 texcoords
        #pragma exclude_renderers gles
        #include "UnityPBSLighting.cginc"

        #pragma multi_compile __ _NORMALMAP

        #define TERRAIN_STANDARD_SHADER
        #define TERRAIN_INSTANCED_PERPIXEL_NORMAL
        #define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard
//        #include "TerrainSplatmapCommon.cginc"

		struct Input
		{
			float4 tc;
			float3 worldPos;
#ifndef TERRAIN_BASE_PASS
			UNITY_FOG_COORDS(0) // needed because finalcolor oppresses fog code generation.
#endif
		};

#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)
		sampler2D _TerrainHeightmapTexture;
		sampler2D _TerrainNormalmapTexture;
		float4    _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
		float4    _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
#endif

UNITY_INSTANCING_BUFFER_START(Terrain)
	UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData) // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)

		void SplatmapVert(inout appdata_full v, out Input data)
		{
			UNITY_INITIALIZE_OUTPUT(Input, data);

#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)

			float2 patchVertex = v.vertex.xy;
			float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

			float4 uvscale = instanceData.z * _TerrainHeightmapRecipSize;
			float4 uvoffset = instanceData.xyxy * uvscale;
			uvoffset.xy += 0.5f * _TerrainHeightmapRecipSize.xy;
			float2 sampleCoords = (patchVertex.xy * uvscale.xy + uvoffset.xy);

			float hm = UnpackHeightmap(tex2Dlod(_TerrainHeightmapTexture, float4(sampleCoords, 0, 0)));
			v.vertex.xz = (patchVertex.xy + instanceData.xy) * _TerrainHeightmapScale.xz * instanceData.z;  //(x + xBase) * hmScale.x * skipScale;
			v.vertex.y = hm * _TerrainHeightmapScale.y;
			v.vertex.w = 1.0f;

			v.texcoord.xy = (patchVertex.xy * uvscale.zw + uvoffset.zw);
			v.texcoord3 = v.texcoord2 = v.texcoord1 = v.texcoord;

#ifdef TERRAIN_INSTANCED_PERPIXEL_NORMAL
			v.normal = float3(0, 1, 0); // TODO: reconstruct the tangent space in the pixel shader. Seems to be hard with surface shader especially when other attributes are packed together with tSpace.
			data.tc.zw = sampleCoords;
#else
			float3 nor = tex2Dlod(_TerrainNormalmapTexture, float4(sampleCoords, 0, 0)).xyz;
			v.normal = 2.0f * nor - 1.0f;
#endif
#endif

			v.tangent.xyz = cross(v.normal, float3(0,0,1));
			v.tangent.w = -1;

			data.tc.xy = v.texcoord;
#ifdef TERRAIN_BASE_PASS
#ifdef UNITY_PASS_META
			data.tc.xy = v.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
#endif
#else
			float4 pos = UnityObjectToClipPos(v.vertex);
			UNITY_TRANSFER_FOG(data, pos);
#endif
		}

#ifndef TERRAIN_BASE_PASS

#ifndef TERRAIN_SURFACE_OUTPUT
#define TERRAIN_SURFACE_OUTPUT SurfaceOutput
#endif

		void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
		{
			color *= o.Alpha;
#ifdef TERRAIN_SPLAT_ADDPASS
			UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0, 0, 0, 0));
#else
			UNITY_APPLY_FOG(IN.fogCoord, color);
#endif
		}

		void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
		{
			normalSpec *= o.Alpha;
		}

		void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
		{
			UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
			emission *= o.Alpha;
		}
#endif // TERRAIN_BASE_PASS

		sampler2D _IndexMap;
		float4 _IndexMap_ST;
		float4 _IndexMap_TexelSize;

		UNITY_DECLARE_TEX2DARRAY(_AlbedoArray);
		UNITY_DECLARE_TEX2DARRAY(_NormalArray);

		float _DetailContrast;	// TODO: make this per material.. :)

		half ApplyDetailContrast(half weight, half detail)
		{
			float detailContrast = 2.0f;
			float result = max(0.1f * weight, detailContrast * (weight + detail) + 1.0f - (detail + detailContrast));
			return pow(result, 4.0);// *result * result;
		}

		// Note that mesh tangent space is equivalent to terrain space in the instanced case (before heightmap is applied, it's just a flat plane)
		half3 GetGeomNormalMeshTangentSpace(Input IN)
		{
			half3 geomNormalMTS = half3(0.0f, 0.0f, 1.0f);	// use mesh normal
#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
			geomNormalMTS = normalize(tex2D(_TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1);
#endif
			return geomNormalMTS;
		}

		half3 NormalToWorldSpace(half3 normalTS, half3 geomNormalMTS)
		{
			half3 normalWS = float3(0.0f, 0.0f, 1.0f);
#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
			half3 geomNormalWS = geomNormalMTS;		// MTS is the same as WS when instanced
//#ifdef _NORMALMAP
			// build full tangent space
			half3 geomTangentWS = normalize(cross(geomNormalWS, float3(0, 0, 1)));
			half3 geomBitangentWS = normalize(cross(geomTangentWS, geomNormalWS));
			normalWS = normalTS.x * geomTangentWS
					 + normalTS.y * geomBitangentWS
					 + normalTS.z * geomNormalWS;
//#else
//			normalWS = geomNormalWS;
//#endif
			normalWS = normalWS.xzy;	// TODO: wha?   double check these normals are correct..
#endif
			return normalWS;
		}

		float bbs(float input)
		{
			return frac(dot(input*input, 251.0f));
		}

		float random(float2 input)
		{
			float4 a= frac(input.xyxy * (2.0f * float4(1.3442f, 1.0377f, 0.98848f, 0.75775f)) + input.yxyx);
			float v = frac(dot(a*a, 251.0f));
			return bbs(v);
		}

		// Project the surface gradient (dhdx, dhdy) onto the surface (n, dpdx, dpdy)
		float3 CalculateSurfaceGradient(float3 n, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
		{
			float3 r1 = cross(dpdy, n);
			float3 r2 = cross(n, dpdx);

			return (r1 * dhdx + r2 * dhdy) / dot(dpdx, r1);
		}

		// Move the normal away from the surface normal in the opposite surface gradient direction
		float3 PerturbNormal(float3 normal, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
		{
			return normalize(normal - CalculateSurfaceGradient(normal, dpdx, dpdy, dhdx, dhdy));
		}

		float ApplyChainRule(float dhdu, float dhdv, float dud_, float dvd_)
		{
			return dhdu * dud_ + dhdv * dvd_;
		}

		// Calculate the surface normal using the uv-space gradient (dhdu, dhdv)
		float3 CalculateSurfaceNormal(float3 position, float3 normal, float2 gradient, float2 uv)
		{
			// TODO: can move this out of the inner loop probably
			float3 dpdx = ddx(position);
			float3 dpdy = ddy(position);

			float dhdx = ApplyChainRule(gradient.x, gradient.y, ddx(uv.x), ddx(uv.y));
			float dhdy = ApplyChainRule(gradient.x, gradient.y, ddy(uv.x), ddy(uv.y));

			return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
		}

		void AccumulateMaterial(float2 texcoord, float3 geomPosWS, float3 geomNormalWS, half4 materialIndex, half weight, float2 uvcenter, inout SurfaceOutputStandard o)
		{
			float material = floor(materialIndex.r * 255.0f + 0.5f);

			// build random number for procedural random stuff
			float rand = random(uvcenter);

			// random weight modifier - TODO: control from materialIndex
			float weightMod = bbs(rand);
			
			// random rotation - TODO: control rotation from materialIndex
			float angleRand = bbs(weightMod);

			// random scale - TODO: control scale from materialIndex
			float scale = bbs(angleRand);

			float angle = materialIndex.a * (2.0f * 3.14159265358979323f);
//			float angle = (angleRand * (2.0f * 3.14159265358979323f));
//			if (material == 3.0)
//			{
//				angle = 0.0f;
//			}
//			angle += _Time.x * 0.1f;		// animate rotation
			float rx = sin(angle);
			float ry = cos(angle);

			// random color (for debug)
			float red = bbs(scale);
			float green = bbs(red);
			float blue = bbs(green);

//			scale = 0.27f * saturate(sin((uvcenter.x + uvcenter.y) * 20.0f + _Time.x * 25.0f) * 0.5f + 0.5f);

			weightMod = materialIndex.g;

			// animate weight modifiers
//			float v2 = bbs(blue);
//			weightMod = (sin(_Time.w * lerp(0.21f, 0.45f, weightMod)) * 0.5f + 0.5f); // lerp(weightMod, v2, saturate(_SinTime.w * 0.5f + 0.5f));

			// don't let it go to zero, starts to break down
			weightMod = weightMod * weightMod + 0.1f;

			float2 rot = normalize(float2(rx, ry)); // *lerp(64.0f, 120.5f, s);

			float2 matUV;
			
			// projection direction defined by indexmap blue channel
			float proj = floor(materialIndex.b * 255.0f + 0.5f);		// [0, 255]		decode byte
			float projDX = frac(proj / 16.0f);							// [0, 15/16]	break into x and y components, 4 bits each
			float projDY = (proj - projDX * 16.0f) / 256.0f;			// [0, 15/16]
			
			projDX = (projDX * 16.0f - 7.0f) / 7.0f;								// [-1, 1 1/7]		bounds here are not centered, so that 0x77 is exactly "up"
			projDY = (projDY * 16.0f - 7.0f) / 7.0f;								// [-1, 1 1/7]

//			projDX = 0.0f;		// force top down projection everywhere
//			projDY = 0.0f;

			float3 projF = normalize(float3(projDX, 0.5f, projDY));					// projection direction
			float3 projU = normalize(cross(projF, float3(rot.x, 0.0f, rot.y)));		// U direction is defined by rotation
			float3 projV = cross(projU, projF);										// V direction (don't have to normalize)

			// project texcoords
			scale = lerp(0.0625f, 0.125f, scale);			// TODO: per material scale bounds
			scale = 0.0625f;								// fixed scale
			matUV.x = dot(projU, geomPosWS) * scale;
			matUV.y = dot(projV, geomPosWS) * scale;

//			matUV.y += _Time.x * 0.9f;		// animate material in V

			// TODO: we may be able to calculate dudx, dudy from dpdx, dpdy and this projection.... would probably solve weird ddx issues across splats
			
			float3 materialUV = float3(matUV, material);

			half4 albedo = UNITY_SAMPLE_TEX2DARRAY(_AlbedoArray, materialUV);
			half3 normalTS = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(_NormalArray, materialUV));
			float2 dHdUV = normalTS.xy * -16.0f; // / (normalTS.z + 0.001f);

			// calculate world space normal
			float3 normalWS = CalculateSurfaceNormal(geomPosWS, geomNormalWS, dHdUV, materialUV.xy);

//			half3 temp = normalTS.xyz;
//			normalTS.x = dot(temp.xy, float2(rot.y, rot.x));
//			normalTS.y = dot(temp.xy, float2(-rot.x, rot.y));

			half smoothness = 0.0f;
			half metallic = 0.0f;

			float3 projWeight = saturate(dot(projF, geomNormalWS));
			weight *= (projWeight * projWeight + 0.0001f);

			half detail = albedo.a;		// *(saturate(dot(projF, geomNormalWS)) + 0.01f);	// applying weight modifier to detail instead?  hmmm
			weight = ApplyDetailContrast(sqrt(weight * weightMod), detail);					// sqrt looks better -- crunchier transitions -- not sure if just because I have bad weightMods though...

			// debug modes
//			albedo.rgb = float3(red, green, blue);									// pure random color
//			albedo.rgb = (0.25f * float3(red, green, blue) + 0.5f * albedo.rgb);	// random color tint per patch
//			albedo.rgb = float3(projF.xyz * 0.5f + 0.5f);							// projection direction
//			albedo.rgb = frac(materialUV * 5.0f);									// material UV debug

			o.Albedo += weight * albedo.rgb;
			o.Normal += weight * normalWS;
			o.Alpha += weight;
			o.Smoothness += weight * smoothness;
			o.Metallic += weight * metallic;
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			// adjust splatUVs so the edges of the terrain tile lie on pixel centers
			float2 indexPixels = IN.tc.xy * (_IndexMap_TexelSize.zw - 1.0f);
			float2 texcoord = indexPixels * _IndexMap_TexelSize.xy;


			// compute bilinear neighbor UVs and their weights, using a mirrored scheme to fix derivative issues
			float2 index00Pixel = floor(indexPixels);

			float4 mirror = float4(0.0f, 0.0f, 1.0f, 1.0f);
			mirror.xy = frac(index00Pixel * 0.5f) * 2.0f;		// 0.0 or 1.0
			mirror.zw = 1.0f - mirror;							// 1.0 or 0.0

			half2 weights1 = (saturate(indexPixels - index00Pixel));
			
			weights1 = lerp(weights1, 1.0f - weights1, mirror.xy);		// there is probably a simpler calculation we can do here to invert the weights on mirror..

			//weights1 = smoothstep(0.0f, 1.0f, weights1);
			half2 weights0 = 1.0 - weights1;

			float2 index00UV = (index00Pixel + mirror.xy) * _IndexMap_TexelSize.xy;
			float2 index01UV = (index00Pixel + mirror.xw) * _IndexMap_TexelSize.xy;
			float2 index10UV = (index00Pixel + mirror.zy) * _IndexMap_TexelSize.xy;
			float2 index11UV = (index00Pixel + mirror.zw) * _IndexMap_TexelSize.xy;

			half4 index00 = tex2D(_IndexMap, index00UV);
			half4 index01 = tex2D(_IndexMap, index01UV);
			half4 index10 = tex2D(_IndexMap, index10UV);
			half4 index11 = tex2D(_IndexMap, index11UV);

			float3 geomPosWS = IN.worldPos;
			half3 geomNormalMTS = GetGeomNormalMeshTangentSpace(IN);

			// TODO: This conversion is only accurate when instancing is enabled
			//  for non-instanced case we need access to the mesh tangent space here (TODO)
			half3 geomNormalWS = geomNormalMTS;
			
			o.Albedo = 0.0f;
			o.Normal = 0.0f;
			o.Alpha = 0.0f;
			o.Smoothness = 0.0f;
			o.Metallic = 0.0f;

			AccumulateMaterial(texcoord, geomPosWS, geomNormalWS, index00, weights0.x * weights0.y, index00UV, o);
			AccumulateMaterial(texcoord, geomPosWS, geomNormalWS, index01, weights0.x * weights1.y, index01UV, o);
			AccumulateMaterial(texcoord, geomPosWS, geomNormalWS, index10, weights1.x * weights0.y, index10UV, o);
			AccumulateMaterial(texcoord, geomPosWS, geomNormalWS, index11, weights1.x * weights1.y, index11UV, o);

			// normalize
			float scale = 1.0 / o.Alpha;
			o.Albedo *= scale;
			o.Normal *= scale;
			o.Alpha = 1.0f;
			o.Smoothness *= scale;
			o.Metallic *= scale;

//			o.Normal = geomNormalMTS;		// no bump map
			o.Normal = o.Normal.xzy;

//			o.Albedo = float3(0.25f, 0.25f, 0.25f);		// override to gray color
//			float3 normalTS = float3(0.0f, 0.0f, 1.0f); // o.Normal.xyz * scale;

//			o.Normal = NormalToWorldSpace(normalTS, geomNormalMTS);

//			o.Albedo.rgb = saturate(geomNormalMTS * 0.5f + 0.5f);
//			o.Albedo.rgb = saturate(normalize(o.Normal) * 0.3f + 0.3f);

//			o.Normal.xyz = float3(0.0f, 0.0f, 1.0f);
		}
        ENDCG

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

//    Dependency "AddPassShader"    = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
    Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/Standard-Base"
    Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/Standard-BaseGen"

    Fallback "Nature/Terrain/Standard"
}
