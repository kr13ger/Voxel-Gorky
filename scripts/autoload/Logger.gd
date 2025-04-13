extends Node

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	NONE
}

var current_level: int = LogLevel.INFO

func set_log_level(level: int) -> void:
	current_level = level

func debug(message: String, context: String = "") -> void:
	if current_level <= LogLevel.DEBUG:
		_log_message("DEBUG", message, context)

func info(message: String, context: String = "") -> void:
	if current_level <= LogLevel.INFO:
		_log_message("INFO", message, context)

func warning(message: String, context: String = "") -> void:
	if current_level <= LogLevel.WARNING:
		_log_message("WARNING", message, context)

func error(message: String, context: String = "") -> void:
	if current_level <= LogLevel.ERROR:
		_log_message("ERROR", message, context)
		
func _log_message(level: String, message: String, context: String) -> void:
	var context_str = " [%s]" % context if context else ""
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] [%s]%s: %s" % [timestamp, level, context_str, message])
