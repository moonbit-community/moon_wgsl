@compute @workgroup_size(32)
fn main(@builtin(subgroup_invocation_id) id: u32) {
  let ballot: vec4<u32> = subgroupBallot(id == 0u);
  let all_value: bool = subgroupAll(true);
  let any_value: bool = subgroupAny(false);
  let add_value: u32 = subgroupAdd(id);
  let mul_value: u32 = subgroupMul(id + 1u);
  let max_value: u32 = subgroupMax(id);
  let min_value: u32 = subgroupMin(id);
  let and_value: u32 = subgroupAnd(id);
  let or_value: u32 = subgroupOr(id);
  let xor_value: u32 = subgroupXor(id);
  let ex_add: u32 = subgroupExclusiveAdd(id);
  let ex_mul: u32 = subgroupExclusiveMul(id + 1u);
  let in_add: u32 = subgroupInclusiveAdd(id);
  let in_mul: u32 = subgroupInclusiveMul(id + 1u);
  let first_value: u32 = subgroupBroadcastFirst(id);
  let broadcast_value: u32 = subgroupBroadcast(id, 0u);
  let shuffle_value: u32 = subgroupShuffle(id, id);
  let down_value: u32 = subgroupShuffleDown(id, 1u);
  let up_value: u32 = subgroupShuffleUp(id, 1u);
  let xor_shuffle_value: u32 = subgroupShuffleXor(id, 1u);
  let quad_broadcast_value: u32 = quadBroadcast(id, 0u);
  let quad_x: u32 = quadSwapX(id);
  let quad_y: u32 = quadSwapY(id);
  let quad_d: u32 = quadSwapDiagonal(id);
}
