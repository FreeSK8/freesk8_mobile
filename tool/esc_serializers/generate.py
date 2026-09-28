#!/usr/bin/env python3
"""Generate the Dart ESC configuration serializers from vendored VESC firmware sources.

For every firmware version listed in versions.json this tool reads the vendored
confgenerator.c / confgenerator.h / datatypes.h (tool/esc_serializers/vesc/<label>/)
and emits lib/hardwareSupport/escHelper/serialization/<file> with a class that
reads and writes MCCONF (motor configuration) and APPCONF (app configuration)
byte-for-byte the way the firmware does. It also emits a layout table per
version under tool/esc_serializers/layouts/ that the unit tests check against.

Usage:
  python3 tool/esc_serializers/generate.py            # write generated files
  python3 tool/esc_serializers/generate.py --check    # fail if files are stale
  python3 tool/esc_serializers/generate.py --out DIR  # write to DIR instead

Only the Python standard library is used.
"""
from __future__ import annotations

import argparse
import difflib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOOL = pathlib.Path(__file__).resolve().parent
DART_DIR = ROOT / "lib" / "hardwareSupport" / "escHelper"
OUT_DIR = DART_DIR / "serialization"
LAYOUT_DIR = TOOL / "layouts"

WIDTH = {"byte": 1, "uint16": 2, "int16": 2, "uint32": 4, "int32": 4,
         "float16": 2, "float32": 4, "float32_auto": 4}

# Struct types the config structs are made of, and how many bytes the C side
# considers them (only used to classify a `buffer[ind++]` byte).
INT_TYPES = {"uint8_t", "int8_t", "unsigned char", "char", "int", "uint16_t",
             "int16_t", "uint32_t", "int32_t", "systime_t"}


class GenError(Exception):
    pass


# --------------------------------------------------------------------------- C parsing

def strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//[^\n]*", "", src)
    return src


def parse_enums(src: str) -> dict[str, list[tuple[str, int]]]:
    """typedef enum { A, B = 3, ... } name;  ->  {name: [(A, 0), (B, 3), ...]}"""
    enums = {}
    for m in re.finditer(r"typedef\s+enum\s*\{(.*?)\}\s*(\w+)\s*;", src, re.S):
        body, name = m.group(1), m.group(2)
        members, value = [], 0
        for raw in body.split(","):
            item = raw.strip()
            if not item or item.startswith("#"):
                continue
            if "=" in item:
                ident, expr = [x.strip() for x in item.split("=", 1)]
                value = int(expr.replace("(", "").replace(")", ""), 0)
            else:
                ident = item
            if not re.fullmatch(r"\w+", ident):
                raise GenError(f"cannot parse enum member {item!r} in {name}")
            members.append((ident, value))
            value += 1
        enums[name] = members
    return enums


def parse_structs(src: str) -> dict[str, dict[str, tuple[str, int | None]]]:
    """typedef struct {...} name; -> {name: {member: (ctype, array_len_or_None)}}"""
    structs = {}
    pattern = r"typedef\s+struct(?:\s*__attribute__\(\(\w+\)\))?\s*\{(.*?)\}\s*(\w+)\s*;"
    for m in re.finditer(pattern, src, re.S):
        body, name = m.group(1), m.group(2)
        members = {}
        for decl in body.split(";"):
            decl = " ".join(decl.split())
            if not decl or decl.startswith("#"):
                continue
            decl = re.sub(r"#\w+[^\n]*", "", decl).strip()
            dm = re.fullmatch(r"((?:unsigned |signed )?\w+)\s+(.*)", decl)
            if not dm:
                continue
            ctype, names = dm.group(1), dm.group(2)
            for n in names.split(","):
                n = n.strip().lstrip("*")
                am = re.fullmatch(r"(\w+)\[(\w+)\]", n)
                if am:
                    size = am.group(2)
                    members[am.group(1)] = (ctype, int(size) if size.isdigit() else -1)
                elif re.fullmatch(r"\w+", n):
                    members[n] = (ctype, None)
        structs[name] = members
    return structs


def c_function_body(src: str, name: str) -> str:
    m = re.search(r"^\S+\s+" + re.escape(name) + r"\s*\([^)]*\)\s*\{\n(.*?)^\}", src, re.S | re.M)
    if not m:
        raise GenError(f"{name} not found")
    return m.group(1)


def parse_c_fields(body: str, direction: str) -> list[dict]:
    """Return the ordered fields of a confgenerator function.

    Each field: {"path": "app_ppm_conf.ctrl_type" or "hall_table[3]", "kind": ...,
                 "scale": "10" or None, "cast": "(int8_t)" or None}
    """
    fields = []
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        if line in ("int32_t ind = 0;", "return ind;", "return true;", "return false;", "}"):
            continue
        if "signature" in line or "SIGNATURE" in line:
            continue
        if direction == "serialize":
            m = re.fullmatch(r"buffer\[ind\+\+\] = (\((?:u?int8_t)\))?conf->([\w.]+(?:\[\d+\])?);", line)
            if m:
                fields.append({"path": m.group(2), "kind": "byte", "scale": None, "cast": m.group(1)})
                continue
            m = re.fullmatch(r"buffer_append_(\w+)\(buffer, conf->([\w.]+(?:\[\d+\])?)(?:, ([\d.e+-]+))?, &ind\);", line)
            if m:
                fields.append({"path": m.group(2), "kind": m.group(1), "scale": m.group(3), "cast": None})
                continue
        else:
            m = re.fullmatch(r"conf->([\w.]+(?:\[\d+\])?) = (\((?:u?int8_t)\))?buffer\[ind\+\+\];", line)
            if m:
                fields.append({"path": m.group(1), "kind": "byte", "scale": None, "cast": m.group(2)})
                continue
            m = re.fullmatch(r"conf->([\w.]+(?:\[\d+\])?) = buffer_get_(\w+)\(buffer(?:, ([\d.e+-]+))?, &ind\);", line)
            if m:
                fields.append({"path": m.group(1), "kind": m.group(2), "scale": m.group(3), "cast": None})
                continue
        raise GenError(f"unrecognised {direction} statement: {line}")
    for f in fields:
        if f["kind"] not in WIDTH:
            raise GenError(f"unknown buffer kind {f['kind']} for {f['path']}")
    return fields


def resolve_ctype(structs, root: str, path: str) -> str:
    """C type of `path` (e.g. 'bms.type', 'hall_table[2]') inside struct `root`."""
    cur = root
    parts = path.split(".")
    for i, part in enumerate(parts):
        name = re.sub(r"\[\d+\]", "", part)
        if cur not in structs or name not in structs[cur]:
            raise GenError(f"C struct {root}: no member {path}")
        ctype, _arr = structs[cur][name]
        if i == len(parts) - 1:
            return ctype
        cur = ctype
    raise GenError(path)


# --------------------------------------------------------------------------- Dart inventory

def parse_dart(paths: list[pathlib.Path]):
    """Return (classes, enums) from the hand-written Dart data classes."""
    classes: dict[str, dict[str, str]] = {}
    enums: dict[str, list[str]] = {}
    for p in paths:
        src = strip_comments(p.read_text())
        for m in re.finditer(r"^enum (\w+)\s*\{(.*?)\}", src, re.S | re.M):
            enums[m.group(1)] = [x.strip() for x in m.group(2).split(",") if x.strip()]
        for m in re.finditer(r"^class (\w+)\s*\{(.*?)^\}", src, re.S | re.M):
            members = {}
            for line in m.group(2).splitlines():
                dm = re.match(r"^\s+(?:final\s+)?([\w<>?]+)\s+(\w+)\s*(?:=|;)", line)
                if dm and not line.strip().startswith("static") and "(" not in line.split("=")[0]:
                    members[dm.group(2)] = dm.group(1)
            classes[m.group(1)] = members
    return classes, enums


def resolve_dart(classes, root: str, path: str, renames: dict[str, str]) -> tuple[str, str]:
    """Dart (path, type) for a C path, applying renames on the full path or last segment."""
    if path in renames:
        path = renames[path]
    parts = path.split(".")
    last = re.sub(r"\[\d+\]", "", parts[-1])
    if last in renames:
        parts[-1] = parts[-1].replace(last, renames[last])
    cur = root
    dart_parts = []
    for i, part in enumerate(parts):
        name = re.sub(r"\[\d+\]", "", part)
        idx = re.search(r"\[(\d+)\]", part)
        if cur not in classes or name not in classes[cur]:
            raise GenError(f"MISSING Dart field: {root}.{'.'.join(parts)} (no `{name}` in class {cur})")
        dtype = classes[cur][name]
        dart_parts.append(part)
        if i == len(parts) - 1:
            if idx:
                lm = re.fullmatch(r"List<(\w+)>", dtype)
                if not lm:
                    raise GenError(f"{root}.{path}: indexed but Dart type is {dtype}")
                return ".".join(dart_parts), lm.group(1)
            return ".".join(dart_parts), dtype
        cur = dtype
    raise GenError(path)


# --------------------------------------------------------------------------- code emission

class Emitter:
    def __init__(self, version: dict, c_enums, c_structs, dart_classes, dart_enums, renames, member_renames):
        self.v = version
        self.member_renames = member_renames
        self.c_enums = c_enums
        self.c_structs = c_structs
        self.dart_classes = dart_classes
        self.dart_enums = dart_enums
        self.renames = renames
        self.tables: dict[str, tuple[str, str, bool]] = {}   # dart enum -> (decl name, declaration, is_map)
        self.missing: list[str] = []
        self.layout: dict[str, dict] = {}

    # enum wire tables ---------------------------------------------------
    def table_for(self, c_enum: str, dart_enum: str) -> tuple[str, bool]:
        """Return (expression naming the wire table, is_map) for this version's enum."""
        if dart_enum in self.tables:
            decl, _code, is_map = self.tables[dart_enum]
            return decl, is_map
        c_members = self.c_enums.get(c_enum)
        if c_members is None:
            raise GenError(f"C enum {c_enum} not found in datatypes.h")
        c_members = [(self.member_renames.get(n, n), val) for n, val in c_members]
        dart_members = self.dart_enums.get(dart_enum)
        if dart_members is None:
            raise GenError(f"Dart enum {dart_enum} not found")
        missing = [n for n, _ in c_members if n not in dart_members]
        if missing:
            self.missing.append(f"enum {dart_enum} lacks members {missing} (C enum {c_enum})")
            self.tables[dart_enum] = (f"{dart_enum}.values", "", False)
            return f"{dart_enum}.values", False
        contiguous = [val for _, val in c_members] == list(range(len(c_members)))
        names = [n for n, _ in c_members]
        if contiguous and names == dart_members:
            self.tables[dart_enum] = (f"{dart_enum}.values", "", False)
            return f"{dart_enum}.values", False
        decl = f"_wire_{dart_enum}"
        if contiguous:
            body = ", ".join(f"{dart_enum}.{n}" for n in names)
            code = f"  static const List<{dart_enum}> {decl} = [{body}];"
        else:
            body = ", ".join(f"{val}: {dart_enum}.{n}" for n, val in c_members)
            code = f"  static const Map<int, {dart_enum}> {decl} = {{{body}}};"
        self.tables[dart_enum] = (decl, code, not contiguous)
        return decl, not contiguous

    # one field --------------------------------------------------------------
    def field_code(self, kind: str, f: dict, c_root: str, dart_root: str, var: str):
        """Return (read_line, write_line, layout_entry)."""
        path, ck, scale = f["path"], f["kind"], f["scale"]
        ctype = resolve_ctype(self.c_structs, c_root, path)
        try:
            dpath, dtype = resolve_dart(self.dart_classes, dart_root, path, self.renames)
        except GenError as e:
            self.missing.append(str(e))
            return None, None, None
        x = f"{var}.{dpath}"
        width = WIDTH[ck]
        entry = {"c": path, "dart": dpath, "kind": ck, "scale": scale, "size": width, "ctype": ctype, "dtype": dtype}
        if ck == "byte":
            if dtype == "bool":
                r = f"{x} = buffer[index++] > 0;"
                w = f"response.setUint8(index++, {x} ? 1 : 0);"
            elif dtype in self.dart_enums and ctype == "bool":
                # older firmware stored a flag where newer firmware has a mode enum
                entry["enum"] = "bool"
                r = f"{x} = buffer[index++] > 0 ? {dtype}.values[1] : {dtype}.values[0];"
                w = f"response.setUint8(index++, {x} == {dtype}.values[0] ? 0 : 1);"
            elif dtype in self.dart_enums:
                if ctype not in self.c_enums:
                    raise GenError(f"{path}: Dart enum {dtype} but C type {ctype} is not an enum")
                table, is_map = self.table_for(ctype, dtype)
                entry["enum"] = ctype
                if is_map:
                    r = f"{x} = enumFromWireMap({table}, buffer[index++], '{path}');"
                    w = f"response.setUint8(index++, enumToWireMap({table}, {x}, '{path}'));"
                else:
                    r = f"{x} = enumFromWire({table}, buffer[index++], '{path}');"
                    w = f"response.setUint8(index++, enumToWire({table}, {x}, '{path}'));"
            elif dtype == "int":
                if ctype == "int8_t" or (f["cast"] == "(int8_t)"):
                    r = f"{x} = buffer[index++].toSigned(8);"
                else:
                    r = f"{x} = buffer[index++];"
                w = f"response.setUint8(index++, {x} & 0xFF);"
            elif dtype == "double":
                r = f"{x} = buffer[index++].toDouble();"
                w = f"response.setUint8(index++, {x}.toInt().clamp(0, 255));"
            else:
                raise GenError(f"{path}: byte field with Dart type {dtype}")
        elif ck in ("uint16", "int16", "uint32", "int32"):
            setter = {"uint16": "setUint16", "int16": "setInt16", "uint32": "setUint32", "int32": "setInt32"}[ck]
            if dtype == "int":
                r = f"{x} = buffer_get_{ck}(buffer, index); index += {width};"
                w = f"response.{setter}(index, {x}); index += {width};"
            elif dtype == "double":
                r = f"{x} = buffer_get_{ck}(buffer, index).toDouble(); index += {width};"
                w = f"response.{setter}(index, {x}.round()); index += {width};"
            else:
                raise GenError(f"{path}: {ck} field with Dart type {dtype}")
        elif ck in ("float16", "float32"):
            getter = "buffer_get_float16" if ck == "float16" else "buffer_get_float32"
            setter = "setInt16" if ck == "float16" else "setInt32"
            s = scale if scale is not None else "1"
            if dtype == "double":
                r = f"{x} = {getter}(buffer, index, {s}); index += {width};"
                w = f"response.{setter}(index, ({x} * {s}).round()); index += {width};"
            elif dtype == "int":
                r = f"{x} = {getter}(buffer, index, {s}).round(); index += {width};"
                w = f"response.{setter}(index, ({x} * {s}).round()); index += {width};"
            else:
                raise GenError(f"{path}: {ck} field with Dart type {dtype}")
        elif ck == "float32_auto":
            if dtype == "double":
                r = f"{x} = buffer_get_float32_auto(buffer, index); index += 4;"
                w = f"response.setFloat32(index, {x}); index += 4;"
            elif dtype == "int":
                r = f"{x} = buffer_get_float32_auto(buffer, index).round(); index += 4;"
                w = f"response.setFloat32(index, {x}.toDouble()); index += 4;"
            else:
                raise GenError(f"{path}: float32_auto field with Dart type {dtype}")
        else:
            raise GenError(ck)
        return r, w, entry

    # a struct ---------------------------------------------------------------
    def struct_code(self, kind: str, csrc: str, signature: int):
        upper = kind.upper()                      # MCCONF / APPCONF
        c_root = "mc_configuration" if kind == "mcconf" else "app_configuration"
        ser = parse_c_fields(c_function_body(csrc, f"confgenerator_serialize_{kind}"), "serialize")
        des = parse_c_fields(c_function_body(csrc, f"confgenerator_deserialize_{kind}"), "deserialize")
        if [(f["path"], f["kind"], f["scale"]) for f in ser] != [(f["path"], f["kind"], f["scale"]) for f in des]:
            raise GenError(f"{self.v['label']} {kind}: serialize and deserialize field order differ")
        reads, writes, entries = [], [], []
        for s, d in zip(ser, des):
            f = dict(s)
            f["cast"] = d["cast"] or s["cast"]
            r, w, e = self.field_code(kind, f, c_root, upper, "conf")
            if r is None:
                continue
            reads.append(r)
            writes.append(w)
            entries.append(e)
        size = 4 + sum(e["size"] for e in entries)
        self.layout[kind] = {"signature": signature, "size": size, "fields": entries}
        var = "conf"
        lines = []
        lines.append(f"  @override")
        lines.append(f"  {upper} process{upper}(Uint8List buffer) {{")
        lines.append(f"    int index = 1; // byte 0 is the packet id")
        lines.append(f"    final {upper} {var} = {upper}();")
        lines.append(f"    final int signature = buffer_get_uint32(buffer, index); index += 4;")
        lines.append(f"    if (signature != {upper}_SIGNATURE) {{")
        lines.append(f"      globalLogger.e('{self.v['class']}: invalid {upper} signature $signature, expected ${upper}_SIGNATURE');")
        lines.append(f"      return {var};")
        lines.append(f"    }}")
        lines.extend(f"    {r}" for r in reads)
        lines.append(f"    assert(index == {upper}_SIZE + 1, '{upper} read $index bytes, expected ${{{upper}_SIZE + 1}}');")
        lines.append(f"    {var}.isValid = true;")
        lines.append(f"    return {var};")
        lines.append(f"  }}")
        lines.append("")
        lines.append(f"  @override")
        lines.append(f"  ByteData serialize{upper}({upper} {var}) {{")
        lines.append(f"    int index = 0;")
        lines.append(f"    final ByteData response = ByteData({upper}_SIZE);")
        lines.append(f"    response.setUint32(index, {upper}_SIGNATURE); index += 4;")
        lines.extend(f"    {w}" for w in writes)
        lines.append(f"    assert(index == {upper}_SIZE, '{upper} wrote $index bytes, expected ${upper}_SIZE');")
        lines.append(f"    return response;")
        lines.append(f"  }}")
        return "\n".join(lines), size

    def render(self, csrc: str, sigs: dict[str, int], source: dict[str, str]) -> str:
        mc_code, mc_size = self.struct_code("mcconf", csrc, sigs["MCCONF_SIGNATURE"])
        app_code, app_size = self.struct_code("appconf", csrc, sigs["APPCONF_SIGNATURE"])
        if self.missing:
            raise GenError("\n".join(self.missing))
        tables = "\n".join(code for _, code, _is_map in self.tables.values() if code)
        v = self.v
        served = ", ".join(v["firmware"])
        out = [
            "// GENERATED FILE - DO NOT EDIT.",
            "//",
            f"// Generated by tool/esc_serializers/generate.py from the VESC firmware sources",
            f"// vendored under tool/esc_serializers/vesc/{v['label']}/ (github.com/vedderb/bldc",
            f"// {source.get('ref', '?')} @ {source.get('commit', '?')}). Serves ESC_FIRMWARE {served}.",
            "// Re-run the generator after changing the vendored sources or the data classes.",
            "",
            "import 'dart:typed_data';",
            "",
            "import '../../../globalUtilities.dart';",
            "import '../appConf.dart';",
            "import '../mcConf.dart';",
            "import 'buffers.dart';",
            "import 'escConfigSerializer.dart';",
            "import 'wireEnums.dart';",
            "",
            f"/// Firmware {v['label']} configuration serializer ({served}).",
            f"class {v['class']} implements EscConfigSerializer {{",
            f"  static const int MCCONF_SIGNATURE = {sigs['MCCONF_SIGNATURE']};",
            f"  static const int APPCONF_SIGNATURE = {sigs['APPCONF_SIGNATURE']};",
            f"  static const int MCCONF_SIZE = {mc_size}; // bytes incl. signature, excl. packet id",
            f"  static const int APPCONF_SIZE = {app_size};",
            "",
            "  @override",
            "  int get mcconfSignature => MCCONF_SIGNATURE;",
            "  @override",
            "  int get appconfSignature => APPCONF_SIGNATURE;",
            "  @override",
            "  int get mcconfSize => MCCONF_SIZE;",
            "  @override",
            "  int get appconfSize => APPCONF_SIZE;",
        ]
        if tables:
            out += ["", "  // Wire index tables for enums whose members differ from the Dart enum order.", tables]
        out += ["", mc_code, "", app_code, "}", ""]
        return "\n".join(out)


# --------------------------------------------------------------------------- driver

def read_source(dirpath: pathlib.Path) -> dict[str, str]:
    info = {}
    p = dirpath / "SOURCE"
    if p.exists():
        for line in p.read_text().splitlines():
            if "=" in line:
                k, val = line.split("=", 1)
                info[k.strip()] = val.strip()
    return info


def generate(manifest: dict) -> tuple[dict[str, str], dict[str, dict]]:
    dart_classes, dart_enums = parse_dart([DART_DIR / "mcConf.dart", DART_DIR / "appConf.dart", DART_DIR / "dataTypes.dart"])
    files: dict[str, str] = {}
    layouts: dict[str, dict] = {}
    errors = []
    for v in manifest["versions"]:
        vdir = TOOL / "vesc" / v["label"]
        csrc = strip_comments((vdir / "confgenerator.c").read_text())
        hsrc = (vdir / "confgenerator.h").read_text()
        dsrc = strip_comments((vdir / "datatypes.h").read_text())
        sigs = {k: int(val) for k, val in re.findall(r"#define\s+(MCCONF_SIGNATURE|APPCONF_SIGNATURE)\s+(\d+)", hsrc)}
        renames = dict(manifest.get("renames", {}))
        renames.update(v.get("renames", {}))
        em = Emitter(v, parse_enums(dsrc), parse_structs(dsrc), dart_classes, dart_enums, renames,
                     manifest.get("enum_member_renames", {}))
        try:
            files[v["file"]] = em.render(csrc, sigs, read_source(vdir))
            layouts[v["label"]] = {"label": v["label"], "ref": read_source(vdir).get("ref"), "class": v["class"],
                                   "firmware": v["firmware"], "mcconf": em.layout["mcconf"], "appconf": em.layout["appconf"]}
        except GenError as e:
            errors.append(f"[{v['label']}] {e}")
    if errors:
        raise GenError("\n".join(errors))
    return files, layouts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="verify the generated files are up to date")
    ap.add_argument("--out", type=pathlib.Path, help="write generated Dart files to this directory instead")
    args = ap.parse_args()
    manifest = json.loads((TOOL / "versions.json").read_text())
    try:
        files, layouts = generate(manifest)
    except GenError as e:
        print("generation failed:\n" + str(e), file=sys.stderr)
        return 2
    out_dir = args.out or OUT_DIR
    layout_dir = (args.out / "layouts") if args.out else LAYOUT_DIR
    stale = []
    for name, content in files.items():
        target = out_dir / name
        if args.check:
            if not target.exists() or target.read_text() != content:
                stale.append(name)
                if target.exists():
                    sys.stdout.writelines(difflib.unified_diff(target.read_text().splitlines(True), content.splitlines(True), str(target), "generated"))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    for label, layout in layouts.items():
        target = layout_dir / f"{label}.json"
        content = json.dumps(layout, indent=1) + "\n"
        if args.check:
            if not target.exists() or target.read_text() != content:
                stale.append(str(target.relative_to(ROOT)) if target.is_relative_to(ROOT) else str(target))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    if args.check:
        if stale:
            print("STALE generated files (run tool/esc_serializers/generate.py): " + ", ".join(stale), file=sys.stderr)
            return 1
        print("generated ESC serializers are up to date")
        return 0
    for label, layout in layouts.items():
        print(f"{label:5} {layout['class']:20} MCCONF {layout['mcconf']['size']:3} B ({len(layout['mcconf']['fields'])} fields)  APPCONF {layout['appconf']['size']:3} B ({len(layout['appconf']['fields'])} fields)")
    print(f"wrote {len(files)} Dart files to {out_dir} and {len(layouts)} layouts to {layout_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
