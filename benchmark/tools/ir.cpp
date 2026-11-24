// Parse HIVM with the same dialect registries as bishengir-opt.
#include "bishengir/InitAllDialects.h"
#include "mlir/InitAllDialects.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Parser/Parser.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/MemoryBuffer.h"
using namespace mlir;

template <typename T> static std::string printed(T item) {
  std::string result;
  llvm::raw_string_ostream out(result);
  item.print(out);
  return result;
}

static llvm::json::Object describe(Operation *op, llvm::DenseMap<Value, int64_t> &ids) {
  llvm::json::Object attrs;
  if (auto props = dyn_cast_or_null<DictionaryAttr>(op->getPropertiesAsAttribute()))
    for (NamedAttribute a : props) attrs[a.getName().str()] = printed(a.getValue());
  for (NamedAttribute a : op->getAttrs()) attrs[a.getName().str()] = printed(a.getValue());
  llvm::json::Array args, results, types, regions, resultTypes, regionArgs;
  auto idOf = [&](Value v) { return ids.try_emplace(v, ids.size()).first->second; };
  for (Value v : op->getOperands()) {
    args.push_back(idOf(v));
    types.push_back(printed(v.getType()));
  }
  for (Value v : op->getResults()) {
    results.push_back(idOf(v));
    resultTypes.push_back(printed(v.getType()));
  }
  for (Region &region : op->getRegions()) {
    llvm::json::Array blocks, blockArgs;
    for (Block &block : region) {
      llvm::json::Array arguments;
      for (BlockArgument arg : block.getArguments()) {
        arguments.push_back(llvm::json::Object{{"id", idOf(arg)}, {"type", printed(arg.getType())}});
      }
      blockArgs.push_back(std::move(arguments));
      llvm::json::Array ops;
      for (Operation &child : block) ops.push_back(describe(&child, ids));
      blocks.push_back(std::move(ops));
    }
    regions.push_back(std::move(blocks));
    regionArgs.push_back(std::move(blockArgs));
  }
  return llvm::json::Object{{"op", op->getName().getStringRef()}, {"attrs", std::move(attrs)},
    {"loc", printed(op->getLoc())}, {"args", std::move(args)}, {"results", std::move(results)},
    {"types", std::move(types)}, {"resultTypes", std::move(resultTypes)},
    {"regionArgs", std::move(regionArgs)}, {"regions", std::move(regions)}};
}
int main() {
  DialectRegistry registry;
  mlir::registerAllDialects(registry);
  bishengir::registerAllDialects(registry);
  MLIRContext ctx(registry);
  ctx.allowUnregisteredDialects();
  auto input = llvm::MemoryBuffer::getSTDIN();
  if (!input) return 1;
  llvm::SourceMgr src;
  src.AddNewSourceBuffer(std::move(*input), llvm::SMLoc());
  auto module = parseSourceFile<ModuleOp>(src, &ctx);
  if (!module) return 1;
  llvm::DenseMap<Value, int64_t> ids;
  llvm::outs() << llvm::json::Value(describe(*module, ids)) << "\n";
}
