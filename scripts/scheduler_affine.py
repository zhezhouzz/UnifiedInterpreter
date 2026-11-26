from xdsl.ir.affine import AffineBinaryOpExpr, AffineBinaryOpKind, AffineConstantExpr, AffineDimExpr, AffineSymExpr
from xdsl.parser.affine_parser import AffineParser


class SemiAffine(AffineParser):
    def _create_binop_expr(self, lhs, rhs, binop):
        # 保留布局中的半仿射运算，避免 xDSL 在符号操作数上执行常量化简。
        kinds = {kind.get_token(): kind for kind in AffineBinaryOpKind}
        if binop.text in ("*", "mod", "ceildiv", "floordiv"):
            return AffineBinaryOpExpr(kinds[binop.text], lhs, rhs)
        return super()._create_binop_expr(lhs, rhs, binop)


class SemiAffineMaps:
    def parse_affine_map(self):
        return SemiAffine(self._parser_state).parse_affine_map()


def affine(expr):
    if isinstance(expr, AffineConstantExpr):
        return expr.value
    if isinstance(expr, AffineDimExpr):
        return ["d", expr.position]
    if isinstance(expr, AffineSymExpr):
        return ["s", expr.position]
    return [expr.kind.get_token(), affine(expr.lhs), affine(expr.rhs)]


def strided_layout(mapping):
    if len(mapping.results) != 1:
        return None
    def linear(expr):
        if isinstance(expr, AffineConstantExpr):
            return expr.value, {}
        if isinstance(expr, AffineSymExpr):
            return None, {}
        if isinstance(expr, AffineDimExpr):
            return 0, {expr.position: 1}
        left, right = linear(expr.lhs), linear(expr.rhs)
        if left is None or right is None:
            return None
        a, xs = left
        b, ys = right
        def plus(x, y):
            return None if x is None or y is None else x + y
        def times(x, y):
            if x == 0 or y == 0:
                return 0
            return None if x is None or y is None else x * y
        if expr.kind.get_token() == "+":
            return plus(a, b), {i: plus(xs.get(i, 0), ys.get(i, 0)) for i in xs.keys() | ys.keys()}
        if expr.kind.get_token() == "*" and not (xs and ys):
            return times(a, b), {**{i: times(v, b) for i,v in xs.items()}, **{i: times(v, a) for i,v in ys.items()}}
        return None
    result = linear(mapping.results[0])
    if result is None:
        return None
    offset, coeffs = result
    return dict(layout="strided", offset=offset, strides=[coeffs.get(i, 0) for i in range(mapping.num_dims)])
