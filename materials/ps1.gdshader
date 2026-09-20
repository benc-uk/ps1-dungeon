shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Opaque, mesh-UV material. Snap size is measured before window upscaling.
// For one texture repeat per face: UV scale (3, 2) on BoxMesh, (1, 1) on PlaneMesh.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec3 albedo_tint : source_color = vec3(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float affine_strength : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float snap_pixels : hint_range(0.0, 8.0, 0.25) = 1.0;

// Camera-depth floor in world units: soften close-up warping and keep UV weights positive.
const float AFFINE_MIN_DEPTH = 1.0;

varying vec3 affine_uv;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	UV = UV * uv_scale + uv_offset;

	// Raw W can be zero/negative on clipped triangles, sending UVs outside the face.
	// Positive weights keep UVs bounded; beyond the depth floor this is fully affine.
	float affine_weight = max(clip_position.w, AFFINE_MIN_DEPTH);
	affine_uv = vec3(UV * affine_weight, affine_weight);

	// Avoid division at/behind the eye, and leave shadow-map geometry unsnapped.
	if (snap_pixels > 0.0 && clip_position.w > 0.0001 && !IN_SHADOW_PASS) {
		vec2 snap_grid = max(VIEWPORT_SIZE / snap_pixels, vec2(1.0));
		vec2 screen_position = (clip_position.xy / clip_position.w * 0.5 + 0.5) * snap_grid;
		screen_position = floor(screen_position + 0.5);
		clip_position.xy = (screen_position / snap_grid * 2.0 - 1.0) * clip_position.w;
	}

	POSITION = clip_position;
}

void fragment() {
	vec2 warped_uv = affine_uv.xy / max(affine_uv.z, 0.00001);
	vec2 texture_uv = mix(UV, warped_uv, affine_strength);
	ALBEDO = texture(albedo_texture, texture_uv).rgb * albedo_tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
