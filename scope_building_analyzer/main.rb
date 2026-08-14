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
require_relative 'highlighter'
require_relative 'report'
require_relative 'ui'
require_relative 'analyzer'

module ScopeBuildingAnalyzer
  unless file_loaded?(__FILE__)
    menu = ::UI.menu("Extensions")
    menu.add_item("Scope Building Analyzer") { ScopeBuildingAnalyzer::Analyzer.run }
    file_loaded(__FILE__)
  end
end
