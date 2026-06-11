#include "CodeLanguages_Container.h"

double CodeLanguages_ContainerVersionNumber = 1.0;
const unsigned char CodeLanguages_ContainerVersionString[] = "1.0";

/* Fallback symbols used only when CodeLanguagesContainer.xcframework is absent. */
#define TREE_SITTER_STUB(name) \
    TSLanguage *name(void) { return 0; }

TREE_SITTER_STUB(tree_sitter_agda)
TREE_SITTER_STUB(tree_sitter_bash)
TREE_SITTER_STUB(tree_sitter_c)
TREE_SITTER_STUB(tree_sitter_cpp)
TREE_SITTER_STUB(tree_sitter_c_sharp)
TREE_SITTER_STUB(tree_sitter_css)
TREE_SITTER_STUB(tree_sitter_dart)
TREE_SITTER_STUB(tree_sitter_dockerfile)
TREE_SITTER_STUB(tree_sitter_elixir)
TREE_SITTER_STUB(tree_sitter_go)
TREE_SITTER_STUB(tree_sitter_gomod)
TREE_SITTER_STUB(tree_sitter_haskell)
TREE_SITTER_STUB(tree_sitter_html)
TREE_SITTER_STUB(tree_sitter_java)
TREE_SITTER_STUB(tree_sitter_javascript)
TREE_SITTER_STUB(tree_sitter_jsdoc)
TREE_SITTER_STUB(tree_sitter_json)
TREE_SITTER_STUB(tree_sitter_julia)
TREE_SITTER_STUB(tree_sitter_kotlin)
TREE_SITTER_STUB(tree_sitter_lua)
TREE_SITTER_STUB(tree_sitter_markdown)
TREE_SITTER_STUB(tree_sitter_markdown_inline)
TREE_SITTER_STUB(tree_sitter_objc)
TREE_SITTER_STUB(tree_sitter_ocaml)
TREE_SITTER_STUB(tree_sitter_ocaml_interface)
TREE_SITTER_STUB(tree_sitter_perl)
TREE_SITTER_STUB(tree_sitter_php)
TREE_SITTER_STUB(tree_sitter_python)
TREE_SITTER_STUB(tree_sitter_regex)
TREE_SITTER_STUB(tree_sitter_ruby)
TREE_SITTER_STUB(tree_sitter_rust)
TREE_SITTER_STUB(tree_sitter_scala)
TREE_SITTER_STUB(tree_sitter_sql)
TREE_SITTER_STUB(tree_sitter_swift)
TREE_SITTER_STUB(tree_sitter_toml)
TREE_SITTER_STUB(tree_sitter_tsx)
TREE_SITTER_STUB(tree_sitter_typescript)
TREE_SITTER_STUB(tree_sitter_verilog)
TREE_SITTER_STUB(tree_sitter_yaml)
TREE_SITTER_STUB(tree_sitter_zig)
