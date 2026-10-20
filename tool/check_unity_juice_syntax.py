"""C# syntax-only check. Does not replace Unity compilation or PlayMode tests.

Use tree-sitter and tree-sitter-c-sharp from an isolated tooling environment.
"""
from pathlib import Path
import sys
from tree_sitter import Language, Parser
import tree_sitter_c_sharp

parser = Parser(Language(tree_sitter_c_sharp.language()))
root = Path(__file__).resolve().parents[1] / "unity/Halabessa/Assets/Scripts"
errors = []
for name in ("UnityBridge.cs", "CardJuiceController.cs", "CardInstance.cs"):
    tree = parser.parse((root / name).read_bytes())
    nodes = [tree.root_node]
    while nodes:
        node = nodes.pop()
        if node.type == "ERROR" or node.is_missing:
            errors.append(f"{name}:{node.start_point.row + 1}: {node.type}")
        nodes.extend(node.children)
    print(f"{name}: {'syntax errors' if tree.root_node.has_error else 'syntax valid'}")
for error in errors:
    print(error, file=sys.stderr)
sys.exit(1 if errors else 0)
