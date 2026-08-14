module ScopeBuildingAnalyzer
  module Finishes
    DEFAULT_WASTAGE = 0.10 # 10% -- typical allowance for cuts/offcuts

    # rooms   - RoomFace list (for floor/ceiling area)
    # walls   - WallFace list (for gross wall area)
    # openings - Opening list (subtracted from wall area, since you don't
    #            paint/tile a door or window)
    def self.summarize(rooms, walls, openings, wastage: DEFAULT_WASTAGE)
      floor_area_m2 = rooms.inject(0.0) { |total, r| total + r.area_m2 }
      ceiling_area_m2 = floor_area_m2 # same footprint, standard assumption

      gross_wall_area_m2 = walls.inject(0.0) { |total, w| total + w.area_m2 }
      opening_area_m2 = openings.inject(0.0) { |total, o| total + o.area_m2 }
      net_wall_area_m2 = [gross_wall_area_m2 - opening_area_m2, 0.0].max

      {
        floor_finish_m2: (floor_area_m2 * (1 + wastage)).round(2),
        ceiling_finish_m2: (ceiling_area_m2 * (1 + wastage)).round(2),
        wall_finish_m2: (net_wall_area_m2 * (1 + wastage)).round(2),
        gross_wall_area_m2: gross_wall_area_m2.round(2),
        opening_area_m2: opening_area_m2.round(2),
        net_wall_area_m2: net_wall_area_m2.round(2),
        wastage_pct: (wastage * 100).round(0)
      }
    end
  end
end
