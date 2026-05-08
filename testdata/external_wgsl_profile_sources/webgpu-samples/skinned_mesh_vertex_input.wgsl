struct VertexInput {
  @location(0) position: vec3f,
  @location(1) normal: vec3f,
  @location(2) texcoord: vec2f,
  @location(3) joints: vec4u,
  @location(4) weights: vec4f,
}
