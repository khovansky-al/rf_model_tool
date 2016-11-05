require 'bindata'
class MshToObj
  
  attr_reader :model, :filename
  attr_accessor :meshes

  def initialize(model, filename)
    # @model = model
    @filename = filename
    @meshes = {}

    print "Parsing mesh..."
    parse_meshes(model)
    puts "Done!"
  end

  def parse_meshes(model)
    model.msh_entities.each do |mesh|
      parse_mesh(mesh)
    end
  end

  def parse_mesh(mesh)
    if mesh.vertices_count > 0
      self.meshes[mesh.msh_name] = {}
      self.meshes[mesh.msh_name][:vertices], self.meshes[mesh.msh_name][:normals] = parse_vertices(mesh)
      self.meshes[mesh.msh_name][:tex_coords], self.meshes[mesh.msh_name][:faces] = parse_faces(mesh)
      self.meshes[mesh.msh_name][:texture] = mesh.texture
    end
  end

  def parse_vertices(mesh)
    vertices = []
    normals = []

    mesh.vertices.each do |rf_vertex|
      vertices << [rf_vertex.x, rf_vertex.y, rf_vertex.z, rf_vertex.w]
      normals << [rf_vertex.normals.x, rf_vertex.normals.y, rf_vertex.normals.z]
    end

    [vertices, normals]
  end

  def parse_faces(mesh)
    tex_coords = []
    faces = []

    mesh.faces.each_with_index do |rf_face, i|
      rf_face.uv.map { |uv| [uv.tex_u, uv.tex_v * -1, 0]  }.each do |prepared_vt|
        tex_coords << prepared_vt
      end

      face = []
      rf_face.indices.each_with_index do |index, coord_index|
        face << [index + 1, i * 3 + (coord_index + 1), index + 1]
      end
      faces << face
    end

    [tex_coords, faces]
  end

  def convert
    puts "Writing .obj file"

    File.open("./#{self.filename}.obj", "w") do |f|
      f.puts '#RF Model Convertor 0.1'
      f.puts '#'
      self.meshes.each do |name, data|
        # fixed_name = BinData::Stringz.new.read(name) # Better way would be create a separate data struct for name in parser and count bytes
        # fixed_name = 'mesh' # Better way would be create a separate data struct for name in parser and count bytes
        fixed_name = name
        f.puts "g #{fixed_name}"
        
        data[:vertices].each do |vertex|
          f.puts "v %.6f %.6f %.6f %.6f" % vertex
        end

        f.puts

        data[:tex_coords].each do |tex_coord|
          f.puts "vt %.6f %.6f %.6f" % tex_coord
        end

        f.puts

        data[:normals].each do |normal|
          f.puts "vn %.6f %.6f %.6f" % normal
        end

        f.puts
        f.puts "g #{fixed_name}"
        f.puts "usemtl #{File.basename(data[:texture])}"
        data[:faces].each do |face|
          f.puts "f #{face[0].join('/')} #{face[1].join('/')} #{face[2].join('/')}"
        end
      end

    end
    puts "Done!"
  end

end