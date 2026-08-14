require_relative 'geometry'

module ScopeBuildingAnalyzer
  # A wall "belongs" to a room if it starts at roughly the room's floor
  # level AND sits close to the room's boundary. A wall can belong to
  # more than one room (e.g. a shared partition), which is correct --
  # both rooms are bounded by it.
  module WallRoomMatcher
    PROXIMITY_M = 0.5      # how close a wall must be to a room's boundary
    LEVEL_TOLERANCE_M = 0.5 # wall base vs room floor level must be within this

    # Returns a Hash keyed by RoomFace => { walls:, area_m2:, avg_height_m:, count: }
    def self.match(rooms, walls)
      result = {}

      rooms.each do |room|
        room_level_m = Geometry.length_to_m(room.world_points.first.z)
        boundary = room_boundary_segments(room)

        matched = walls.select do |wall|
          next false if (wall.base_z_m - room_level_m).abs > LEVEL_TOLERANCE_M
          wall_near_boundary?(wall, boundary)
        end

        area = matched.inject(0.0) { |total, w| total + w.area_m2 }
        avg_height = matched.empty? ? 0.0 : matched.inject(0.0) { |total, w| total + w.height_m } / matched.length

        result[room] = { walls: matched, area_m2: area.round(2), avg_height_m: avg_height.round(2), count: matched.length }
      end

      result
    end

    def self.room_boundary_segments(room)
      pts = room.face.outer_loop.vertices.map { |v| v.position.transform(room.transformation) }
      pts.each_index.map { |i| [pts[i], pts[(i + 1) % pts.length]] }
    end

    # A logical wall can be long and made of several merged fragments, so
    # checking only its centroid could miss rooms it only partially
    # borders. Instead, check all of its corner points and consider it a
    # match if ANY of them sit close to this room's boundary.
    def self.wall_near_boundary?(wall, boundary)
      wall.world_points.any? { |p| distance_to_boundary([p.x, p.y], boundary) <= PROXIMITY_M }
    end

    def self.distance_to_boundary(point, segments)
      segments.map { |a, b| distance_point_to_segment(point, [a.x, a.y], [b.x, b.y]) }.min
    end

    def self.distance_point_to_segment(p, a, b)
      px, py = p
      ax, ay = a
      bx, by = b
      dx = bx - ax
      dy = by - ay
      len_sq = (dx * dx) + (dy * dy)

      t = len_sq.zero? ? 0.0 : (((px - ax) * dx) + ((py - ay) * dy)) / len_sq
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0

      cx = ax + (t * dx)
      cy = ay + (t * dy)
      Geometry.length_to_m(Math.sqrt(((px - cx)**2) + ((py - cy)**2)))
    end
  end
end
