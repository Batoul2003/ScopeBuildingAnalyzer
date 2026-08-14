module ScopeBuildingAnalyzer
  module Highlighter
    # Selecting the faces (rather than recoloring them) is non-destructive
    # -- nothing about the model changes, and it's trivially undoable by
    # just clearing the selection.
    def self.highlight_faces(faces)
      model = Sketchup.active_model
      model.selection.clear
      model.selection.add(faces)
      model.active_view.zoom(model.selection) unless faces.empty?
    end

    def self.clear
      Sketchup.active_model.selection.clear
    end
  end
end
