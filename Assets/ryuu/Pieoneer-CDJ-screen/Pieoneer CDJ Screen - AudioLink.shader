Shader "ryuu/Pieoneer Waveform"
{
	Properties
	{
		_MainTex("Background", 2D) = "black" {}
		_MainTex_Color("Background Color", Color) = (1, 1, 1, 1)
		[Toggle] _TransparentBackground ("Transparent Background",float) = 0

		[KeywordEnum(3Band, RGB, Blue)] _Style("Waveform Style", int) = 0
		_WaveformGain("Gain", Range(-1,1)) = 0
		_WaveformSmoothness("Waveform Smoothness", Range(0,0.2)) = 0.01
		[IntRange] _WaveformZoom("Zoom", Range(1,4)) = 0

	}
	SubShader
	{
		Cull Back
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		Tags { "Queue" = "Transparent" "RenderType" = "Transparent"}

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _STYLE_3BAND _STYLE_RGB _STYLE_BLUE
			#pragma shader_feature _TRANSPARENTBACKGROUND_ON

			#include "UnityCG.cginc"
			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 tex_uv : TEXCOORD1;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 tex_uv : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_Color;

			float _WaveformSmoothness;
			float _WaveformGain;
			half _WaveformZoom;

			fixed3 _BassColor;
			fixed3 _MidColor;
			fixed3 _HighColor;


			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.tex_uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv = v.uv;

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{

				#ifdef _STYLE_3BAND
					_BassColor = fixed3(0, 0.1682694, 0.7379106);
					_MidColor = fixed3(0.4507858, 0.1412633, 0.01161224);
					_HighColor = fixed3(0.921582, 0.822786, 0.6938719);
				#elif _STYLE_RGB
					_BassColor = fixed3(1, 0.006941255, 0.005208478);
					_MidColor = fixed3(0, 1, 0.02125202);
					_HighColor = fixed3(0, 0.05581313, 1);
				#elif _STYLE_BLUE
					_BassColor = fixed3(0.06281455, 0.223414, 1);
					_MidColor = fixed3(0.0664974, 0.4508419, 0.7388448);
					_HighColor = fixed3(0.5461946, 0.8154009, 0.8794155);
				#endif

				#ifndef _TRANSPARENTBACKGROUND_ON
					// FIXME: The waveforms end up sliding away from the texture before jumping back into place.
					i.tex_uv.x *=  _MainTex_ST.x / _WaveformZoom;
					i.tex_uv.x += _Time.y * AUDIOLINK_4BAND_TARGET_RATE / AUDIOLINK_WIDTH;
					fixed4 c = tex2D(_MainTex, i.tex_uv);
					c *= _MainTex_Color;
				#else
					fixed4 c = fixed4(0,0,0,0);
				#endif

				i.uv.x = 1 - i.uv.x;

				float band0 = AudioLinkData(ALPASS_AUDIOLINK + float2(i.uv.x * AUDIOLINK_WIDTH / _WaveformZoom , 0)).r;
				band0 += band0 * _WaveformGain;
				
				float band1 = AudioLinkData(ALPASS_AUDIOLINK + float2(i.uv.x * AUDIOLINK_WIDTH / _WaveformZoom , 1)).r*0.7;
				band1 += band1 * _WaveformGain;
				
				float band2 = AudioLinkData(ALPASS_AUDIOLINK + float2(i.uv.x * AUDIOLINK_WIDTH / _WaveformZoom , 2)).r*0.5;
				band2 += band2 * _WaveformGain;

				float uvpoint = abs(i.uv.y - 0.5); 

				c = lerp(c, fixed4(_BassColor.rgb,1), smoothstep(band0, band0 - _WaveformSmoothness, uvpoint));
				c = lerp(c,fixed4( _MidColor.rgb, 1), smoothstep(band1, band1 - _WaveformSmoothness, uvpoint));
				c = lerp(c, fixed4(_HighColor.rgb, 1), smoothstep(band2, band2 - _WaveformSmoothness, uvpoint));
				
				return c;
			}

			ENDCG
		}
	}
}
