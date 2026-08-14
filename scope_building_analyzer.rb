require 'sketchup.rb'
require 'extensions.rb'

module ScopeBuildingAnalyzer
  unless file_loaded?(__FILE__)
    EXTENSION = ::SketchupExtension.new(
      "Scope Building Analyzer",
      "scope_building_analyzer/main.rb"
    )
    EXTENSION.description = "Detects rooms/floors anywhere in the model " \
      "(including inside groups and components) and estimates floor and " \
      "wall areas for scope-of-work takeoffs."
    EXTENSION.version     = "1.0.0"
    EXTENSION.creator     = "Your Name"
    EXTENSION.copyright   = "#{Time.now.year}"

    # `true` = load automatically. Registering this way (instead of loading
    # everything immediately) lets users enable/disable the extension from
    # Window > Extension Manager, and SketchUp only loads main.rb when the
    # extension is actually turned on.
    Sketchup.register_extension(EXTENSION, true)

    file_loaded(__FILE__)
  end
end
