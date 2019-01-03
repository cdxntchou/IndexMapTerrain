
sampler2D _IndexMap;
float4 _IndexMap_ST;
float4 _IndexMap_TexelSize;

half ApplyDetailContrast(half weight, half detail, half detailContrast)
{
	float result = max(0.1f * weight, detailContrast * (weight + detail) + 1.0f - (detail + detailContrast));
	return pow(result, 4.0);// *result * result;
}
