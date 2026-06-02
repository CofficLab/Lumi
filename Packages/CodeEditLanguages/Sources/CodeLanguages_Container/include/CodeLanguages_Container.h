#ifndef CODE_LANGUAGES_CONTAINER_H
#define CODE_LANGUAGES_CONTAINER_H

extern double CodeLanguages_ContainerVersionNumber;
extern const unsigned char CodeLanguages_ContainerVersionString[];

typedef struct TSLanguage TSLanguage;

#ifdef __cplusplus
extern "C" {
#endif

extern TSLanguage *tree_sitter_agda(void);
extern TSLanguage *tree_sitter_bash(void);
extern TSLanguage *tree_sitter_c(void);
extern TSLanguage *tree_sitter_cpp(void);
extern TSLanguage *tree_sitter_c_sharp(void);
extern TSLanguage *tree_sitter_css(void);
extern TSLanguage *tree_sitter_dart(void);
extern TSLanguage *tree_sitter_dockerfile(void);
extern TSLanguage *tree_sitter_elixir(void);
extern TSLanguage *tree_sitter_go(void);
extern TSLanguage *tree_sitter_gomod(void);
extern TSLanguage *tree_sitter_haskell(void);
extern TSLanguage *tree_sitter_html(void);
extern TSLanguage *tree_sitter_java(void);
extern TSLanguage *tree_sitter_javascript(void);
extern TSLanguage *tree_sitter_jsdoc(void);
extern TSLanguage *tree_sitter_json(void);
extern TSLanguage *tree_sitter_julia(void);
extern TSLanguage *tree_sitter_kotlin(void);
extern TSLanguage *tree_sitter_lua(void);
extern TSLanguage *tree_sitter_markdown(void);
extern TSLanguage *tree_sitter_markdown_inline(void);
extern TSLanguage *tree_sitter_objc(void);
extern TSLanguage *tree_sitter_ocaml(void);
extern TSLanguage *tree_sitter_ocaml_interface(void);
extern TSLanguage *tree_sitter_perl(void);
extern TSLanguage *tree_sitter_php(void);
extern TSLanguage *tree_sitter_python(void);
extern TSLanguage *tree_sitter_regex(void);
extern TSLanguage *tree_sitter_ruby(void);
extern TSLanguage *tree_sitter_rust(void);
extern TSLanguage *tree_sitter_scala(void);
extern TSLanguage *tree_sitter_sql(void);
extern TSLanguage *tree_sitter_swift(void);
extern TSLanguage *tree_sitter_toml(void);
extern TSLanguage *tree_sitter_tsx(void);
extern TSLanguage *tree_sitter_typescript(void);
extern TSLanguage *tree_sitter_verilog(void);
extern TSLanguage *tree_sitter_yaml(void);
extern TSLanguage *tree_sitter_zig(void);

#ifdef __cplusplus
}
#endif

#endif
