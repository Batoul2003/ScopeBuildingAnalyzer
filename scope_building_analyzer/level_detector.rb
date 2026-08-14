require_relative 'geometry'

module ScopeBuildingAnalyzer
  Level = Struct.new(:name, :elevation_m)

  module LevelDetector
    # Elevations within this range of each other are treated as the same
    # level (handles small modeling inaccuracies -- floors are rarely
    # perfectly co-planar down to the millimeter).
    CLUSTER_TOLERANCE_M = 0.3

    # elevations_m - flat array of Z values in meters (e.g. from room
    #                base elevations). Returns Level structs sorted
    #                bottom to top.
    def self.detect(elevations_m)
      sorted = elevations_m.uniq.sort
      clusters = []

      sorted.each do |z|
        if clusters.empty? || (z - clusters.last.last) > CLUSTER_TOLERANCE_M
          clusters << [z]
        else
          clusters.last << z
        end
      end

      clusters.each_with_index.map do |group, i|
        avg = group.inject(0.0) { |total, v| total + v } / group.length
        Level.new("Level #{i + 1}", avg.round(2))
      end
    end

    # Finds the closest known level for a given elevation.
    def self.assign(elevation_m, levels)
      return nil if levels.empty?
      levels.min_by { |lvl| (lvl.elevation_m - elevation_m).abs }
    end
  end
end
