require 'sketchup.rb'

module ScopeBuildingAnalyzer

  unless file_loaded?(__FILE__)

    require_relative 'scope_building_analyzer/analyzer'
    require_relative 'scope_building_analyzer/geometry'
    require_relative 'scope_building_analyzer/room_detector'
    require_relative 'scope_building_analyzer/quantity_takeoff'
    require_relative 'scope_building_analyzer/report'
    require_relative 'scope_building_analyzer/ui'

    file_loaded(__FILE__)

  end

end