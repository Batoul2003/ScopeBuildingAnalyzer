require_relative 'geometry'
require_relative 'entity_walker'

module ScopeBuildingAnalyzer
  Opening = Struct.new(:name, :kind, :width_m, :height_m, :area_m2, :base_z_m, :centroid_x_m, :centroid_y_m)

  module OpeningDetector
    # Matches typical door/window component names, e.g. "Door 36in",
    # "window_casement", "Sliding Window". This is name-based because
    # SketchUp has no built-in "this is a door" flag on plain geometry --
    # it relies on the modeler using sensible component names (which is
    # standard practice, and what SketchUp's own component library uses).
    NAME_PATTERN = /door|window/i
    WINDOW_PATTERN = /window/i

    def self.find_openings
      results = []
      EntityWalker.each_instance do |instance, world_transform, parent_label|
        process_instance(instance, world_transform, parent_label, results)
      end
      results
    end

    def self.process_instance(instance, world_transform, parent_label, results)
      inst_name = instance.name.to_s.strip
      def_name = instance.definition.name.to_s.strip
      label = inst_name.empty? ? def_name : inst_name
      return if label.empty?
      return unless label =~ NAME_PATTERN

      kind = label =~ WINDOW_PATTERN ? 'Window' : 'Door'

      bounds = instance.definition.bounds
      corners = (0..7).map { |i| bounds.corner(i).transform(world_transform) }
      xs = corners.map(&:x)
      ys = corners.map(&:y)
      zs = corners.map(&:z)

      width_in = [xs.max - xs.min, ys.max - ys.min].max
      height_in = zs.max - zs.min
      return if width_in <= 0 || height_in <= 0

      width_m = Geometry.length_to_m(width_in).round(2)
      height_m = Geometry.length_to_m(height_in).round(2)
      centroid_x_m = Geometry.length_to_m(xs.inject(0.0) { |total, v| total + v } / xs.length).round(2)
      centroid_y_m = Geometry.length_to_m(ys.inject(0.0) { |total, v| total + v } / ys.length).round(2)

      results << Opening.new(
        label, kind, width_m, height_m, (width_m * height_m).round(2),
        Geometry.length_to_m(zs.min).round(2), centroid_x_m, centroid_y_m
      )
    end
  end
end
