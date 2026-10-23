(comment) @comment
(string) @string
[(integer) (float)] @number
[(true) (false)] @boolean
(none) @constant.builtin
["def" "class" "import" "from" "as" "if" "elif" "else" "for" "while" "try" "except" "finally" "with" "return" "yield" "raise" "async" "await" "lambda" "pass" "break" "continue" "global" "nonlocal" "assert" "del" "in" "is" "not" "and" "or"] @keyword
(function_definition name: (identifier) @function)
(class_definition name: (identifier) @type)
(call function: (identifier) @function.call)
