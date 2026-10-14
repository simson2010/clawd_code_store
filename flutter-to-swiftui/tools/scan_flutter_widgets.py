#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scan_flutter_widgets.py — Flutter 组件清单扫描器

用途：在 Flutter → SwiftUI 迁移开始前，把目标仓库的 UI 组件资产全部盘点出来，
      为「映射到通用 SwiftUI 组件」还是「映射到公司自定义组件」的决策提供数据。

它会产出三张表：

  1. 自定义组件清单   — 项目自己定义的 StatelessWidget / StatefulWidget
  2. 系统组件用量     — 用了哪些 Flutter SDK widget，据此判断 UI 基线（Material? Cupertino?）
  3. 疑似设计系统组件 — 引用次数高 + 命名成体系的组件，这些最可能对应公司 DS

同时给出每个组件的「迁移难度信号」：
  - Stateful            → 有内部行为状态，映射到原生时行为层必须显式保留
  - 参数个数 / 是否必填 → 组件契约复杂度
  - 引用次数            → 复用广度，决定优先级（映射错了影响面有多大）

用法：
  python3 scan_flutter_widgets.py --path D:/projects/my_flutter_app
  python3 scan_flutter_widgets.py --path ./myapp --out ./mapping-out
  python3 scan_flutter_widgets.py --path ./myapp --min-refs 3

依赖：仅标准库，不需要 Dart SDK。
"""

import argparse
import csv
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

# ---------------------------------------------------------------- 正则策略

# 组件类定义。故意宽松：能容忍换行、注释、泛型。
# 除了 Stateless/Stateful，还要抓自绘与渲染型基类 —— 它们是最难迁移的一类。
RE_CLASS_DEFINE = re.compile(
    r"class\s+(?P<name>[A-Za-z_]\w*)\s*(?:<[^>]*>)?\s+extends\s+"
    r"(?P<base>StatelessWidget|StatefulWidget"
    r"|CustomPainter|CustomClipper|CustomScrollView"
    r"|SingleChildRenderObjectWidget|LeafRenderObjectWidget"
    r"|MultiChildRenderObjectWidget|RenderObjectWidget"
    r"|RenderProxyBox|RenderBox|RenderObject"
    r"|ImplicitlyAnimatedWidget|AnimatedWidget|StatefulElement)",
)

# 自绘 / 渲染型基类 —— 这类组件没有 SwiftUI 现成等价物，必须重写
SELF_RENDER_BASES = {
    "CustomPainter", "CustomClipper", "RenderObjectWidget",
    "SingleChildRenderObjectWidget", "LeafRenderObjectWidget",
    "MultiChildRenderObjectWidget", "RenderProxyBox", "RenderBox",
    "RenderObject",
}

# State<N> 类
RE_STATE_DEFINE = re.compile(r"class\s+_(?P<name>\w+)\s+extends\s+State\s*<\s*(?P<widget>\w+)")

# 构造函数参数（取第一次出现的 const X({ ... }) 或 X({ ... })）
RE_CTOR = re.compile(
    r"(?:const\s+)?%s\s*\(\s*\{(?P<params>.*?)\}\s*\)",
    re.DOTALL,
)

# 组件前缀 — 这些前缀通常标志着「公司自定义设计/基础组件」
PREFIX_HINTS = [
    "App", "DS", "Design", "Base", "Common", "Custom", "Ui", "UI",
    "Brand", "Shared", "Kit", "Standard", "Theme", "X", "Y", "Z",
]

# Flutter SDK 常见 widget，用于判断 UI 基线与第一层映射工作量
SDK_WIDGETS_MATERIAL = [
    "Scaffold", "AppBar", "MaterialApp", "Card", "FloatingActionButton",
    "ElevatedButton", "TextButton", "OutlinedButton", "BottomNavigationBar",
    "Drawer", "SnackBar", "BottomSheet", "Chip", "DataTable", "Stepper",
    "TabBar", "TabBarView", "LinearProgressIndicator", "CircularProgressIndicator",
    "Switch", "Slider", "Checkbox", "Radio", "TextField", "ListTile", "Divider",
    "NavigationBar", "SearchAnchor", "SegmentedButton", "Badge", "Tooltip",
]
SDK_WIDGETS_CUPERTINO = [
    "CupertinoApp", "CupertinoPageScaffold", "CupertinoNavigationBar",
    "CupertinoButton", "CupertinoTextField", "CupertinoSwitch", "CupertinoSlider",
    "CupertinoSegmentedControl", "CupertinoTabBar", "CupertinoTabScaffold",
    "CupertinoAlertDialog", "CupertinoActionSheet", "CupertinoPicker",
    "CupertinoActivityIndicator", "CupertinoListTile", "CupertinoSearchTextField",
]
SDK_WIDGETS_NEUTRAL = [
    "Container", "Column", "Row", "Stack", "Positioned", "Padding", "Align",
    "Center", "SizedBox", "Expanded", "Flexible", "Wrap", "ListView", "GridView",
    "CustomScrollView", "SliverList", "SingleChildScrollView", "PageView",
    "Text", "Image", "Icon", "RichText", "ClipRRect", "Opacity", "Transform",
    "DecoratedBox", "InkWell", "GestureDetector", "Hero", "AnimatedContainer",
    "RefreshIndicator", "FutureBuilder", "StreamBuilder", "LayoutBuilder",
    "MediaQuery", "Navigator", "WillPopScope", "BackdropFilter", "CustomPaint",
]

# 迁移高危信号 —— 这些出现在组件内部就意味着映射无法机械完成
HIGH_RISK_SIGNALS = {
    "CustomPainter": "自绘路径 → SwiftUI Canvas/Path 手绘",
    "CustomClipper": "自定义裁剪 → Path 或 Shape 重做",
    "BackdropFilter": "实时背景模糊 → Material / UIVisualEffectView",
    "ShaderMask": "着色器遮罩 → Metal 或降级方案",
    "RenderBox": "自绘渲染对象 → UIViewRepresentable 兜底",
    "RenderObjectWidget": "自绘渲染对象 → UIViewRepresentable 兜底",
    "MethodChannel": "平台通道 → 原生侧重写，无法自动映射",
    "ffi": "FFI 调用 → 原生桥接重写",
    "Shader": "GLSL 着色器 → Metal 重写",
    "TabBarView": "Tab 滚动联动 → TabView + 状态同步",
    "NestedScrollView": "嵌套滚动 → ScrollView 协调器重做",
    "Sliver": "Sliver 折叠效果 → SwiftUI 需手写 sticky header",
    "WebView": "内嵌网页 → WKWebView 封装",
    "GoogleMap": "地图 → MapKit 重写",
    "camera": "相机 → AVFoundation 重写",
}

# 类体里出现这些子串，说明该组件自带「行为契约」，纯视觉映射会丢东西
BODY_RISK_SIGNALS = {
    "CustomPaint": "自绘画布委托 → SwiftUI Canvas / Path 手绘",
    "CustomClipper": "自定义裁剪形状 → Shape / Path 重做",
    "ImageFilter": "模糊滤镜 → Material / UIVisualEffectView",
    "LinearGradient": "渐变 → SwiftUI LinearGradient",
    "Matrix4": "3D 变换 → CATransform3D / Rotation3DEffect",
    "Ticker": "逐帧动画 → TimelineView / CADisplayLink",
    "AnimatedBuilder": "自定义动画驱动 → Animatable / TimelineView",
    "ScrollController": "滚动位置控制 → ScrollViewReader / 偏好键",
    "PageController": "页面控制器 → TabView(selection:) 绑定",
    "TextEditingController": "文本控制器 → @State 字符串绑定",
    "FocusNode": "焦点管理 → @FocusState",
    "Timer": "定时器 → Timer / .task 生命周期需重挂",
    "SharedPreferences": "本地偏好读写 → UserDefaults / @AppStorage",
    "analytics": "埋点行为 → 迁移时需同步保留，否则数据断流",
    "track(": "埋点行为 → 迁移时需同步保留，否则数据断流",
    "logEvent": "埋点行为 → 迁移时需同步保留，否则数据断流",
    "WillPopScope": "返回拦截 → iOS 侧滑返回手势处理不同",
}


# ---------------------------------------------------------------- 扫描逻辑

def relative_project_path(path):
    """把扫描路径转成尽量相对的形式，避免输出里带上绝对路径导致不可移植。

    在项目内部 target 位于当前工作目录下时输出相对路径；否则退回原样。
    """
    p = Path(path)
    try:
        return str(p.resolve().relative_to(Path.cwd().resolve())).replace("\\", "/")
    except ValueError:
        return str(p)


def read_dart_files(project_path):
    """收集所有 .dart 文件，跳过构建产物与三方包。"""
    skip_dirs = {
        ".git", ".dart_tool", "build", ".idea", ".vscode",
        "ios", "android", "macos", "windows", "linux", "web",
        "test_driver", "Pods", "node_modules",
    }
    root = Path(project_path)
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs and not d.startswith(".")]
        for fn in filenames:
            if fn.endswith(".dart"):
                files.append(Path(dirpath) / fn)
    return files


def strip_comments(src):
    """移除 // 与 /* */ 注释，避免注释里的代码被误解析。"""
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    src = re.sub(r"//.*?$", "", src, flags=re.MULTILINE)
    # 保留字符串字面量，避免 String 里的 // 被当注释切掉
    return src


def parse_params(param_block):
    """把构造参数块解析成 [(name, required?, type)。"""
    if not param_block:
        return []
    # 去掉 {} 内部嵌套，只保留字段级声明
    lines, depth, buf = [], 0, ""
    for ch in param_block:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "," and depth == 0:
            lines.append(buf)
            buf = ""
        else:
            buf += ch
    lines.append(buf)

    out = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        required = "required" in line
        line = line.replace("required", "").strip()
        # this.xxx 形式
        m = re.match(r"(?:final\s+)?(?:(?P<type>[\w<>,?\s\[\]]+?)\s+)?(?P<name>[A-Za-z_]\w*)", line)
        if m:
            out.append((m.group("name"), required, (m.group("type") or "").strip()))
    return out


def scan(path, min_refs):
    files = read_dart_files(path)
    if not files:
        raise SystemExit(f"未在 {path} 下找到 .dart 文件，确认这是 Flutter 项目根目录吗？")

    sources = {}
    for f in files:
        try:
            sources[f] = strip_comments(f.read_text(encoding="utf-8", errors="ignore"))
        except Exception:
            continue

    all_text = "\n".join(sources.values())

    # ---- 1. 自定义组件清单
    custom = {}
    state_map = {}
    for f, src in sources.items():
        for m in RE_CLASS_DEFINE.finditer(src):
            name = m.group("name")
            if custom.get(name):
                continue
            base = m.group("base")
            body = _class_body(src, name)
            risks = {k for k in HIGH_RISK_SIGNALS if k in body}
            risks |= {k for k in BODY_RISK_SIGNALS if k in body}
            if base in SELF_RENDER_BASES:
                risks.add("__self_render__")
            custom[name] = {
                "name": name,
                "base": base,
                "stateful": base == "StatefulWidget",
                "self_render": base in SELF_RENDER_BASES,
                "file": str(f.relative_to(Path(path))).replace("\\", "/"),
                "params": parse_params(_extract_ctor(src, name)),
                "risk": sorted(risks),
            }
        for m in RE_STATE_DEFINE.finditer(src):
            state_map[m.group("widget")] = m.group("name")

    # ---- 2. 引用统计（去掉定义处那一次）
    for name, info in custom.items():
        refs = len(re.findall(rf"(?<![A-Za-z_\w]){name}\s*[\(\.]", all_text))
        info["refs"] = max(refs - 1, 0)

    # ---- 3. SDK 组件用量
    sdk_usage = Counter()
    for w in SDK_WIDGETS_MATERIAL + SDK_WIDGETS_CUPERTINO + SDK_WIDGETS_NEUTRAL:
        n = len(re.findall(rf"(?<![A-Za-z_\w]){w}\s*\(", all_text))
        if n:
            sdk_usage[w] = n

    # ---- 4. UI 基线判断
    m_count = sum(sdk_usage.get(w, 0) for w in SDK_WIDGETS_MATERIAL)
    c_count = sum(sdk_usage.get(w, 0) for w in SDK_WIDGETS_CUPERTINO)
    if c_count > m_count * 0.3:
        baseline = "Cupertino（偏原生 iOS 观感，迁移到 SwiftUI 视觉落差小）"
    elif m_count > 0:
        baseline = "Material（Material Design 观感，迁移到 SwiftUI 需要重新定性视觉）"
    else:
        baseline = "自定义为主（几乎不用 SDK 组件，说明公司有自己的组件体系）"

    # ---- 5. 疑似设计系统组件
    ds_candidates = []
    for name, info in custom.items():
        has_prefix = any(name.startswith(p) for p in PREFIX_HINTS)
        widely_used = info["refs"] >= max(min_refs, 2)
        # 放在 "widgets/" "components/" "ui/" "common/" 这类目录里也是强信号
        in_ds_dir = bool(re.search(r"/(widgets?|components?|ui|common|shared|kit|design)/", info["file"]))
        score = sum([has_prefix, widely_used, in_ds_dir, info["refs"] >= 5])
        if score >= 2:
            ds_candidates.append((score, name, info))

    ds_candidates.sort(key=lambda x: (-x[0], -x[2]["refs"]))

    return {
        # 路径尽力取相对形式，让输出可移植（拷到别的机器/目录 diff 仍然干净）
        "project": relative_project_path(path),
        "dart_files": len(sources),
        "custom_widgets": dict(sorted(custom.items(), key=lambda kv: -kv[1]["refs"])),
        "sdk_usage": dict(sdk_usage.most_common()),
        "baseline": baseline,
        "material_calls": m_count,
        "cupertino_calls": c_count,
        "ds_candidates": [(s, n, i) for s, n, i in ds_candidates],
    }


def _split_top_level_classes(src):
    """按顶层 class 切段，避免相邻类的内容互相污染。返回 [(class_name, body)]。"""
    parts = re.split(r"(?m)^class\s+", src)
    segs = []
    for p in parts[1:]:
        m = re.match(r"([A-Za-z_]\w*)", p)
        if m:
            segs.append((m.group(1), p))
    return segs


def _class_body(src, class_name):
    """取某个顶层类的完整类体，绝不溢出到下一个类。"""
    for name, body in _split_top_level_classes(src):
        # 精确匹配声明头：`class AppCard extends ...` / `class AppCard<...> ...`
        if re.match(rf"{re.escape(class_name)}\s*(?:<[^>]*>)?\s*(?:extends|implements|with|\{{)", body):
            return body
    return ""


def _extract_ctor(src, class_name):
    body = _class_body(src, class_name)
    if not body:
        return ""
    # 每次编译必须显式带上 DOTALL，否则跨行构造函数匹配不到
    pat = re.compile(RE_CTOR.pattern % re.escape(class_name), re.DOTALL)
    m = pat.search(body)
    return m.group("params") if m else ""


def _token_used(src, class_name, token):
    """判断 token 是否出现在该组件自己的类体范围内（精确切段，不溢出到相邻类）。"""
    body = _class_body(src, class_name)
    return bool(body) and token in body


def fmt_risks(info):
    """把内部风险 key 渲染成一句人话，并按「映射目标」去重，避免同一结论重复输出。"""
    if info.get("self_render"):
        return "自绘/渲染型 → 无 SwiftUI 等价物，必须重写"
    out, seen_target = [], set()
    for k in info.get("risk") or []:
        if k == "__self_render__":
            continue
        s = HIGH_RISK_SIGNALS.get(k) or BODY_RISK_SIGNALS.get(k, k)
        # 多个信号指向同一个原生方案时只说一次
        target = s.split("→")[-1].strip() if "→" in s else s
        if target in seen_target:
            continue
        seen_target.add(target)
        out.append(s)
    return "、".join(sorted(set(out))) if out else "—"


# ---------------------------------------------------------------- 输出

def write_outputs(result, out_dir, min_refs):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    cw = result["custom_widgets"]

    # --- CSV
    csv_path = out_dir / "widget_inventory.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([
            "组件名", "基类", "是否Stateful", "引用次数", "必填参数数",
            "总参数数", "参数列表", "迁移风险信号", "源码路径",
        ])
        for name, i in cw.items():
            req = sum(1 for _, r, _ in i["params"] if r)
            w.writerow([
                name, i["base"], "是" if i["stateful"] else "否", i["refs"],
                req, len(i["params"]),
                " | ".join(f"{n}{'*' if r else ''}" for n, r, _ in i["params"]),
                fmt_risks(i),
                i["file"],
            ])

    # --- Markdown 报告
    md_path = out_dir / "widget_inventory.md"
    lines = [
        "# Flutter 组件清单报告",
        "",
        f"- 扫描路径：`{result['project']}`",
        f"- Dart 文件数：**{result['dart_files']}**",
        f"- 自定义组件数：**{len(cw)}**",
        f"- **UI 基线判断**：{result['baseline']}",
        f"  - Material 调用 {result['material_calls']} 次 / Cupertino 调用 {result['cupertino_calls']} 次",
        "",
        "## 一、疑似设计系统组件（优先处理）",
        "",
        "这些组件是公司自有组件库的核心，迁移时应优先确认公司 iOS DS 里有没有对应物。",
        "",
        "| 组件 | 引用次数 | 基类 | 必填/总参数 | 危险信号 | 路径 |",
        "|---|---|---|---|---|---|",
    ]
    for score, name, i in result["ds_candidates"]:
        req = sum(1 for _, r, _ in i["params"] if r)
        lines.append(
            f"| `{name}` | {i['refs']} | {'Stateful' if i['stateful'] else 'Stateless'} "
            f"| {req}/{len(i['params'])} | {fmt_risks(i)} | `{i['file']}` |"
        )

    lines += [
        "",
        "## 二、全部自定义组件（按引用次数降序）",
        "",
        "| 组件 | 基类 | 引用 | 必填/总参数 | 危险信号 |",
        "|---|---|---|---|---|",
    ]
    for name, i in cw.items():
        if i["refs"] < min_refs:
            continue
        req = sum(1 for _, r, _ in i["params"] if r)
        base = i["base"] + (" ·自绘" if i.get("self_render") else "")
        lines.append(
            f"| `{name}` | {base} | {i['refs']} "
            f"| {req}/{len(i['params'])} | {fmt_risks(i)} |"
        )

    lines += [
        "",
        "## 三、Flutter SDK 组件用量",
        "",
        "| Widget | 出现次数 |",
        "|---|---|",
    ]
    for w_, n in result["sdk_usage"].items():
        lines.append(f"| `{w_}` | {n} |")

    lines += ["", "（完整数据见 `widget_inventory.csv`，原始 JSON 见 `widget_inventory.json`）", ""]
    md_path.write_text("\n".join(lines), encoding="utf-8")

    # --- JSON
    json_path = out_dir / "widget_inventory.json"
    serializable = {
        "project": result["project"],
        "dart_files": result["dart_files"],
        "baseline": result["baseline"],
        "custom_widgets": {k: dict(v) for k, v in cw.items()},
        "sdk_usage": result["sdk_usage"],
        "ds_candidates": [n for _, n, _ in result["ds_candidates"]],
    }
    json_path.write_text(json.dumps(serializable, ensure_ascii=False, indent=2), encoding="utf-8")

    return csv_path, md_path, json_path


def main():
    ap = argparse.ArgumentParser(description="扫描 Flutter 项目，产出 UI 组件迁移清单")
    ap.add_argument("--path", required=True, help="Flutter 项目根目录")
    ap.add_argument("--out", default="./mapping-out", help="输出目录，默认 ./mapping-out")
    ap.add_argument("--min-refs", type=int, default=0, help="Markdown 中隐藏引用次数低于该值的组件")
    ap.add_argument("--json-only", action="store_true", help="只输出 JSON，不写 CSV/MD")
    args = ap.parse_args()

    result = scan(args.path, args.min_refs)

    if args.json_only:
        print(json.dumps({
            k: (v if not isinstance(v, dict) else {kk: vv for kk, vv in v.items()})
            for k, v in result.items() if k != "ds_candidates"
        }, ensure_ascii=False, indent=2))
        return

    csv_path, md_path, json_path = write_outputs(result, args.out, args.min_refs)

    print(f"Dart 文件数      : {result['dart_files']}")
    print(f"自定义组件数      : {len(result['custom_widgets'])}")
    print(f"UI 基线          : {result['baseline']}")
    print(f"疑似 DS 组件      : {len(result['ds_candidates'])} 个")
    for s, n, i in result["ds_candidates"][:10]:
        print(f"   - {n}  (引用 {i['refs']} 次, {'Stateful' if i['stateful'] else 'Stateless'})")
    print("")
    print(f"CSV  : {csv_path}")
    print(f"MD   : {md_path}")
    print(f"JSON : {json_path}")


if __name__ == "__main__":
    main()
