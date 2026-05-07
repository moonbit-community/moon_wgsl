// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This package ports the data model of Naga's shader IR. Naga is licensed
// under MIT OR Apache-2.0 by the gfx-rs authors.

///|
pub(all) struct Handle {
  index : Int
} derive(Eq, Debug)

///|
pub fn Handle::Handle(index : Int) -> Handle {
  Handle::{ index, }
}

///|
pub fn Handle::index(self : Handle) -> Int {
  self.index
}

///|
pub(all) struct HandleRange {
  start : Handle
  end : Handle
} derive(Eq, Debug)

///|
pub fn HandleRange::HandleRange(start : Handle, end : Handle) -> HandleRange {
  HandleRange::{ start, end }
}

///|
pub(all) struct StorageAccess {
  bits : Int
} derive(Eq, Debug)

///|
pub fn StorageAccess::empty() -> StorageAccess {
  StorageAccess::{ bits: 0 }
}

///|
pub fn StorageAccess::load() -> StorageAccess {
  StorageAccess::{ bits: 1 }
}

///|
pub fn StorageAccess::store() -> StorageAccess {
  StorageAccess::{ bits: 2 }
}

///|
pub fn StorageAccess::atomic_access() -> StorageAccess {
  StorageAccess::{ bits: 4 }
}

///|
pub fn StorageAccess::union(
  self : StorageAccess,
  other : StorageAccess,
) -> StorageAccess {
  StorageAccess::{ bits: self.bits | other.bits }
}

///|
pub fn StorageAccess::contains(
  self : StorageAccess,
  other : StorageAccess,
) -> Bool {
  (self.bits & other.bits) == other.bits
}

///|
pub(all) struct MemoryDecorations {
  bits : Int
} derive(Eq, Debug)

///|
pub fn MemoryDecorations::empty() -> MemoryDecorations {
  MemoryDecorations::{ bits: 0 }
}

///|
pub fn MemoryDecorations::coherent() -> MemoryDecorations {
  MemoryDecorations::{ bits: 1 }
}

///|
pub fn MemoryDecorations::volatile_decoration() -> MemoryDecorations {
  MemoryDecorations::{ bits: 2 }
}

///|
pub fn MemoryDecorations::union(
  self : MemoryDecorations,
  other : MemoryDecorations,
) -> MemoryDecorations {
  MemoryDecorations::{ bits: self.bits | other.bits }
}

///|
pub(all) struct Barrier {
  bits : Int
} derive(Eq, Debug)

///|
pub fn Barrier::empty() -> Barrier {
  Barrier::{ bits: 0 }
}

///|
pub fn Barrier::storage() -> Barrier {
  Barrier::{ bits: 1 }
}

///|
pub fn Barrier::work_group() -> Barrier {
  Barrier::{ bits: 2 }
}

///|
pub fn Barrier::sub_group() -> Barrier {
  Barrier::{ bits: 4 }
}

///|
pub fn Barrier::texture() -> Barrier {
  Barrier::{ bits: 8 }
}

///|
pub fn Barrier::union(self : Barrier, other : Barrier) -> Barrier {
  Barrier::{ bits: self.bits | other.bits }
}

///|
pub(all) struct RayFlag {
  bits : Int
} derive(Eq, Debug)

///|
pub fn RayFlag::empty() -> RayFlag {
  RayFlag::{ bits: 0 }
}

///|
pub fn RayFlag::force_opaque() -> RayFlag {
  RayFlag::{ bits: 1 }
}

///|
pub fn RayFlag::force_no_opaque() -> RayFlag {
  RayFlag::{ bits: 2 }
}

///|
pub fn RayFlag::terminate_on_first_hit() -> RayFlag {
  RayFlag::{ bits: 4 }
}

///|
pub fn RayFlag::skip_closest_hit_shader() -> RayFlag {
  RayFlag::{ bits: 8 }
}

///|
pub fn RayFlag::cull_back_facing() -> RayFlag {
  RayFlag::{ bits: 0x10 }
}

///|
pub fn RayFlag::cull_front_facing() -> RayFlag {
  RayFlag::{ bits: 0x20 }
}

///|
pub fn RayFlag::cull_opaque() -> RayFlag {
  RayFlag::{ bits: 0x40 }
}

///|
pub fn RayFlag::cull_no_opaque() -> RayFlag {
  RayFlag::{ bits: 0x80 }
}

///|
pub fn RayFlag::skip_triangles() -> RayFlag {
  RayFlag::{ bits: 0x100 }
}

///|
pub fn RayFlag::skip_aabbs() -> RayFlag {
  RayFlag::{ bits: 0x200 }
}

///|
pub fn RayFlag::union(self : RayFlag, other : RayFlag) -> RayFlag {
  RayFlag::{ bits: self.bits | other.bits }
}
