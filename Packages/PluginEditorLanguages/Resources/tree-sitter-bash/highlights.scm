(comment) @comment
[(string) (raw_string) (ansi_c_string)] @string
(variable_name) @variable
["if" "then" "else" "elif" "fi" "for" "while" "until" "do" "done" "case" "esac" "function" "in"] @keyword
(function_definition name: (word) @function)
(command name: (command_name (word) @function.call))
