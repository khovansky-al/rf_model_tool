# encoding: utf-8

require 'bindata'
require_relative 'mshtoobj'

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

class RfFace < BinData::Record
  endian :little

  array :indices, type: :uint32, initial_length: 3
  skip length: 9 * 4 # index buffers

  array :uv, initial_length: 3 do
    float :tex_u
    float :tex_v # possibly should be multiplied by -1 to use correctly
    skip length: 4
  end
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
  
  skip length: 23 * 4 + 2 + 1 #that looks like some more matrixes or smth
  
  array :vertices, type: :rf_vertex, initial_length: :vertices_count
  array :faces, type: :rf_face, initial_length: :faces_count

  uint32 :bones_num
end

class RfMsh < BinData::Record
  endian :little

  uint16 :msh_count
  array :msh_entities, type: :msh_entity, initial_length: :msh_count
end

# MODEL_FILENAME='BELCOR_WEAPON_TSTAFF_076'
# MODEL_FILENAME='BC_W_TSTAFF_201'
MODEL_FILENAME='BELCOR_ARMOR_LSHIELD_169'
# $stderr.reopen("err.txt", "w")

time_start = Time.now

io = File.open("#{MODEL_FILENAME}.msh", 'rb')
# BinData::trace_reading do
model = RfMsh.read(io)
# end

time_end = Time.now
time_delta = time_end - time_start

puts "Parsed #{MODEL_FILENAME} in #{time_delta}ms."
puts "Meshes count: #{model.msh_count}"

puts "Mesh: #{model.msh_entities[5].msh_name}"
puts "Limb: #{model.msh_entities[5].limb_name}"
puts "========"
puts "Mtx1: #{model.msh_entities[5].mtx1}"
puts "Mtx2: #{model.msh_entities[5].mtx2}"
puts "Mtx3: #{model.msh_entities[5].mtx3}"
puts "========"
puts "Vertices count: #{model.msh_entities[5].vertices_count}"
puts "Faces count: #{model.msh_entities[5].faces_count}"
puts "Bones count: #{model.msh_entities[5].bones_count}"
puts "========"
puts "Texture name: #{model.msh_entities[5].texture}"
puts "Tex2 name: #{model.msh_entities[5].texture_2}"
puts "========"
puts "Vertices: #{model.msh_entities[5].vertices[0]}"
puts "Faces: #{model.msh_entities[5].faces[0]}"
puts "Bones number again?: #{model.msh_entities[5].bones_num}"

puts "Converting to .obj..."
convertor = MshToObj.new(model, MODEL_FILENAME)
convertor.convert 