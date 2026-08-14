require_relative 'geometry'
require_relative 'level_detector'

module ScopeBuildingAnalyzer
  module Validator
    SMALL_ROOM_M2 = 3.0                # rooms below this are flagged as "verify"
    OVERLAP_RATIO = 0.3                # bbox overlap area / smaller room area
    MIN_REASONABLE_WALL_HEIGHT_M = 1.0 # walls shorter than this look suspicious
    MAX_REASONABLE_WALL_HEIGHT_M = 6.0 # walls taller than this look suspicious
    OPENING_WALL_PROXIMITY_M = 0.5     # how close a wall must be to "host" a door/window

    # severity: :warning or :error (used to split the Errors/Warnings
    # counts shown in the Check Model dialog).
    Issue = Struct.new(:severity, :message)

    def self.run(rooms, walls, openings, levels, wall_matches)
      issues = []
      issues.concat(small_rooms(rooms))
      issues.concat(rooms_without_walls(rooms, wall_matches))
      issues.concat(overlapping_rooms(rooms))
      issues.concat(unusual_wall_heights(walls))
      issues.concat(openings_off_level(openings, levels))
      issues.concat(openings_without_host_wall(openings, walls))
      issues
    end

    def self.small_rooms(rooms)
      rooms.select { |r| r.area_m2 < SMALL_ROOM_M2 }.map do |r|
        Issue.new(:warning, "#{r.name || 'Unnamed room'} is only #{r.area_m2.round(2)} m2 -- confirm this is really a room, not a landing/closet/noise face.")
      end
    end

    def self.rooms_without_walls(rooms, wall_matches)
      rooms.select { |r| (wall_matches[r] || { count: 0 })[:count] == 0 }.map do |r|
        Issue.new(:error, "#{r.name || 'Unnamed room'} has no matched walls -- geometry may be missing, hidden, too far from the room boundary, or at a different floor level than expected.")
      end
    end

    def self.overlapping_rooms(rooms)
      issues = []
      rooms.combination(2).each do |a, b|
        box_a = bbox_xy(a.world_points)
        box_b = bbox_xy(b.world_points)
        overlap = overlap_area(box_a, box_b)
        next if overlap <= 0

        smaller_area = [a.area_m2, b.area_m2].min
        next if smaller_area <= 0 || overlap / smaller_area < OVERLAP_RATIO

        issues << Issue.new(:warning, "#{a.name || 'Room'} and #{b.name || 'Room'} overlap significantly -- possible duplicate detection or stacked faces.")
      end
      issues
    end

    def self.unusual_wall_heights(walls)
      walls.each_with_index.select { |w, _i| w.height_m < MIN_REASONABLE_WALL_HEIGHT_M || w.height_m > MAX_REASONABLE_WALL_HEIGHT_M }.map do |w, i|
        label = w.name || "Wall #{i + 1}"
        Issue.new(:warning, "#{label} has an unusual height (#{w.height_m} m) -- confirm this is correct.")
      end
    end

    def self.openings_off_level(openings, levels)
      return [] if levels.empty?

      openings.select do |o|
        nearest = LevelDetector.assign(o.base_z_m, levels)
        (nearest.elevation_m - o.base_z_m).abs > 2.0 # more than 2m from any known level
      end.map do |o|
        Issue.new(:warning, "#{o.name} (#{o.kind}) sits well away from any detected level -- check it isn't a stray or misplaced component.")
      end
    end

    def self.openings_without_host_wall(openings, walls)
      openings.select { |o| walls.none? { |w| wall_near_opening?(w, o) } }.map do |o|
        Issue.new(:error, "#{o.name} (#{o.kind}) has no host wall detected nearby -- check it isn't floating or mis-tagged.")
      end
    end

    def self.wall_near_opening?(wall, opening)
      wall.world_points.any? do |p|
        dx = Geometry.length_to_m(p.x) - opening.centroid_x_m
        dy = Geometry.length_to_m(p.y) - opening.centroid_y_m
        Math.sqrt((dx * dx) + (dy * dy)) <= OPENING_WALL_PROXIMITY_M
      end
    end

    def self.bbox_xy(points)
      xs = points.map(&:x)
      ys = points.map(&:y)
      { min_x: xs.min, max_x: xs.max, min_y: ys.min, max_y: ys.max }
    end

    def self.overlap_area(a, b)
      dx = [a[:max_x], b[:max_x]].min - [a[:min_x], b[:min_x]].max
      dy = [a[:max_y], b[:max_y]].min - [a[:min_y], b[:min_y]].max
      return 0.0 if dx <= 0 || dy <= 0
      Geometry.area_to_m2(dx * dy)
    end
  end
end
