module ScopeBuildingAnalyzer

  module Geometry

    SQIN_TO_SQM = 0.00064516

    def self.area_to_m2(area)

      area * SQIN_TO_SQM

    end

  end

end