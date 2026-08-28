[(comment) (multiline_comment)] @comment
[(line_str_text) (multi_line_str_text) (raw_str_part)] @string
[(integer_literal) (hex_literal) (oct_literal) (bin_literal)] @number
(real_literal) @float
(boolean_literal) @boolean
(type_identifier) @type
(function_declaration (simple_identifier) @function.method)
(call_expression (simple_identifier) @function.call)
[(visibility_modifier) (member_modifier) (function_modifier) (property_modifier)] @keyword.modifier
["func" "let" "var" "struct" "class" "enum" "protocol" "extension" "import"] @keyword
