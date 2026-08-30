[(comment)] @comment
[(string) (template_string)] @string
[(number)] @number
[(true) (false)] @boolean
["const" "let" "var" "function" "class" "interface" "type" "enum" "extends" "implements" "import" "export" "from" "if" "else" "return" "async" "await" "new" "as"] @keyword
(predefined_type) @type.builtin
(type_identifier) @type
(jsx_opening_element name: (_) @tag)
(jsx_closing_element name: (_) @tag)
(jsx_attribute (property_identifier) @attribute)
