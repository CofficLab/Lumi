[(comment)] @comment
[(string) (template_string)] @string
[(number)] @number
[(true) (false)] @boolean
[(null) (undefined)] @constant.builtin
["const" "let" "var" "function" "class" "extends" "import" "export" "from" "if" "else" "switch" "case" "for" "while" "return" "throw" "try" "catch" "finally" "async" "await" "new" "typeof" "instanceof"] @keyword
(function_declaration name: (identifier) @function)
(call_expression function: (identifier) @function.call)
(class_declaration name: (identifier) @type)
