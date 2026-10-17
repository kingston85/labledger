// Expression engine: parses text like "x^3 - 2x + sin(pi*x)/3" into a tree
// that can be evaluated quickly many times with different variable values.
//
// Supports + - * / ^ (right-associative), unary minus, parentheses,
// implicit multiplication (2x, 3(x+1), (x+1)(x-1), 2 sin(x)),
// constants pi and e, scientific notation (1.5e-3) and common functions.

import 'dart:math' as math;

class ExprError implements Exception {
  final String message;
  final int position;
  ExprError(this.message, [this.position = -1]);
  @override
  String toString() => message;
}

abstract class Node {
  double eval(Map<String, double> vars);
}

class _Num extends Node {
  final double v;
  _Num(this.v);
  @override
  double eval(Map<String, double> vars) => v;
}

class _Var extends Node {
  final String name;
  _Var(this.name);
  @override
  double eval(Map<String, double> vars) {
    final v = vars[name];
    if (v == null) throw ExprError('No value for "$name"');
    return v;
  }
}

class _Neg extends Node {
  final Node a;
  _Neg(this.a);
  @override
  double eval(Map<String, double> vars) => -a.eval(vars);
}

class _Bin extends Node {
  final String op;
  final Node a, b;
  _Bin(this.op, this.a, this.b);
  @override
  double eval(Map<String, double> vars) {
    final x = a.eval(vars);
    final y = b.eval(vars);
    switch (op) {
      case '+':
        return x + y;
      case '-':
        return x - y;
      case '*':
        return x * y;
      case '/':
        return x / y;
      case '^':
        return _pow(x, y);
    }
    throw ExprError('Unknown operator $op');
  }

  static double _pow(double x, double y) {
    if (x < 0 && y != y.roundToDouble()) {
      // Real odd roots of negatives, e.g. (-8)^(1/3) = -2.
      final inv = 1 / y;
      if ((inv - inv.round()).abs() < 1e-9 && inv.round().isOdd) {
        return -math.pow(-x, y).toDouble();
      }
    }
    return math.pow(x, y).toDouble();
  }
}

class _Fn extends Node {
  final String name;
  final List<Node> args;
  _Fn(this.name, this.args);
  @override
  double eval(Map<String, double> vars) {
    final v = [for (final a in args) a.eval(vars)];
    return Functions.apply(name, v);
  }
}

class Functions {
  Functions._();

  static const Map<String, int> arity = {
    'sin': 1, 'cos': 1, 'tan': 1, 'asin': 1, 'acos': 1, 'atan': 1,
    'sinh': 1, 'cosh': 1, 'tanh': 1, 'exp': 1, 'ln': 1, 'log': 1, 'log10': 1,
    'log2': 1, 'sqrt': 1, 'cbrt': 1, 'abs': 1, 'floor': 1, 'ceil': 1,
    'round': 1, 'sign': 1, 'sec': 1, 'csc': 1, 'cot': 1,
    'atan2': 2, 'min': 2, 'max': 2, 'pow': 2, 'mod': 2,
  };

  static double apply(String f, List<double> a) {
    final x = a.isNotEmpty ? a[0] : double.nan;
    switch (f) {
      case 'sin':
        return math.sin(x);
      case 'cos':
        return math.cos(x);
      case 'tan':
        return math.tan(x);
      case 'sec':
        return 1 / math.cos(x);
      case 'csc':
        return 1 / math.sin(x);
      case 'cot':
        return 1 / math.tan(x);
      case 'asin':
        return math.asin(x);
      case 'acos':
        return math.acos(x);
      case 'atan':
        return math.atan(x);
      case 'sinh':
        return (math.exp(x) - math.exp(-x)) / 2;
      case 'cosh':
        return (math.exp(x) + math.exp(-x)) / 2;
      case 'tanh':
        final e2 = math.exp(2 * x);
        return e2.isInfinite ? 1.0 : (e2 - 1) / (e2 + 1);
      case 'exp':
        return math.exp(x);
      case 'ln':
        return math.log(x);
      case 'log':
      case 'log10':
        return math.log(x) / math.ln10;
      case 'log2':
        return math.log(x) / math.ln2;
      case 'sqrt':
        return math.sqrt(x);
      case 'cbrt':
        return x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
      case 'abs':
        return x.abs();
      case 'floor':
        return x.floorToDouble();
      case 'ceil':
        return x.ceilToDouble();
      case 'round':
        return x.roundToDouble();
      case 'sign':
        return x.sign;
      case 'atan2':
        return math.atan2(a[0], a[1]);
      case 'min':
        return math.min(a[0], a[1]);
      case 'max':
        return math.max(a[0], a[1]);
      case 'pow':
        return _Bin._pow(a[0], a[1]);
      case 'mod':
        return a[0] % a[1];
    }
    throw ExprError('Unknown function "$f"');
  }
}

enum _T { num, id, op, lp, rp, comma, end }

class _Tok {
  final _T t;
  final String s;
  final int pos;
  _Tok(this.t, this.s, this.pos);
}

List<_Tok> _lex(String src) {
  final out = <_Tok>[];
  var i = 0;
  bool isDigit(int c) => c >= 48 && c <= 57;
  bool isAlpha(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  while (i < src.length) {
    final c = src.codeUnitAt(i);
    final ch = src[i];
    if (ch == ' ' || ch == '\t') {
      i++;
    } else if (isDigit(c) || (ch == '.' && i + 1 < src.length && isDigit(src.codeUnitAt(i + 1)))) {
      final start = i;
      while (i < src.length && (isDigit(src.codeUnitAt(i)) || src[i] == '.')) {
        i++;
      }
      // Scientific notation: 1.5e-3, 2E6 (but not "2e" followed by a letter like "2exp").
      if (i < src.length && (src[i] == 'e' || src[i] == 'E')) {
        var j = i + 1;
        if (j < src.length && (src[j] == '+' || src[j] == '-')) j++;
        if (j < src.length && isDigit(src.codeUnitAt(j))) {
          i = j;
          while (i < src.length && isDigit(src.codeUnitAt(i))) {
            i++;
          }
        }
      }
      final text = src.substring(start, i);
      if (double.tryParse(text) == null) throw ExprError('Bad number "$text"', start);
      out.add(_Tok(_T.num, text, start));
    } else if (isAlpha(c)) {
      final start = i;
      while (i < src.length && (isAlpha(src.codeUnitAt(i)) || isDigit(src.codeUnitAt(i)))) {
        i++;
      }
      out.add(_Tok(_T.id, src.substring(start, i), start));
    } else if ('+-*/^'.contains(ch)) {
      out.add(_Tok(_T.op, ch, i));
      i++;
    } else if (ch == '×' || ch == '·') {
      out.add(_Tok(_T.op, '*', i));
      i++;
    } else if (ch == '÷') {
      out.add(_Tok(_T.op, '/', i));
      i++;
    } else if (ch == '−') {
      out.add(_Tok(_T.op, '-', i));
      i++;
    } else if (ch == '(' || ch == '[') {
      out.add(_Tok(_T.lp, '(', i));
      i++;
    } else if (ch == ')' || ch == ']') {
      out.add(_Tok(_T.rp, ')', i));
      i++;
    } else if (ch == ',') {
      out.add(_Tok(_T.comma, ',', i));
      i++;
    } else if (ch == 'π') {
      out.add(_Tok(_T.id, 'pi', i));
      i++;
    } else {
      throw ExprError('Unexpected "$ch"', i);
    }
  }
  out.add(_Tok(_T.end, '', src.length));
  return out;
}

class _Parser {
  final List<_Tok> toks;
  final Set<String> allowed;
  final Set<String> used = {};
  int i = 0;
  _Parser(this.toks, this.allowed);

  _Tok get peek => toks[i];
  _Tok next() => toks[i++];

  Node parse() {
    final n = _sum();
    if (peek.t != _T.end) throw ExprError('Unexpected "${peek.s}"', peek.pos);
    return n;
  }

  Node _sum() {
    var n = _product();
    while (peek.t == _T.op && (peek.s == '+' || peek.s == '-')) {
      final op = next().s;
      n = _Bin(op, n, _product());
    }
    return n;
  }

  bool _startsFactor(_Tok t) => t.t == _T.num || t.t == _T.id || t.t == _T.lp;

  Node _product() {
    var n = _unary();
    while (true) {
      if (peek.t == _T.op && (peek.s == '*' || peek.s == '/')) {
        final op = next().s;
        n = _Bin(op, n, _unary());
      } else if (_startsFactor(peek)) {
        // Implicit multiplication: 2x, 2(x+1), (a)(b), x sin(x)
        n = _Bin('*', n, _power());
      } else {
        return n;
      }
    }
  }

  Node _unary() {
    if (peek.t == _T.op && peek.s == '-') {
      next();
      return _Neg(_unary());
    }
    if (peek.t == _T.op && peek.s == '+') {
      next();
      return _unary();
    }
    return _power();
  }

  Node _power() {
    final base = _atom();
    if (peek.t == _T.op && peek.s == '^') {
      next();
      return _Bin('^', base, _unary()); // right-associative, allows 2^-x
    }
    return base;
  }

  Node _atom() {
    final t = next();
    switch (t.t) {
      case _T.num:
        return _Num(double.parse(t.s));
      case _T.lp:
        final n = _sum();
        if (peek.t != _T.rp) throw ExprError('Missing ")"', peek.pos);
        next();
        return n;
      case _T.id:
        final name = t.s;
        if (Functions.arity.containsKey(name) && peek.t == _T.lp) {
          next();
          final args = <Node>[_sum()];
          while (peek.t == _T.comma) {
            next();
            args.add(_sum());
          }
          if (peek.t != _T.rp) throw ExprError('Missing ")" after $name(', peek.pos);
          next();
          if (args.length != Functions.arity[name]) {
            throw ExprError('$name needs ${Functions.arity[name]} argument(s)', t.pos);
          }
          return _Fn(name, args);
        }
        if (Functions.arity.containsKey(name)) {
          // Allow "sin x" style with a single following factor.
          if (_startsFactor(peek)) return _Fn(name, [_power()]);
          throw ExprError('$name needs ( )', t.pos);
        }
        if (name == 'pi') return _Num(math.pi);
        if (name == 'e') return _Num(math.e);
        if (allowed.contains(name)) {
          used.add(name);
          return _Var(name);
        }
        // Split run-together variables like "xy" or "tx" when every letter is allowed.
        if (name.split('').every(allowed.contains)) {
          Node n = _Var(name[0]);
          used.add(name[0]);
          for (final ch in name.substring(1).split('')) {
            used.add(ch);
            n = _Bin('*', n, _Var(ch));
          }
          return n;
        }
        throw ExprError('Unknown name "$name"', t.pos);
      default:
        throw ExprError(t.t == _T.end ? 'Expression is incomplete' : 'Unexpected "${t.s}"', t.pos);
    }
  }
}

/// A parsed expression ready to evaluate.
class Expr {
  final String source;
  final Node _root;
  final Set<String> variables;
  Expr._(this.source, this._root, this.variables);

  static Expr parse(String source, {Set<String> vars = const {'x'}}) {
    final src = source.trim();
    if (src.isEmpty) throw ExprError('Enter an expression');
    final p = _Parser(_lex(src), vars);
    final root = p.parse();
    return Expr._(src, root, p.used);
  }

  static Expr? tryParse(String source, {Set<String> vars = const {'x'}}) {
    try {
      return parse(source, vars: vars);
    } catch (_) {
      return null;
    }
  }

  double eval([Map<String, double> values = const {}]) => _root.eval(values);

  /// Convenience for one-variable functions.
  double at(double x, [String name = 'x']) => _root.eval({name: x});

  double Function(double) fn([String name = 'x']) {
    final m = <String, double>{};
    return (double v) {
      m[name] = v;
      return _root.eval(m);
    };
  }
}

/// Evaluates a plain numeric expression like "2*pi/3" or "1e-6"; null if invalid.
double? evalNumber(String text) {
  try {
    final v = Expr.parse(text, vars: const {}).eval();
    return v.isFinite ? v : null;
  } catch (_) {
    return null;
  }
}

/// Short number formatting used throughout the app.
String fmt(double v, {int sig = 8}) {
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v > 0 ? '∞' : '−∞';
  if (v == 0) return '0';
  final a = v.abs();
  if (a >= 1e7 || a < 1e-5) {
    final s = v.toStringAsExponential(sig - 1);
    final parts = s.split('e');
    var mant = parts[0];
    if (mant.contains('.')) {
      mant = mant.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    final exp = int.parse(parts[1]);
    return '$mant×10${_sup(exp)}';
  }
  var s = v.toStringAsPrecision(sig);
  if (s.contains('e')) s = v.toString();
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

String _sup(int n) {
  const d = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  final s = n.abs().toString().split('').map((c) => d[int.parse(c)]).join();
  return n < 0 ? '⁻$s' : s;
}
