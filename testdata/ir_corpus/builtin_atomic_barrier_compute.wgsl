var<workgroup> counter: atomic<i32>;

@group(0) @binding(0)
var<storage, read_write> output: array<i32>;

@compute @workgroup_size(1)
fn main(@builtin(local_invocation_index) idx: u32) {
  atomicStore(&counter, 1i);
  workgroupBarrier();
  let a: i32 = atomicLoad(&counter);
  let b: i32 = atomicAdd(&counter, 2i);
  let c: i32 = atomicSub(&counter, 1i);
  let d: i32 = atomicMax(&counter, 8i);
  let e: i32 = atomicMin(&counter, -1i);
  let f: i32 = atomicAnd(&counter, 15i);
  let g: i32 = atomicOr(&counter, 16i);
  let h: i32 = atomicXor(&counter, 3i);
  let i: i32 = atomicExchange(&counter, 9i);
  let j = atomicCompareExchangeWeak(&counter, 9i, 10i);
  storageBarrier();
  textureBarrier();
  output[idx] = a + b + c + d + e + f + g + h + i + j.old_value + select(0i, 1i, j.exchanged);
}
