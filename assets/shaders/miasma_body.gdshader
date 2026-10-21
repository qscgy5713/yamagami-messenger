shader_type spatial;
// 妖氣之主的身體:兩層流動的 Kenney 煙霧貼圖(世界座標投影,隨身體移動)疊出翻湧的暗紫妖氣,邊緣泛紫光。
uniform sampler2D smoke : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 dark : source_color = vec3(0.07, 0.03, 0.12);
uniform vec3 light : source_color = vec3(0.34, 0.17, 0.52);
uniform vec3 rim : source_color = vec3(0.65, 0.35, 1.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_a = wpos.xz * 0.45 + vec2(TIME * 0.06, TIME * 0.04) + vec2(wpos.y * 0.2);
	vec2 uv_b = wpos.xy * 0.55 + vec2(-TIME * 0.05, TIME * 0.07);
	float n = texture(smoke, uv_a).a * 0.55 + texture(smoke, uv_b).a * 0.45;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(dark, light, n);
	ROUGHNESS = 0.75;
	EMISSION = rim * fres * 1.6 + light * n * 0.5;
}
