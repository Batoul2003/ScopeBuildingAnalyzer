require_relative 'geometry'
require_relative 'entity_walker'

module ScopeBuildingAnalyzer
  # world_points - transformed vertex positions, used by Validator (bbox
  #                overlap checks) and Highlighter needs just the face.
  RoomFace = Struct.new(:face, :transformation, :name, :area_in2, :level_z, :world_points) do
    def area_m2
      Geometry.area_to_m2(area_in2)
    end
  end

  module RoomDetector
    MIN_ROOM_AREA_M2 = 1.0    # ignore slivers / noise faces
    NORMAL_TOLERANCE = 0.99   # how close to straight-up the face normal must be

    # Recursively finds candidate room/floor faces anywhere in the model,
    # including inside nested groups and component instances.
    def self.find_rooms
      results = []
      EntityWalker.each_face do |face, transformation, parent_label|
        process_face(face, transformation, parent_label, results)
      end
      results
    end

    def self.process_face(face, transformation, parent_label, results)
      return unless face.valid?

      normal = face.normal.transform(transformation)
      normal.normalize!
      return unless normal.z > NORMAL_TOLERANCE

      area_in2 = face.area(transformation)
      return if Geometry.area_to_m2(area_in2) < MIN_ROOM_AREA_M2

      world_points = face.vertices.map { |v| v.position.transform(transformation) }
      z = world_points.first.z

      results << RoomFace.new(face, transformation, parent_label, area_in2, z.round(1), world_points)
    end
  end
end
