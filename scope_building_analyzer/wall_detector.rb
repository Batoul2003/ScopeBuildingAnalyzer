require_relative 'geometry'
require_relative 'entity_walker'

module ScopeBuildingAnalyzer
  # This is one raw SketchUp face, not yet a "logical wall" -- a single
  # physical wall is often built from several of these (see wall_merger.rb).
  #
  # normal_xy - the face's horizontal facing direction as a 2D unit
  #             vector [x, y]. Walls are vertical, so only the horizontal
  #             direction matters for telling which way a wall faces.
  WallFace = Struct.new(:face, :transformation, :name, :length_m, :height_m, :area_m2, :base_z_m, :world_points, :normal_xy)

  module WallDetector
    # A face counts as "vertical" if its normal's Z component is small --
    # i.e. the face points mostly sideways, not up or down.
    NORMAL_Z_TOLERANCE = 0.3

    # Faces smaller than this are almost certainly not real wall geometry
    # at all (stray slivers, leftover construction faces, etc). This is
    # kept deliberately tiny -- the real "is this actually a wall, or just
    # noise" judgement happens AFTER merging fragments together, in
    # WallMerger::MIN_LOGICAL_WALL_AREA_M2, where a whole merged wall's
    # true size can be judged fairly instead of one small piece of it.
    MIN_RAW_FACE_AREA_M2 = 0.05

    def self.find_walls
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
      return unless normal.z.abs < NORMAL_Z_TOLERANCE

      area_in2 = face.area(transformation)
      area_m2 = Geometry.area_to_m2(area_in2)
      return if area_m2 < MIN_RAW_FACE_AREA_M2

      world_points = face.vertices.map { |v| v.position.transform(transformation) }
      zs = world_points.map(&:z)
      height_m = Geometry.length_to_m(zs.max - zs.min)
      return if height_m <= 0

      # Deriving length from area / height (rather than measuring a
      # bounding-box diagonal) stays correct even for walls that aren't
      # perfectly axis-aligned rectangles.
      length_m = area_m2 / height_m
      base_z_m = Geometry.length_to_m(zs.min)

      # Flatten the normal onto the XY plane (walls are vertical, so we
      # only care about which way they face in plan) and normalize it.
      normal_len = Math.sqrt((normal.x * normal.x) + (normal.y * normal.y))
      normal_xy = normal_len.zero? ? [0.0, 0.0] : [normal.x / normal_len, normal.y / normal_len]

      results << WallFace.new(
        face, transformation, parent_label,
        length_m.round(2), height_m.round(2), area_m2.round(2), base_z_m.round(2),
        world_points, normal_xy
      )
    end
  end
end
