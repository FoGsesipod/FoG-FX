//=======================================================================================================
// Rim Color by FoG
// Version - 1.0
//=======================================================================================================

#include "ReShade.fxh"

//=======================================================================================================

uniform int PassOneBlendMode <
    ui_category = "Color Pass One";
    ui_label = "Blend Mode";
    ui_tooltip = "Determines How The Color Is Added";
    ui_type = "combo";
    ui_items = "\Soft Light\0Overlay\0Hard Light\0Multiply\0Vivid Light\0Linear Light\0Addition";
> = 1;

uniform float3 PassOneColor <
    ui_category = "Color Pass One";
    ui_label = "Color";
    ui_tooltip = "Color To Apply";
    ui_type = "color";
> = float3(1, 1, 1);

uniform float3 PassOneDetect <
    ui_category = "Color Pass One";
    ui_label = "Color To Apply";
    ui_tooltip = "Color To Addon";
    ui_type = "color";
> = float3(1, 1, 1);

uniform float PassOneTolerance <
    ui_category = "Color Pass One";
    ui_label = "Similarity Threshold";
    ui_tooltip = "Margin Of Color Similarity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.1;

uniform bool Debug <
    ui_category = "Debug Tools";
	ui_category_closed = true;
    ui_label = "Display Normal Map Pass";
    ui_tooltip = "Displays Surface Vectors";
> = false;

//=======================================================================================================

float Prevention(float Layer) {
    const float MinLayer = min(Layer, 0.5);
    const float MaxLayer = max(Layer, 0.5);

	return 2 * (MinLayer * MinLayer + 2 * MaxLayer - MaxLayer * MaxLayer) - 1.5;
}

float GetDepth(float2 texcoord) {
    float depth;
    if (Debug) {
        #if (RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN)
            texcoord.y = 1.0 - texcoord.y;
        #endif

        depth = tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;

        #if (RESHADE_DEPTH_INPUT_IS_LOGARITHMIC)
	        const float C = 0.01;
	        depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
		#endif
		#if (RESHADE_DEPTH_INPUT_IS_REVERSED)
		    depth = 1.0 - depth;
		#endif

        depth /= RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - depth * (RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - 1.0);
    }
    else {
        depth = ReShade::GetLinearizedDepth(texcoord);
    }
    return depth;
}

float3 NormalVector(float2 texcoord) {
    const float3 Offset = float3(BUFFER_PIXEL_SIZE.xy, 0.0);
    const float2 posCenter = texcoord.xy;
    const float2 posNorth = posCenter - Offset.zy;
    const float2 posEast = posCenter + Offset.xz;

    const float3 vertCenter = float3(posCenter - 0.5, 1) * GetDepth(posCenter);
    const float3 vertNorth = float3(posNorth - 0.5, 1) * GetDepth(posNorth);
    const float3 vertEast = float3(posEast - 0.5, 1) * GetDepth(posEast);

    return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}

float3 NearPixels(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {



}

void PassOneRimColor(in float4 vpos : SV_Position, in float2 texcoord : TEXCOORD, out float3 color : SV_Target) {
    const float3 NormalPass = NormalVector(texcoord);
    const float3 ColorPass = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float Blend;

    float Luma = dot(ColorPass.rgb, float3(0.32786885,0.655737705,0.0163934436));

    if (Debug) {
        color = NormalPass;
    }
    else {
        if (abs(ColorPass.r - PassOneDetect.r) <= PassOneTolerance && abs(ColorPass.g - PassOneDetect.g) <= PassOneTolerance && abs(ColorPass.b - PassOneDetect.b) <= PassOneTolerance) {
            color = cross(NormalPass, float3(0.5, 0.5, 1.0));
            float Base = max(max(color.x, color.y), color.z);
            if (PassOneBlendMode == 0) {
                // SoftLight
                Blend = lerp(2 * Luma * Base + Luma * Luma * (1.0 - 2 * Base), 2 * Luma * (1.0 - Base) + pow(Luma, 0.5) * (2 * Base - 1.0), step(0.49, Base));
            }
            if (PassOneBlendMode == 1) {
                // Overlay
                Blend = lerp(2 * Luma * Base, 1.0 - 2 * (1.0 - Luma) * (1.0 - Base), step(0.50, Luma));
            }
            if (PassOneBlendMode == 2) {
                // HardLight
                Blend = lerp(2 * Luma * Base, 1.0 - 2 * (1.0 - Luma) * (1.0 - Base), step(0.50, Base));
            }
            if (PassOneBlendMode == 3) {
                // Multiply
                Blend = saturate(2 * Luma * Base);
            }
            if (PassOneBlendMode == 4) {
                // Vivid Light
                Blend = lerp(2 * Luma * Base, Luma / (2 * (1 - Base)), step(0.50, Base));
            }
            if (PassOneBlendMode == 5) {
                // Linear Light
                Blend = Luma + 2.0 * Base - 1.0;
            }
            if (PassOneBlendMode == 6) {
                // Addition
                Blend = saturate(Luma + (Base - 0.5));
            }
            color = tex2D(ReShade::BackBuffer, texcoord).rgb;
            color += saturate(PassOneColor * Blend) * Prevention(Base);
        }
        else {
            color = tex2D(ReShade::BackBuffer, texcoord).rgb;
        }
    }

}

//=======================================================================================================

technique RimColor
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PassOneRimColor;
    }
}