extends SceneTree
## Optional visual check: requires a graphics display; never use --headless.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var studio: Node3D = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	studio.truck.set_expression("Happy")
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var result := root.get_texture().get_image().save_png("res://test-results/studio.png")
	print("RENDER_RESULT ", error_string(result))
	quit(0 if result == OK else 1)
