(comment) @comment
[(double_quote_scalar) (single_quote_scalar)] @string
[(integer_scalar) (float_scalar)] @number
[(boolean_scalar)] @boolean
[(null_scalar)] @constant.builtin
(block_mapping_pair key: (flow_node) @property)
[(anchor_name) (alias_name)] @label
