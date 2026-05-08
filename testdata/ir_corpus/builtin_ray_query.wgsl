enable wgpu_ray_query;

@group(0) @binding(0)
var tlas: acceleration_structure;

fn ray_func() -> f32 {
  var rq: ray_query;
  let desc: RayDesc = RayDesc(0u, 255u, 0.0001f, 100000f, vec3f(0f, 0f, 0f), vec3f(1f, 0f, 0f));
  rayQueryInitialize(&rq, tlas, desc);
  rayQueryProceed(&rq);
  let candidate: RayIntersection = rayQueryGetCandidateIntersection(&rq);
  rayQueryGenerateIntersection(&rq, 1.0f);
  rayQueryConfirmIntersection(&rq);
  let committed: RayIntersection = rayQueryGetCommittedIntersection(&rq);
  rayQueryTerminate(&rq);
  return candidate.t + committed.t;
}

fn main() -> f32 {
  return ray_func();
}
