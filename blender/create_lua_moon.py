import bpy
import math
import os
from mathutils import Vector

# Original procedural Lua moon generator for Blender 4.x.
# Run from Blender's Scripting workspace with: Run Script.

MOON_NAME = "LuaMoon"
EXPORT_PATH = os.path.join(os.path.dirname(bpy.data.filepath), "lua_moon.glb") if bpy.data.filepath else os.path.join(os.path.expanduser("~"), "lua_moon.glb")


def clear_previous():
    collection = bpy.data.collections.get(MOON_NAME)
    if collection:
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(collection)
    collection = bpy.data.collections.new(MOON_NAME)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def make_moon(collection):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=6, radius=3.0, location=(0, 0, 0))
    moon = bpy.context.object
    moon.name = MOON_NAME
    move_to_collection(moon, collection)

    bpy.ops.object.shade_smooth()
    bevel = moon.modifiers.new("Soft lunar silhouette", "BEVEL")
    bevel.width = 0.008
    bevel.segments = 2

    displacement = moon.modifiers.new("Large crater terrain", "DISPLACE")
    cloud = bpy.data.textures.new("Lunar terrain noise", type="CLOUDS")
    cloud.noise_scale = 0.32
    cloud.noise_depth = 5
    cloud.noise_basis = "IMPROVED_PERLIN"
    displacement.texture = cloud
    displacement.strength = 0.055
    displacement.mid_level = 0.52

    material = make_lunar_material()
    moon.data.materials.append(material)
    return moon


def make_lunar_material():
    material = bpy.data.materials.new("Lua lunar regolith")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (900, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.location = (620, 0)
    shader.inputs["Roughness"].default_value = 0.92
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Specular IOR Level"].default_value = 0.18

    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-900, 0)
    mapping = nodes.new("ShaderNodeMapping")
    mapping.location = (-720, 0)

    large_noise = nodes.new("ShaderNodeTexNoise")
    large_noise.location = (-500, 160)
    large_noise.inputs["Scale"].default_value = 2.1
    large_noise.inputs["Detail"].default_value = 7.0
    large_noise.inputs["Roughness"].default_value = 0.78

    fine_noise = nodes.new("ShaderNodeTexNoise")
    fine_noise.location = (-500, -170)
    fine_noise.inputs["Scale"].default_value = 32.0
    fine_noise.inputs["Detail"].default_value = 5.0
    fine_noise.inputs["Roughness"].default_value = 0.86

    craters = nodes.new("ShaderNodeTexVoronoi")
    craters.location = (-490, -430)
    craters.voronoi_dimensions = "3D"
    craters.feature = "DISTANCE_TO_EDGE"
    craters.distance = "EUCLIDEAN"
    craters.inputs["Scale"].default_value = 14.0

    crater_ramp = nodes.new("ShaderNodeValToRGB")
    crater_ramp.location = (-220, -430)
    crater_ramp.color_ramp.elements[0].position = 0.24
    crater_ramp.color_ramp.elements[1].position = 0.42

    color_ramp = nodes.new("ShaderNodeValToRGB")
    color_ramp.location = (40, 160)
    color_ramp.color_ramp.elements[0].position = 0.22
    color_ramp.color_ramp.elements[0].color = (0.055, 0.062, 0.072, 1.0)
    color_ramp.color_ramp.elements[1].position = 0.78
    color_ramp.color_ramp.elements[1].color = (0.34, 0.36, 0.38, 1.0)

    mix = nodes.new("ShaderNodeMixRGB")
    mix.location = (300, 80)
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 0.42

    bump = nodes.new("ShaderNodeBump")
    bump.location = (360, -210)
    bump.inputs["Strength"].default_value = 0.38
    bump.inputs["Distance"].default_value = 0.12

    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], large_noise.inputs["Vector"])
    links.new(mapping.outputs["Vector"], fine_noise.inputs["Vector"])
    links.new(mapping.outputs["Vector"], craters.inputs["Vector"])
    links.new(large_noise.outputs["Fac"], color_ramp.inputs["Fac"])
    links.new(craters.outputs["Distance"], crater_ramp.inputs["Fac"])
    links.new(color_ramp.outputs["Color"], mix.inputs[1])
    links.new(crater_ramp.outputs["Color"], mix.inputs[2])
    links.new(mix.outputs["Color"], shader.inputs["Base Color"])
    links.new(fine_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def make_lighting(collection):
    bpy.ops.object.light_add(type="AREA", location=(-5.0, -6.0, 5.0))
    sun = bpy.context.object
    sun.name = "Cold sun"
    sun.data.energy = 1200
    sun.data.shape = "DISK"
    sun.data.size = 4.0
    sun.rotation_euler = (math.radians(28), math.radians(-24), math.radians(-38))
    move_to_collection(sun, collection)

    bpy.ops.object.light_add(type="AREA", location=(4.0, 2.0, -1.0))
    fill = bpy.context.object
    fill.name = "Subtle space fill"
    fill.data.energy = 90
    fill.data.color = (0.16, 0.22, 0.30)
    fill.data.size = 5.0
    move_to_collection(fill, collection)


def make_camera(collection):
    bpy.ops.object.camera_add(location=(0, -8.5, 0.4))
    camera = bpy.context.object
    camera.name = "Lua preview camera"
    camera.data.lens = 58
    direction = Vector((0, 0, 0)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    move_to_collection(camera, collection)
    bpy.context.scene.camera = camera


def export_glb():
    folder = os.path.dirname(EXPORT_PATH)
    if folder:
        os.makedirs(folder, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=EXPORT_PATH,
        export_format="GLB",
        use_selection=False,
        export_materials="EXPORT",
        export_apply=True,
    )
    print("Lua moon exported to:", EXPORT_PATH)


def main():
    collection = clear_previous()
    make_moon(collection)
    make_lighting(collection)
    make_camera(collection)
    bpy.context.scene.world.color = (0.002, 0.004, 0.008)
    export_glb()


if __name__ == "__main__":
    main()
