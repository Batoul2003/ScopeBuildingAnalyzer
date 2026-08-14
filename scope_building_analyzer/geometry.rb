module ScopeBuildingAnalyzer
  # SketchUp's Ruby API always returns lengths in inches and areas in
  # square inches, regardless of the model's display units. Every
  # conversion in the plugin should go through here so there's exactly
  # one place that knows the conversion factors.
  module Geometry
    SQIN_TO_SQM  = 0.00064516
    SQIN_TO_SQFT = 1.0 / 144.0
    IN_TO_M      = 0.0254
    IN_TO_FT     = 1.0 / 12.0
    FT_TO_M      = 0.3048
    SQFT_TO_SQM  = 0.09290304

    def self.area_to_m2(area_sqin)
      area_sqin * SQIN_TO_SQM
    end

    def self.area_to_sqft(area_sqin)
      area_sqin * SQIN_TO_SQFT
    end

    def self.length_to_m(length_in)
      length_in * IN_TO_M
    end

    def self.length_to_ft(length_in)
      length_in * IN_TO_FT
    end

    # Metric <-> imperial, used for display conversion and for parsing
    # user-entered values (e.g. a wall height typed in feet).
    def self.m_to_ft(length_m)
      length_m / FT_TO_M
    end

    def self.ft_to_m(length_ft)
      length_ft * FT_TO_M
    end

    def self.m2_to_sqft(area_m2)
      area_m2 / SQFT_TO_SQM
    end

    def self.sqft_to_m2(area_sqft)
      area_sqft * SQFT_TO_SQM
    end
  end
end

