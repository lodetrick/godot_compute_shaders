extends Control


func _on_button_pressed():
	get_tree().change_scene_to_file("res://CGoL/main.tscn")


func _on_boids_button_pressed():
	get_tree().change_scene_to_file("res://Boids/boids.tscn")
