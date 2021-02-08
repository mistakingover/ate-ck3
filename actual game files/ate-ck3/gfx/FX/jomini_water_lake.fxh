Includes = {
	"cw/utility.fxh"
}

ConstantBuffer( JominiWater )
{
	float2	ScreenResolution
	float	WaterReflectionNormalFlatten;
	float	WaterZoomedInZoomedOutFactor;

	float3	WaterToSunDir;
	float	WaterDiffuseMultiplier;
	float3	WaterColorShallow;
	float	WaterSpecular;
	float3	WaterColorDeep;
	float	WaterSpecularFactor;
	float3	WaterColorMapTint;
	float	WaterColorMapTintFactor;
	
	float	WaterGlossScale;
	float	WaterGlossBase;
	float	WaterFresnelBias;
	float	WaterFresnelPow;
	
	float	WaterCubemapIntensity;
	float	WaterFoamScale;
	float	WaterFoamDistortFactor;
	float	WaterFoamShoreMaskDepth;
	float	WaterFoamShoreMaskSharpness;
	float	WaterFoamNoiseScale;
	float	WaterFoamNoiseSpeed;
	float	WaterFoamStrength;
	
	float	WaterRefractionScale;
	float	WaterRefractionShoreMaskDepth;
	float	WaterRefractionShoreMaskSharpness;
	float	WaterRefractionFade;
	
	float2	WaterWave1Scale;
	float	WaterWave1Rotation;
	float	WaterWave1Speed;
	float2	WaterWave2Scale;
	float	WaterWave2Rotation;
	float	WaterWave2Speed;
	float2	WaterWave3Scale;
	float	WaterWave3Rotation;
	float	WaterWave3Speed;
	
	float	WaterWave1NormalFlatten;
	float	WaterWave2NormalFlatten;
	float	WaterWave3NormalFlatten;
	float	WaterFlowTime;
	
	float2 	WaterFlowMapSize;
	float 	WaterFlowNormalScale;
	float 	WaterFlowNormalFlatten;
	
	float	WaterHeight;	
	float	WaterFadeShoreMaskDepth;
	float	WaterFadeShoreMaskSharpness;
	float	WaterSeeThroughDensity;
	float	WaterSeeThroughShoreMaskDepth;
	float	WaterSeeThroughShoreMaskSharpness;
};


VertexStruct VS_INPUT_WATER
{
    int2 Position			: POSITION;
};

VertexStruct VS_OUTPUT_WATER
{
    float4 Position			: PDX_POSITION;
	float3 WorldSpacePos	: TEXCOORD0;
	float2 UV01				: TEXCOORD1;
};

PixelShader =
{
	Code
	[[
		float3 SampleNormalMapTexture( PdxTextureSampler2D Texture, float2 UV, float2 Scale, float Rotation, float Offset, float NormalFlatten )
		{
			float2 Rotate = float2( cos( Rotation ), sin( Rotation ) );
		
			float2 UVCoord = float2( UV.x * Rotate.x - UV.y * Rotate.y, UV.x * Rotate.y + UV.y * Rotate.x );
			UVCoord *= Scale;
			UVCoord.x += Offset;
			
			float3 Normal = UnpackNormal( PdxTex2D( Texture, UVCoord ) ).xzy;
			
			float2 InvRotate = float2( cos( -Rotation ), sin( -Rotation ) );
			Normal.xz = float2( Normal.x * InvRotate.x - Normal.z * InvRotate.y, Normal.x * InvRotate.y + Normal.z * InvRotate.x );
			Normal.z *= -1;
			
			Normal.y *= NormalFlatten;
			
			return normalize( Normal );
		}
		
		void SampleFlowTexture( PdxTextureSampler2D FlowMapTexture, PdxTextureSampler2D FlowNormalTexture, float2 FlowCoord, float2 NormalCoord, float2 Offset, float2 DDX, float2 DDY, out float3 Normal, out float FoamMask )
		{
			float3 FlowMap = PdxTex2DLod0( FlowMapTexture, FlowCoord ).rgb;
			float2 FlowDir = FlowMap.xy * 2.0 - 1.0;
			FlowDir = FlowDir / ( length( FlowDir ) + 0.000001 ); // Intel did not like normalize()

			float2x2 FlowRotMat = Create2x2( FlowDir.x, FlowDir.y, -FlowDir.y, FlowDir.x );
			float2x2 FlowInvRotMat = Create2x2( FlowDir.x, -FlowDir.y, FlowDir.y, FlowDir.x );
			float4 Sample = PdxTex2DGrad( FlowNormalTexture, mul( FlowRotMat, NormalCoord ) - Offset * FlowMap.b, DDX, DDY );
			
			Normal = UnpackNormal( Sample ).xzy;
			Normal.y *= 1.0 / max( 0.01, FlowMap.b );
			Normal.xz = mul( FlowInvRotMat, Normal.xz );
			
			FoamMask = Sample.a * FlowMap.b;
		}
		
		float3 CalcFlow( PdxTextureSampler2D FlowMapTexture, PdxTextureSampler2D FlowNormalTexture, float2 FlowMapUV, float2 NormalMapUV, out float FoamMask )
		{
			float FlowMapScale = 1.5;				
			float2 FlowCoordScale = WaterFlowMapSize * FlowMapScale;
			float2 FlowCoord = FlowMapUV * FlowCoordScale;
			
			float2 BlendFactor = abs( 2.0 * frac( FlowCoord ) - 1.0 ) - 0.5;
			BlendFactor = 0.5 - 4.0 * BlendFactor * BlendFactor * BlendFactor;
			//BlendFactor = 1.0 - abs( 2.0 * frac( FlowCoord ) - 1.0 );
			
			float2 NormalCoord = NormalMapUV * WaterFlowNormalScale;
			float2 DDX = ddx( NormalCoord );
			float2 DDY = ddy( NormalCoord );
			
			float2 Offset = float2( 0.0, -WaterFlowTime );
			
			float4 Sample1;
			SampleFlowTexture( FlowMapTexture, FlowNormalTexture, floor( FlowCoord ) / FlowCoordScale, NormalCoord, Offset, DDX, DDY, Sample1.xyz, Sample1.a );
			float4 Sample2;
			SampleFlowTexture( FlowMapTexture, FlowNormalTexture, floor( FlowCoord + float2(0.5, 0.0) ) / FlowCoordScale, NormalCoord, Offset, DDX, DDY, Sample2.xyz, Sample2.a );
			float4 Sample3;
			SampleFlowTexture( FlowMapTexture, FlowNormalTexture, floor( FlowCoord + float2(0.0, 0.5) ) / FlowCoordScale, NormalCoord, Offset, DDX, DDY, Sample3.xyz, Sample3.a );
			float4 Sample4;
			SampleFlowTexture( FlowMapTexture, FlowNormalTexture, floor( FlowCoord + float2(0.5, 0.5) ) / FlowCoordScale, NormalCoord, Offset, DDX, DDY, Sample4.xyz, Sample4.a );
			
			float4 Sample12 = lerp( Sample2, Sample1, BlendFactor.x );
			float4 Sample34 = lerp( Sample4, Sample3, BlendFactor.x );
			
			float4 Sample = lerp( Sample34, Sample12, BlendFactor.y );
			
			Sample.y *= WaterFlowNormalFlatten;
			float3 Normal = normalize( Sample.xyz );
			
			FoamMask = Sample.a;
			return Normal;
		}

		float3 CalcTerrainUnderwaterSeeThrough( float Depth, float3 WorldSpacePos, float3 WaterColorMap, float3 Color )
		{
			float3 ToCameraDir = normalize( CameraPosition.xyz - WorldSpacePos );
			float WaterDistance = 5*Depth / ToCameraDir.y;
			Color = lerp( WaterColorMap, Color, saturate( exp( -WaterSeeThroughDensity * WaterDistance ) ) );
			
			float WaterSeeThroughShoreMask = 1.0 - saturate( (WaterSeeThroughShoreMaskDepth - Depth) * WaterSeeThroughShoreMaskSharpness );
			//return vec3( WaterSeeThroughShoreMask );
			Color = lerp( Color, WaterColorMap, WaterSeeThroughShoreMask );
			
			return Color;
		}
		
		static const float MaxHeight = 50.0;
		float CompressWorldSpace( float3 WorldSpacePos )
		{
			float3 CameraPos = CameraPosition;
			if ( CameraPos.y > MaxHeight )
			{
				float Above = CameraPos.y - MaxHeight;
				float3 ToCameraDir = normalize( CameraPosition - WorldSpacePos );
				CameraPos = CameraPosition - ToCameraDir * (Above / ToCameraDir.y);
			}
			float3 ToCamera = CameraPos - WorldSpacePos;
			return length( ToCamera );
		}
		
		float3 DecompressWorldSpace( float3 WorldSpacePos, float Length )
		{
			float3 ToCameraDir = normalize( CameraPosition - WorldSpacePos );
				
			float3 CameraPos = CameraPosition;
			if ( CameraPos.y > MaxHeight )
			{
				float Above = CameraPos.y - MaxHeight;
				CameraPos = CameraPosition - ToCameraDir * (Above / ToCameraDir.y);
			}
			
			float3 RefractionWorldSpacePos = CameraPos - ToCameraDir * Length;
			return RefractionWorldSpacePos;
		}
	]]
}
