### 环境信息
            
Main branch
### 🐛 问题描述
            
Rule 2 of MergeCVScope.cpp merges scopes based on IR adjacency instead of the dependency graph, causing significant performance degradation.

```
for (Operation &op :
         llvm::make_early_inc_range(outerScope.getRegion().front())) {
      if (op.hasTrait<OpTrait::IsTerminator>())
        break;
      auto current = dyn_cast<ScopeOp>(&op);
      auto currCore = current ? getScopeCoreType(current) : std::nullopt;
      if (!current || !isEligibleForCoreMerge(current) || !currCore) {
        previous = ScopeOp();
        continue;
      }

      if (previous) {
        auto prevCore = getScopeCoreType(previous);
        if (prevCore && areCompatibleCoreTypes(*prevCore, *currCore)) {
          if (ScopeOp merged = mergeScopes(previous, current, current)) {
            previous = merged;
            changed = true;
            continue;
          }
        }
      }
      previous = current;
    }
  ```
