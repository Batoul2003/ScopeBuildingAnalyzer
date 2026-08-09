module ScopeBuildingAnalyzer

  unless file_loaded?(__FILE__)

    menu = UI.menu("Extensions")

    menu.add_item("Scope Building Analyzer") {

      ScopeBuildingAnalyzer::Analyzer.run

    }

    file_loaded(__FILE__)

  end

end