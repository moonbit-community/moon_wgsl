enable wgpu_ray_query;
enable wgpu_ray_query_vertex_return;

@group(0) @binding(0)
var tlas: acceleration_structure<vertex_return>;

fn ray_func() -> f32 {
  var rq: ray_query<vertex_return>;
  let desc: RayDesc = RayDesc(0u, 255u, 0.0001f, 100000f, vec3f(0f, 0f, 0f), vec3f(1f, 0f, 0f));
  rayQueryInitialize(&rq, tlas, desc);
  rayQueryProceed(&rq);
  let candidate: RayIntersection = rayQueryGetCandidateIntersection(&rq);
  rayQueryGenerateIntersection(&rq, 1.0f);
  rayQueryConfirmIntersection(&rq);
  let committed: RayIntersection = rayQueryGetCommittedIntersection(&rq);
  let candidate_positions: array<vec3f, 3> = getCandidateHitVertexPositions(&rq);
  let positions: array<vec3f, 3> = getCommittedHitVertexPositions(&rq);
  rayQueryTerminate(&rq);
  return candidate.t + committed.t + candidate_positions[1].y + positions[0].x;
}

fn main() -> f32 {
  return ray_func();
}
