Shader "ryuu/Pieoneer Waveform"
{
	Properties
	{
		_MainTex("Background", 2D) = "black" {}
		_MainTex_Color("Background Color", Color) = (1, 1, 1, 1)
		[Toggle] _TransparentBackground ("Transparent Background",float) = 0

		[KeywordEnum(3Band, RGB, Blue)] _Style("Waveform Style", int) = 0
		_WaveformGain("Gain", Range(0,1)) = 1
		[IntRange] _WaveformSampleRate("Wave count", Range(1,256)) = 1
		_BandTimeShift("Band shift multiplier", Range(0,1)) = 1
		_WaveformSmoothness("Waveform Smoothness", Range(0.05,1)) = 0.01
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

			#define IF(a, b, c) lerp(b, c, step((fixed) (a), 0))
			#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))

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
			float _WaveformThickness;
			float _WaveformSampleRate;
			float _BandTimeShift;
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

				_WaveformSampleRate =  _WaveformSampleRate / _WaveformZoom;
				
				i.uv.x = 1 - i.uv.x;

				float audiolink_saw = lerp(0,1,frac(i.uv.x*AUDIOLINK_WIDTH/_WaveformZoom));
				float audiolink_scroll_speed = 1/AUDIOLINK_4BAND_TARGET_RATE * AUDIOLINK_WIDTH * _WaveformZoom;
				float audiolink_uv_x = ((i.uv.x) * AUDIOLINK_WIDTH / _WaveformZoom);
				
				float band0_polarity = lerp(0, 1, 1-abs(frac((-(i.uv.x) + _Time.y*audiolink_scroll_speed) * 2 * _WaveformSampleRate)-0.5)*2);
				float band1_polarity = lerp(0, 1, 1-abs(frac((-(i.uv.x+0.3*_BandTimeShift) + _Time.y*audiolink_scroll_speed) * 2 * _WaveformSampleRate)-0.5)*2);
				float band2_polarity = lerp(0, 1, 1-abs(frac((-(i.uv.x+0.6*_BandTimeShift) + _Time.y*audiolink_scroll_speed) * 2 * _WaveformSampleRate)-0.5)*2);
				
				i.uv.x = glsl_mod(i.uv.x + _Time.y, 1.0 / (_WaveformZoom / _WaveformSampleRate * AUDIOLINK_4BAND_TARGET_RATE * AUDIOLINK_WIDTH));
				
				
				float band0 = lerp(AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x, 0)).r, AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x+1, 0)).r, audiolink_saw);
				
				float band1 = lerp(AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x, 1)).r, AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x+1, 1)).r, audiolink_saw)*0.7;
				
				float band2 = lerp(AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x, 2)).r, AudioLinkData(ALPASS_AUDIOLINK + float2(audiolink_uv_x+1, 2)).r, audiolink_saw)*0.5;
								
				i.uv.y = abs((i.uv.y - 0.5) * 2) / _WaveformGain/2;
				
				band1 *= 0.85;
				band2 *= 0.70;

				float band0_waveform = 1 - smoothstep((band0_polarity * band0) * (1 - _WaveformSmoothness*0.9), (band0_polarity * band0), i.uv.y);
				float band1_waveform = 1 - smoothstep((band1_polarity * band1) * (1 - _WaveformSmoothness*0.9), (band1_polarity * band1), i.uv.y);
				float band2_waveform = 1 - smoothstep((band2_polarity * band2) * (1 - _WaveformSmoothness*0.9), (band2_polarity * band2), i.uv.y);


				c = lerp(c, fixed4( _BassColor.rgb, 1), band0_waveform);
				c = lerp(c, fixed4( _MidColor.rgb, 1), band1_waveform);
				c = lerp(c, fixed4( _HighColor.rgb, 1), band2_waveform);
				return c;
			}
			ENDCG
		}
	}
}
