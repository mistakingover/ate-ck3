Includes = {
	"cw/pdxmesh.fxh"
	"jomini_water_edit.fxh"
}
VertexShader =
{
	Code
	[[
		VS_OUTPUT_WATER ConvertOutputWater( VS_OUTPUT_PDXMESH MeshOutput )
		{
			VS_OUTPUT_WATER Output;
				
			Output.Position = MeshOutput.Position;
			Output.WorldSpacePos = MeshOutput.WorldSpacePos;
			Output.UV01 = float2( MeshOutput.WorldSpacePos.x / MapSize.x, 1.0 - MeshOutput.WorldSpacePos.z / MapSize.y );
			
			return Output;
		}
	]]
	MainCode VS_jomini_water_mesh
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_WATER"
		Code
		[[
			PDX_MAIN
			{
				return ConvertOutputWater( PdxMeshVertexShaderStandard( Input ) );
			}
		]]
	}
	MainCode VS_jomini_water_mapobject
	{
		Input = "VS_INPUT_PDXMESH_MAPOBJECT"
		Output = "VS_OUTPUT_WATER"
		Code
		[[
			PDX_MAIN
			{
				return ConvertOutputWater( PdxMeshVertexShader( PdxMeshConvertInput( Input ), 0, UnpackAndGetMapObjectWorldMatrix( Input.InstanceIndex24_Opacity8 ) ) );				
			}
		]]
	}
}