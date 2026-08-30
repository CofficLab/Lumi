[(comment)] @comment
[(string) (template_string)] @string
[(number)] @number
[(true) (false)] @boolean
["const" "let" "var" "function" "class" "interface" "type" "enum" "namespace" "extends" "implements" "import" "export" "from" "if" "else" "switch" "case" "for" "while" "return" "throw" "try" "catch" "async" "await" "new" "keyof" "typeof" "as" "satisfies"] @keyword
(predefined_type) @type.builtin
(type_identifier) @type
(function_declaration name: (identifier) @function)
(call_expression function: (identifier) @function.call)
