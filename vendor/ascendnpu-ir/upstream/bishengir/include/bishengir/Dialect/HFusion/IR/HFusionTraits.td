//===- HFusionTraits.td - HFusion library ops --------------*- tablegen -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//===----------------------------------------------------------------------===//
//
// Traits used by HFusion ops.
//
//===----------------------------------------------------------------------===//
#ifndef BISHENGIR_DIALECT_HFUSION_IR_HFUSIONTRAITS_TD
#define BISHENGIR_DIALECT_HFUSION_IR_HFUSIONTRAITS_TD

include "mlir/IR/OpBase.td"

/// Currently only attached to manually defined structured ops. However this may
/// be attached to HFusionStructuredBase_Op if suitable.
def ResultOnlyIfTensor
    : PredOpTrait<"Result must only exist if using tensor semantics",
                  CPred<"($_op.getNumResults() == 0) ^ "
                        "(cast<DestinationStyleOpInterface>(&$_op)."
                        "hasPureTensorSemantics())">>;

/// Check to make sure that `attr` is less than the rank of `shaped`. Used for
/// GatherOp.
class AttrWithinRankOf<string attr, string shaped>
    : PredOpTrait<attr#" must be less than rank of "#shaped,
                  CPred<"$" # attr # " < static_cast<uint64_t>(cast<ShapedType>"
                        # "($" # shaped # ".getType()).getRank())">>;

#endif // BISHENGIR_DIALECT_HFUSION_IR_HFUSIONTRAITS_TD
