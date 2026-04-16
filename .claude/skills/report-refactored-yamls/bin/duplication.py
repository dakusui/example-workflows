#!/usr/bin/env python3

import os
import sys
import json
from collections import defaultdict

try:
    import yaml
except ImportError:
    yaml = None


def is_yaml_file(path: str) -> bool:
    return path.endswith((".yaml", ".yml", ".yaml++", ".yml++"))


def is_json_file(path: str) -> bool:
    return path.endswith((".json", ".json++"))


def load_documents(path: str):
    """
    Load one file and return a list of parsed documents.
    - JSON file -> [obj]
    - YAML single-document file -> [obj]
    - YAML multi-document file -> [obj1, obj2, ...]
    Empty YAML documents are ignored.
    """
    with open(path, "r", encoding="utf-8") as f:
        if is_json_file(path):
            doc = json.load(f)
            return [doc] if doc is not None else []

        if is_yaml_file(path):
            if yaml is None:
                raise RuntimeError("PyYAML is required for YAML files")
            docs = list(yaml.safe_load_all(f))
            return [doc for doc in docs if doc is not None]

    return []


def compute_size(node) -> int:
    """
    Size = number of key-value entries recursively.
    Arrays themselves do not add size directly; their contained objects do.
    Scalars contribute 0.
    """
    if isinstance(node, dict):
        return sum(1 + compute_size(v) for v in node.values())
    if isinstance(node, list):
        return sum(compute_size(v) for v in node)
    return 0


def to_canonical_obj(node):
    """
    Convert to a canonical JSON-serializable structure.
    Objects: sort keys
    Arrays: preserve order
    Scalars: 그대로
    """
    if isinstance(node, dict):
        return {str(k): to_canonical_obj(node[k]) for k in sorted(node.keys(), key=str)}
    if isinstance(node, list):
        return [to_canonical_obj(x) for x in node]
    return node


def canonicalize(node) -> str:
    return json.dumps(
        to_canonical_obj(node),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def extract_fragments(node, min_size=3):
    """
    Extract all candidate fragments:
    - only dict/list rooted subtrees
    - only those whose size >= min_size
    Returns a list of dicts:
      {
        "canon": ...,
        "size": ...,
        "node": canonical Python object
      }
    """
    out = []

    def visit(n):
        if isinstance(n, (dict, list)):
            size = compute_size(n)
            if size >= min_size:
                out.append({
                    "canon": canonicalize(n),
                    "size": size,
                    "node": to_canonical_obj(n),
                })

            if isinstance(n, dict):
                for v in n.values():
                    visit(v)
            else:
                for v in n:
                    visit(v)

    visit(node)
    return out


def is_subtree(candidate, container) -> bool:
    """
    Returns True if 'candidate' appears somewhere inside 'container'
    as a proper subtree or equal subtree.
    Both arguments are canonical Python objects.
    """
    if candidate == container:
        return True

    if isinstance(container, dict):
        return any(is_subtree(candidate, v) for v in container.values())

    if isinstance(container, list):
        return any(is_subtree(candidate, v) for v in container)

    return False


def collect_input_files(inputs):
    paths = []
    for inp in inputs:
        if os.path.isdir(inp):
            for root, _, files in os.walk(inp):
                for name in files:
                    if name.endswith((".json", ".yaml", ".yml", ".yaml++", ".yml++", ".json++")):
                        paths.append(os.path.join(root, name))
        else:
            if inp.endswith((".json", ".yaml", ".yml", ".yaml++", ".yml++", ".json++")):
                paths.append(inp)
    return sorted(paths)


def compute_duplication_ratio(paths, min_size=3):
    total_size = 0
    fragments_by_canon = defaultdict(list)

    for path in paths:
        docs = load_documents(path)
        for doc in docs:
            total_size += compute_size(doc)
            for frag in extract_fragments(doc, min_size=min_size):
                fragments_by_canon[frag["canon"]].append(frag)

    # Keep only duplicated fragments
    duplicated_groups = []
    for canon, frags in fragments_by_canon.items():
        count = len(frags)
        if count > 1:
            duplicated_groups.append({
                "canon": canon,
                "size": frags[0]["size"],
                "count": count,
                "node": frags[0]["node"],
            })

    # Sort larger fragments first
    duplicated_groups.sort(key=lambda x: x["size"], reverse=True)

    maximal_groups = []
    for g in duplicated_groups:
        contained_in_larger = False
        for kept in maximal_groups:
            if is_subtree(g["node"], kept["node"]):
                contained_in_larger = True
                break
        if not contained_in_larger:
            maximal_groups.append(g)

    duplicated_excess = sum(g["size"] * (g["count"] - 1) for g in maximal_groups)

    ratio = 0.0 if total_size == 0 else duplicated_excess / total_size

    return {
        "total_size": total_size,
        "duplicated_excess": duplicated_excess,
        "duplication_ratio": ratio,
        "num_maximal_groups": len(maximal_groups),
        "maximal_groups": maximal_groups,
    }


def main(argv):
    if len(argv) < 2:
        print(f"Usage: {argv[0]} <file-or-directory> [more files/dirs...]")
        return 1

    paths = collect_input_files(argv[1:])
    if not paths:
        print("No JSON/YAML files found.")
        return 1

    result = compute_duplication_ratio(paths, min_size=3)

    print(f"Files scanned        : {len(paths)}")
    print(f"Total size           : {result['total_size']}")
    print(f"Duplicated excess    : {result['duplicated_excess']}")
    print(f"DuplicationRatio     : {result['duplication_ratio']:.6f}")
    print(f"Maximal dup groups   : {result['num_maximal_groups']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
