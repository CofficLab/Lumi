# ToolCallLoopDetectionPlugin

Listens for database events and stops the agent turn when the same tool call
(name + arguments) repeats too many times in recent history.
