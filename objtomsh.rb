require 'bindata'

class Matrix44 < BinData::Record
  endian :little

  array :x, type: :float, initial_length: 4
  array :y, type: :float, initial_length: 4
  array :z, type: :float, initial_length: 4
  array :w, type: :float, initial_length: 4
end

class RfVertex < BinData::Record
  endian :little

  float :x
  float :y
  float :z
  float :w

  struct :normals do
    float :x
    float :y
    float :z
  end
end

class RfUV < BinData::Record
  endian :little

  float :tex_u
  float :tex_v
  skip length: 4
end

class RfFace < BinData::Record
  endian :little

  array :indices, type: :uint32, initial_length: 3
  skip length: 9 * 4 # index buffers

  array :uv, type: :rf_uv, initial_length: 3
  uint32 :unknown
end

class MshEntity < BinData::Record
  endian :little

  string :msh_name, length: 100, trim_padding: true
  string :limb_name, length: 100, trim_padding: true # ?
  
  matrix44 :mtx1
  matrix44 :mtx2
  matrix44 :mtx3
  
  uint16 :vertices_count
  uint16 :faces_count
  uint16 :bones_count #?
  
  string :texture, length: 100, trim_padding: true
  string :texture_2, length: 100, trim_padding: true #?
  
  # skip length: 23 * 4 + 2 + 1 #that looks like some more matrixes or smth
  
  skip length: 9 * 4
  uint32 :unk1, initial_value: 1
  skip length: 4
  uint32 :unk2, initial_value: 1
  skip length: 47

  array :vertices, type: :rf_vertex, initial_length: :vertices_count
  array :faces, type: :rf_face, initial_length: :faces_count

  uint32 :bones_num
end

class RfMsh < BinData::Record
  endian :little

  uint16 :msh_count
  array :msh_entities, type: :msh_entity, initial_length: :msh_count
end

Struct.new("Vertex", :x, :y, :z, :w, :normals)
Struct.new("Normal", :x, :y, :z)
Struct.new("UV", :tu, :tv)
Struct.new("Face", :indices, :uv)

def merge_vert_normals(vertices, normals)
  vertices.map.with_index do |vertex, i|
    vertex.normals = normals[i]
    vertex
  end
end

def merge_faces_uv(faces, uv_coords)
  faces.map.with_index do |face, index|
    face.uv = face.uv.map do |coord_index|
      uv_coords[coord_index]
    end

    face
  end
end

MODEL_FILENAME='BELCOR_WEAPON_TSTAFF_076'
MSH_NAME="W00"
BONE_NAME='Bip01 R Finger0'
file = File.open("#{MODEL_FILENAME}.obj", "r")

vertices, normals, uv_coords, faces = [], [], [], []
texture_name = 'dummy.dds'

while line = file.gets
  attrs = line.split
  type = attrs.shift

  case type
  when 'v'
    vertices << Struct::Vertex.new(*attrs.map(&:to_f))
  when 'vt'
    uv_coords << Struct::UV.new(*attrs.take(2).map.with_index {|v, i| i == 1 ? v.to_f * -1 : v.to_f })
  when 'vn'
    normals << Struct::Normal.new(*attrs.map(&:to_f))
  when 'f'
    indices = []
    uv = []
    attrs.each do |component|
      cmp_idx_arr = component.split('/')
      indices << cmp_idx_arr[0].to_i - 1 # v/vt/vn
      uv << cmp_idx_arr[1].to_i - 1
    end
    faces << Struct::Face.new(indices, uv)
  when 'usemtl'
    texture_name = attrs[0]
  end
end

file.close

texture_name = "D:\\RF3D\\rubyconv\\#{texture_name}"

vert_normals = merge_vert_normals(vertices, normals)
faces_uv = merge_faces_uv(faces, uv_coords)

vert_objects = []
face_objects = []

vert_normals.each do |v|
  vert = RfVertex.new(
    x: v.x,
    y: v.y,
    z: v.z,
    w: v.w, 
  )
  vert.normals.assign(
    x: v.normals.x,
    y: v.normals.y,
    z: v.normals.z,
  )

  vert_objects << vert
end

faces_uv.each do |face|
  uv_coords = face.uv.map do |tex_coord|
    RfUV.new(tex_u: tex_coord.tu, tex_v: tex_coord.tv)
  end
  face_objects << RfFace.new(
    indices: face.indices,
    uv: uv_coords
  )
end

world_matrix = Matrix44.new(
  x: [0.030, 0.999, -0.007, 0],
  y: [-0.038, -0.006, -0.999, 0],
  z: [-0.998, 0.030, 0.038, 0],
  w: [-0.019, 0.288, -0.145, 1]
)

EDIT_SECTION = 5
io = File.open("#{MODEL_FILENAME}.msh", 'rb')
# BinData::trace_reading do
orig_model = RfMsh.read(io)

msh_entity = MshEntity.new(
  msh_name: orig_model.msh_entities[EDIT_SECTION].msh_name, 
  limb_name: orig_model.msh_entities[EDIT_SECTION].limb_name,
  mtx1: orig_model.msh_entities[EDIT_SECTION].mtx1,
  mtx2: orig_model.msh_entities[EDIT_SECTION].mtx2,
  mtx3: orig_model.msh_entities[EDIT_SECTION].mtx3,
  vertices_count: vert_normals.count,
  faces_count: faces_uv.count,
  bones_count: 0,
  texture: texture_name,
  vertices: vert_objects,
  faces: face_objects,
  bones_num: 0
)
orig_model.msh_entities[5].assign(msh_entity)
# msh_entity = MshEntity.new(
#   msh_name: MSH_NAME, 
#   limb_name: BONE_NAME,
#   mtx2: world_matrix,
#   vertices_count: vert_normals.count,
#   faces_count: faces_uv.count,
#   bones_count: 0,
#   texture: texture_name,
#   vertices: vert_objects,
#   faces: face_objects,
#   bones_num: 0
# )
new_mesh = RfMsh.new(msh_count: 1, msh_entities: [msh_entity])

File.open("CONV_#{MODEL_FILENAME}.msh", "wb") do |io|
  # new_mesh.write(io)
  orig_model.write(io)
end