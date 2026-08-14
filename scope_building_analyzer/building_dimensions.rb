require_relative 'geometry'

module ScopeBuildingAnalyzer
  module BuildingDimensions
    # Every top-level Group/ComponentInstance/Face/Edge has a #bounds
    # method whose box already accounts for everything nested inside it,
    # transformed into the model's coordinate system. Summing the
    # top-level entities' boxes is therefore enough to get the true
    # overall extent, without us having to recurse ourselves.
    def self.overall
      model = Sketchup.active_model
      bb = Geom::BoundingBox.new

      model.entities.each do |entity|
        bb.add(entity.bounds) if entity.respond_to?(:bounds)
      end

      width_m = Geometry.length_to_m(bb.width)
      depth_m = Geometry.length_to_m(bb.depth)
      height_m = Geometry.length_to_m(bb.height)

      {
        width_m: width_m.round(2),
        depth_m: depth_m.round(2),
        height_m: height_m.round(2),
        footprint_m2: (width_m * depth_m).round(2)
      }
    end
  end
end
