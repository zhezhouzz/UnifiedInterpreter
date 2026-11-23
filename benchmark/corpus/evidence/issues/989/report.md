Dual B8 gather lowering currently rejects ave.hir.pge <H> when its width attribute is missing. The number of enabled lanes depends on predicate granularity: 128 for B8, 64 for B16, and 32 for B32. The vector type alone does not determine this granularity.

AnalyzeVectorLayout can derive predicate granularity from consumer constraints, but it runs after VectorToHIVMAVE, where the original mask must already be split into even and odd predicates.

Explore the possibility of inferring the original predicate width from consumer constraints before splitting gather. Accept `H` when the width is determined unambiguously.