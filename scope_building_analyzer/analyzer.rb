module ScopeBuildingAnalyzer

  class Analyzer

    def self.run

      model = Sketchup.active_model

      rooms = RoomDetector.find_rooms

      report = "Scope Building Analyzer\n"
      report << "========================\n\n"

      total_area = 0

      rooms.each_with_index do |face, index|

        area_m2 = Geometry.area_to_m2(face.area)

        total_area += area_m2

        report << "Room #{index + 1}: #{area_m2.round(2)} m²\n"

      end

      report << "\n------------------------\n"
      report << "Detected Areas: #{rooms.length}\n"
      report << "Total Floor Area: #{total_area.round(2)} m²"

      UI.messagebox(report)

    end

  end

end