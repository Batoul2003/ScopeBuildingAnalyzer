require_relative 'geometry'

module ScopeBuildingAnalyzer
  module QuantityTakeoff
    # Perimeter length (inches, world space) of a room's outer boundary.
    # Kept as an independent metric -- it's a straightforward geometric
    # property of the room, useful regardless of whether walls were
    # matched to it.
    def self.perimeter_for(room)
      room.face.outer_loop.edges.inject(0.0) { |total, edge| total + edge_length(edge, room.transformation) }
    end

    def self.edge_length(edge, transformation)
      p1 = edge.start.position.transform(transformation)
      p2 = edge.end.position.transform(transformation)
      p1.distance(p2)
    end

    # wall_matches - Hash from WallRoomMatcher.match: RoomFace => { area_m2:, avg_height_m:, count: }
    # Wall area/height here are real measured values from matched walls,
    # not an assumption. A room with no matched walls shows 0 -- that's
    # a real, honest "nothing detected here", and Validator separately
    # flags it so it doesn't get missed.
    def self.summarize(rooms, wall_matches)
      rooms.map do |room|
        match = wall_matches[room] || { area_m2: 0.0, avg_height_m: 0.0, count: 0 }
        perimeter_m = Geometry.length_to_m(perimeter_for(room))

        {
          room: room,
          floor_area_m2: room.area_m2,
          perimeter_m: perimeter_m,
          wall_area_m2: match[:area_m2],
          wall_height_m: match[:avg_height_m],
          wall_count: match[:count]
        }
      end
    end

    def self.totals(summary)
      {
        floor_area_m2: summary.inject(0.0) { |total, s| total + s[:floor_area_m2] },
        perimeter_m: summary.inject(0.0) { |total, s| total + s[:perimeter_m] },
        wall_area_m2: summary.inject(0.0) { |total, s| total + s[:wall_area_m2] }
      }
    end
  end
end
