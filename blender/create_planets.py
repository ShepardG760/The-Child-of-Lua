import bpy
import os

PLANETS = {
    "virel": {
        "name": "Virel",
        "colors": [(0.10, 0.035, 0.018, 1.0), (0.62, 0.20, 0.07, 1.0), (0.91, 0.53, 0.22, 1.0)],
        "pattern": "noise",
        "scale": 5.0,
        "roughness": 0.82,
    },
    "orison": {
        "name": "Orison",
        "colors": [(0.07, 0.15, 0.24, 1.0), (0.40, 0.65, 0.76, 1.0), (0.82, 0.90, 0.94, 1.0)],
        "pattern": "bands",
        "scale": 4.0,
        "roughness": 0.40,
    },
    "nadir": {
        "name": "Nadir",
        "colors": [(0.008, 0.035, 0.075, 1.0), (0.015, 0.20, 0.29, 1.0), (0.10, 0.48, 0.48, 1.0)],
        "pattern": "noise",
        "scale": 3.2,
        "roughness": 0.25,
    },
    "khepri": {
        "name": "Khepri",
        "colors": [(0.12, 0.10, 0.045, 1.0), (0.43, 0.34, 0.14, 1.0), (0.78, 0.67, 0.38, 1.0)],
        "pattern": "cells",
        "scale": 7.0,
        "roughness": 0.72,
    },
}

def get_output_dir():
    script_path = globals().get("__file__", "")
    if not script_path:
        for text in bpy.data.texts:
            if text.filepath and os.path.basename(text.filepath) == "create_planets.py":
                script_path = bpy.path.abspath(text.filepath)
                break
    if script_path:
        return os.path.dirname(os.path.abspath(script_path))
    return os.path.join(os.path.expanduser("~"), "lua_planets")


OUTPUT_DIR = get_output_dir()


def make_material(config):
    material = bpy.data.materials.new(config["name"] + " planetary surface")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (650, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.location = (400, 0)
    shader.inputs["Roughness"].default_value = config["roughness"]
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Specular IOR Level"].default_value = 0.25

    coordinates = nodes.new("ShaderNodeTexCoord")
    coordinates.location = (-800, 0)
    noise = nodes.new("ShaderNodeTexNoise")
    noise.location = (-550, -180)
    noise.inputs["Scale"].default_value = config["scale"]
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.72

    if config["pattern"] == "bands":
        separate = nodes.new("ShaderNodeSeparateXYZ")
        separate.location = (-550, 180)
        links.new(coordinates.outputs["Generated"], separate.inputs["Vector"])
        band_noise = nodes.new("ShaderNodeMath")
        band_noise.operation = "MULTIPLY_ADD"
        band_noise.location = (-320, 180)
        band_noise.inputs[1].default_value = 14.0
        band_noise.inputs[2].default_value = 0.12
        links.new(separate.outputs["Z"], band_noise.inputs[0])
        pattern_output = band_noise.outputs[0]
    else:
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        if config["pattern"] == "cells":
            cells = nodes.new("ShaderNodeTexVoronoi")
            cells.location = (-550, 180)
            cells.inputs["Scale"].default_value = config["scale"]
            links.new(coordinates.outputs["Generated"], cells.inputs["Vector"])
            pattern_output = cells.outputs["Distance"]
        else:
            pattern_output = noise.outputs["Fac"]

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-40, 60)
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for index, color in enumerate(config["colors"]):
        element = ramp.color_ramp.elements[0] if index == 0 else ramp.color_ramp.elements.new(index / (len(config["colors"]) - 1))
        element.position = index / (len(config["colors"]) - 1)
        element.color = color
    links.new(pattern_output, ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], shader.inputs["Base Color"])

    bump = nodes.new("ShaderNodeBump")
    bump.location = (160, -220)
    bump.inputs["Strength"].default_value = 0.18 if config["pattern"] != "bands" else 0.08
    bump.inputs["Distance"].default_value = 0.08
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def make_planet(key, config):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=40, radius=1.0, location=(0.0, 0.0, 0.0))
    planet = bpy.context.object
    planet.name = config["name"]
    bpy.ops.object.shade_smooth()
    planet.data.materials.append(make_material(config))

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    planet.select_set(True)
    bpy.context.view_layer.objects.active = planet
    output_path = os.path.join(OUTPUT_DIR, key + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_apply=True,
    )
    print("Exported", config["name"], "to", output_path)
    bpy.data.objects.remove(planet, do_unlink=True)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for key, config in PLANETS.items():
        make_planet(key, config)


if __name__ == "__main__":
    main()
