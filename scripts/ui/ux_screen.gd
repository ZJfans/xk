class_name UXScreen
extends Control
## Feature presentation boundary. UI requests events; it NEVER updates the domain mock directly.
signal route_requested(route_id: String)
signal action_requested(action_id: String, payload: Dictionary)
var session: UXSession

func mount(value: UXSession) -> void:
	session = value
	render()

func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build()

func build() -> void:
	pass

func go(destination: String) -> void:
	route_requested.emit(destination)

func do(action_id: String, payload: Dictionary = {}) -> void:
	action_requested.emit(action_id, payload)
