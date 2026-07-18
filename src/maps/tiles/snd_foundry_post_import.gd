@tool
extends EditorScenePostImport

## Post-import hook for snd_foundry.glb.
## Forces every material to use nearest ("closest") texture filtering so the
## small pixel-art textures render as crisp pixels instead of being smoothed.

func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene


func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					(mat as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for child in node.get_children():
		_apply(child)
