#!/usr/bin/env python3
"""Extract exact compiler-libs / ppx objects from a dk value-store artifact via
the zip central directory, navigating nested zips (valuestore.zip -> blob -> prefix.zip),
without full extraction. Prints matches + sha256, writes matches to <out>/."""
import io, os, re, sys, zipfile, hashlib

def sha(b): return hashlib.sha256(b).hexdigest()

# Members we care about (basename or path fragment), as regexes.
TARGETS = re.compile(
    r'(compiler-libs/(config|location|ocamlcommon)\.(cmx|cmi|cmxa)'
    r'|(^|/)(config|location)\.cmx$'
    r'|ppxlib/astlib/astlib\.cmxa'
    r'|codept-lib/codept_lib\.cmxa'
    r'|(^|/)astlib\.cmxa$'
    r'|(^|/)ocamlcommon\.cmxa$)')

def open_zip_bytes(b):
    try:
        return zipfile.ZipFile(io.BytesIO(b))
    except zipfile.BadZipFile:
        return None

def walk(zf, prefix, out, depth, blob_filter=None):
    """Walk a ZipFile; recurse one level into nested zips (prefix.zip/install.zip
    or a large stored member). Extract TARGET members to out."""
    for info in zf.infolist():
        name = info.filename
        low = name.lower()
        if TARGETS.search(name):
            data = zf.read(info)
            dest = os.path.join(out, os.path.basename(name))
            with open(dest, 'wb') as f: f.write(data)
            print(f"  EXTRACT {prefix}{name}  size={len(data)} sha256={sha(data)}")
            continue
        is_ziplike = low.endswith('.zip') or info.file_size > 3_000_000
        if depth > 0 and is_ziplike:
            if blob_filter and prefix == "" and not any(k in name for k in blob_filter):
                continue
            try:
                data = zf.read(info)
            except Exception:
                continue
            inner = open_zip_bytes(data)
            if inner is not None:
                walk(inner, prefix + name + "!/", out, depth - 1)

def main():
    vs, out = sys.argv[1], sys.argv[2]
    blob_filter = sys.argv[3].split(',') if len(sys.argv) > 3 else None
    os.makedirs(out, exist_ok=True)
    print(f"== {vs} (blob_filter={blob_filter}) ==")
    with zipfile.ZipFile(vs) as zf:
        walk(zf, "", out, depth=3, blob_filter=blob_filter)

if __name__ == '__main__':
    main()
