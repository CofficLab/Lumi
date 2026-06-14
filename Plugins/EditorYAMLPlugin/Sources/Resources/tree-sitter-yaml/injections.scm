(block_mapping_pair
  key: (flow_node (plain_scalar) @key
    (#eq? @key "run"))
  value: (block_node (block_scalar) @injection.content
    (#set! injection.language "bash")))

(block_mapping_pair
  key: (flow_node (plain_scalar) @key
    (#eq? @key "run"))
  value: (flow_node (block_scalar) @injection.content
    (#set! injection.language "bash")))
