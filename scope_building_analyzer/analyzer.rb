require_relative 'geometry'
require_relative 'entity_walker'
require_relative 'room_detector'
require_relative 'wall_detector'
require_relative 'wall_merger'
require_relative 'opening_detector'
require_relative 'level_detector'
require_relative 'building_dimensions'
require_relative 'wall_room_matcher'
require_relative 'quantity_takeoff'
require_relative 'finishes'
require_relative 'validator'
require_relative 'report'
require_relative 'ui'

module ScopeBuildingAnalyzer
  class Analyzer
    def self.run
      model = Sketchup.active_model
      unless model
        ::UI.messagebox("No active SketchUp model.")
        return
      end

      rooms = RoomDetector.find_rooms
      if rooms.empty?
        ::UI.messagebox(
          "No room/floor faces detected.\n\n" \
          "Faces must be roughly horizontal and upward-facing, and at " \
          "least #{RoomDetector::MIN_ROOM_AREA_M2} m² in area. If your " \
          "geometry is inside nested groups or components, it should " \
          "still be found -- check that it isn't hidden or on a hidden layer/tag."
        )
        return
      end

      data = build_data(rooms)
      UI.show_report(data)
    end

    # Runs every detector/validator and packages the results. Called both
    # for the initial run and whenever the dialog needs a full re-scan.
    def self.build_data(rooms)
      raw_wall_faces = WallDetector.find_walls
      walls = WallMerger.merge(raw_wall_faces) # combine fragments into real, physical walls
      openings = OpeningDetector.find_openings
      levels = LevelDetector.detect(rooms.map { |r| Geometry.length_to_m(r.world_points.first.z) })
      dimensions = BuildingDimensions.overall
      wall_matches = WallRoomMatcher.match(rooms, walls)
      room_summary = QuantityTakeoff.summarize(rooms, wall_matches)
      room_totals = QuantityTakeoff.totals(room_summary)
      finishes = Finishes.summarize(rooms, walls, openings)
      issues = Validator.run(rooms, walls, openings, levels, wall_matches)

      {
        rooms: rooms,
        walls: walls,
        openings: openings,
        levels: levels,
        dimensions: dimensions,
        room_summary: room_summary,
        room_totals: room_totals,
        finishes: finishes,
        issues: issues
      }
    end
  end
end
