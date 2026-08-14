require_relative 'geometry'

module ScopeBuildingAnalyzer
  # A LogicalWall is the "real" wall an engineer would talk about --
  # possibly built from several raw SketchUp faces (fragments split by a
  # door/window opening, or the two opposite finish faces of one solid
  # wall). thickness_m is 0.0 when only one face was found for this wall
  # (no matching opposite face, so thickness can't be measured).
  LogicalWall = Struct.new(:name, :length_m, :height_m, :area_m2, :thickness_m, :base_z_m, :faces, :world_points)

  # ------------------------------------------------------------------
  # WallMerger groups raw wall faces (from WallDetector) into logical
  # walls. This is what fixes the "hundreds of tiny wall entries"
  # problem: most of those entries are just fragments of the same
  # physical wall, not separate walls.
  #
  # Grouping happens in two stages:
  #
  #   STAGE A - "one face, split into pieces"
  #     Faces that sit on the exact same infinite plane, face the same
  #     direction, and are close enough along the wall's run to belong
  #     together (e.g. two pieces on either side of a door opening) are
  #     merged into one "face group". This does NOT compare length or
  #     height between fragments -- position/orientation/proximity only.
  #
  #   STAGE B - "two sides of one solid wall"
  #     Two face groups that face OPPOSITE directions, sit a plausible
  #     wall-thickness apart, and run alongside each other for a decent
  #     stretch are merged into a single LogicalWall (this is the
  #     interior + exterior face of one physical wall). A face group
  #     with no matching opposite side just becomes its own LogicalWall.
  #
  # Two different physical walls will only ever merge if they satisfy
  # ALL of the position/orientation/proximity checks below -- having the
  # same length or height is never, by itself, a reason to merge.
  #
  # All tolerances are grouped at the top so they're easy to tune.
  # ------------------------------------------------------------------
  module WallMerger
    # --- Stage A: grouping fragments of the same physical face --------
    SAME_DIRECTION_DOT_MIN = 0.98    # ~11 degrees -- normals must point almost the same way
    PLANE_OFFSET_TOLERANCE_M = 0.05  # how far off the same infinite plane a fragment can be
    HEIGHT_TOLERANCE_M = 0.3         # how different two fragments' vertical ranges can be
    MAX_GAP_M = 1.5                  # max gap along the wall run to bridge (e.g. a door opening)

    # --- Stage B: pairing the two sides of one solid wall --------------
    OPPOSITE_DIRECTION_DOT_MAX = -0.98 # normals must point almost exactly opposite ways
    MIN_WALL_THICKNESS_M = 0.02
    MAX_WALL_THICKNESS_M = 0.6
    MIN_OPPOSITE_OVERLAP_RATIO = 0.4   # the two sides must run alongside each other for at least this fraction of the shorter one

    # --- Final cleanup ---------------------------------------------------
    # After merging, drop anything still too small to plausibly be a
    # standalone wall. Kept deliberately small -- real buildings can have
    # small walls (a short pony wall, a low parapet return, etc), so this
    # should only catch clear modeling noise, not legitimate small walls.
    # Change this single number to make the filter stricter/looser.
    MIN_LOGICAL_WALL_AREA_M2 = 0.2

    def self.merge(wall_faces)
      face_groups = group_coplanar_fragments(wall_faces)
      logical_walls = pair_opposite_groups(face_groups)
      logical_walls.select { |w| w.area_m2 >= MIN_LOGICAL_WALL_AREA_M2 }
    end

    # ---------------- Stage A ------------------------------------------

    def self.group_coplanar_fragments(wall_faces)
      groups = wall_faces.map { |w| descriptor_for(w) }

      # Repeatedly scan for pairs of groups that belong together and
      # merge them, until nothing more can be merged. This naturally
      # handles chains of fragments (A touches B, B touches C) even when
      # A and C alone wouldn't be considered close enough to merge.
      merged_any = true
      while merged_any
        merged_any = false
        # Materialize the pairs first -- we mutate `groups` inside the
        # loop (deleting merged-away entries), so we can't safely iterate
        # a live enumerator built from the same array.
        candidate_pairs = groups.combination(2).to_a

        candidate_pairs.each do |a, b|
          next unless groups.include?(a) && groups.include?(b)
          next unless same_physical_face?(a, b)

          merge_fragment_into!(a, b)
          groups.delete(b)
          merged_any = true
        end
      end

      groups
    end

    # Builds a lightweight description of one raw wall face (in meters),
    # used only internally by the merging logic below.
    def self.descriptor_for(wall_face)
      nx, ny = wall_face.normal_xy
      # The "tangent" direction is perpendicular to the wall's facing
      # direction -- i.e. the direction the wall actually runs in plan.
      tangent = [-ny, nx]

      points_m = wall_face.world_points.map do |p|
        [Geometry.length_to_m(p.x), Geometry.length_to_m(p.y), Geometry.length_to_m(p.z)]
      end

      t_values = points_m.map { |x, y, _z| (x * tangent[0]) + (y * tangent[1]) }
      offset = (points_m.first[0] * nx) + (points_m.first[1] * ny)
      zs = points_m.map { |_x, _y, z| z }
      cx = points_m.inject(0.0) { |total, p| total + p[0] } / points_m.length
      cy = points_m.inject(0.0) { |total, p| total + p[1] } / points_m.length

      {
        normal: [nx, ny],
        offset: offset,          # signed distance of this face's plane from the origin, along `normal`
        tmin: t_values.min,      # extent of this fragment along the wall's run direction
        tmax: t_values.max,
        zmin: zs.min,            # vertical extent
        zmax: zs.max,
        centroid: [cx, cy],
        area_m2: wall_face.area_m2,
        faces: [wall_face.face],
        points: wall_face.world_points,
        labels: wall_face.name ? [wall_face.name] : []
      }
    end

    # Do fragments a and b belong to the SAME physical face -- same
    # plane, same facing direction, close enough along the wall run?
    # Note: length and height are intentionally NOT compared here.
    def self.same_physical_face?(a, b)
      dot = (a[:normal][0] * b[:normal][0]) + (a[:normal][1] * b[:normal][1])
      return false if dot < SAME_DIRECTION_DOT_MIN

      return false if (a[:offset] - b[:offset]).abs > PLANE_OFFSET_TOLERANCE_M

      height_gap = [a[:zmin], b[:zmin]].max - [a[:zmax], b[:zmax]].min
      return false if height_gap > HEIGHT_TOLERANCE_M

      tangent_gap = [a[:tmin], b[:tmin]].max - [a[:tmax], b[:tmax]].min
      return false if tangent_gap > MAX_GAP_M

      true
    end

    def self.merge_fragment_into!(a, b)
      a[:tmin] = [a[:tmin], b[:tmin]].min
      a[:tmax] = [a[:tmax], b[:tmax]].max
      a[:zmin] = [a[:zmin], b[:zmin]].min
      a[:zmax] = [a[:zmax], b[:zmax]].max
      a[:area_m2] += b[:area_m2]
      a[:faces].concat(b[:faces])
      a[:points].concat(b[:points])
      a[:labels].concat(b[:labels])
      # Rough centroid update -- only used later to measure wall
      # thickness, so exact precision isn't necessary here.
      a[:centroid] = [
        (a[:centroid][0] + b[:centroid][0]) / 2.0,
        (a[:centroid][1] + b[:centroid][1]) / 2.0
      ]
      a
    end

    # ---------------- Stage B ------------------------------------------

    def self.pair_opposite_groups(groups)
      used = []
      logical_walls = []

      groups.each do |a|
        next if used.include?(a)

        partner = groups.find { |b| !b.equal?(a) && !used.include?(b) && opposite_sides_of_one_wall?(a, b) }

        if partner
          used << a
          used << partner
          logical_walls << build_wall_from_pair(a, partner)
        else
          used << a
          logical_walls << build_wall_from_single(a)
        end
      end

      logical_walls
    end

    # Do face groups a and b look like the two opposite faces (interior
    # + exterior) of the same solid wall -- not two unrelated walls that
    # happen to face each other across a room?
    def self.opposite_sides_of_one_wall?(a, b)
      dot = (a[:normal][0] * b[:normal][0]) + (a[:normal][1] * b[:normal][1])
      return false if dot > OPPOSITE_DIRECTION_DOT_MAX

      thickness = perpendicular_distance(a, b)
      return false if thickness < MIN_WALL_THICKNESS_M || thickness > MAX_WALL_THICKNESS_M

      height_gap = [a[:zmin], b[:zmin]].max - [a[:zmax], b[:zmax]].min
      return false if height_gap > HEIGHT_TOLERANCE_M

      overlap = [a[:tmax], b[:tmax]].min - [a[:tmin], b[:tmin]].max
      return false if overlap <= 0

      shorter_length = [a[:tmax] - a[:tmin], b[:tmax] - b[:tmin]].min
      return false if shorter_length <= 0 || (overlap / shorter_length) < MIN_OPPOSITE_OVERLAP_RATIO

      true
    end

    # Perpendicular distance between the two groups' planes, measured
    # along group a's facing direction -- this IS the wall's thickness.
    def self.perpendicular_distance(a, b)
      b_offset_along_a = (b[:centroid][0] * a[:normal][0]) + (b[:centroid][1] * a[:normal][1])
      (b_offset_along_a - a[:offset]).abs
    end

    def self.build_wall_from_pair(a, b)
      length_m = [a[:tmax], b[:tmax]].max - [a[:tmin], b[:tmin]].min
      height_m = ((a[:zmax] - a[:zmin]) + (b[:zmax] - b[:zmin])) / 2.0
      area_m2 = (a[:area_m2] + b[:area_m2]) / 2.0
      thickness_m = perpendicular_distance(a, b)
      base_z_m = [a[:zmin], b[:zmin]].min
      name = (a[:labels] + b[:labels]).first
      faces = a[:faces] + b[:faces]
      points = a[:points] + b[:points]

      LogicalWall.new(name, length_m.round(2), height_m.round(2), area_m2.round(2), thickness_m.round(3), base_z_m.round(2), faces, points)
    end

    def self.build_wall_from_single(a)
      length_m = a[:tmax] - a[:tmin]
      height_m = a[:zmax] - a[:zmin]
      LogicalWall.new(a[:labels].first, length_m.round(2), height_m.round(2), a[:area_m2].round(2), 0.0, a[:zmin].round(2), a[:faces], a[:points])
    end
  end
end
