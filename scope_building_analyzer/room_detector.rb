module ScopeBuildingAnalyzer

  class RoomDetector

    MIN_ROOM_AREA_M2 = 1.0

    def self.find_rooms

      model = Sketchup.active_model
      entities = model.active_entities

      rooms = []

      entities.grep(Sketchup::Face).each do |face|

        # Only horizontal upward-facing faces
        next unless face.normal.z > 0.99

        # Convert area to square meters
        area_m2 = Geometry.area_to_m2(face.area)

        # Ignore very small faces
        next if area_m2 < MIN_ROOM_AREA_M2

        rooms << face

      end

      rooms

    end

  end

end