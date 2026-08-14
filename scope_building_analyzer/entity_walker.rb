module ScopeBuildingAnalyzer
  # Every detector (rooms, walls, openings) needs to walk the same tree of
  # nested groups/components and accumulate the same transformations.
  # Centralizing that here means each detector only has to say what it's
  # looking for, not how to find it.
  module EntityWalker
    # Yields (face, world_transformation, parent_label) for every face
    # anywhere in the model.
    def self.each_face(entities = nil, transformation = Geom::Transformation.new, parent_label = nil, &block)
      entities ||= Sketchup.active_model.active_entities

      entities.each do |entity|
        case entity
        when Sketchup::Face
          block.call(entity, transformation, parent_label)
        when Sketchup::Group
          next if skip?(entity)
          label = readable_name(entity) || parent_label
          each_face(entity.entities, transformation * entity.transformation, label, &block)
        when Sketchup::ComponentInstance
          next if skip?(entity)
          label = readable_name(entity) || parent_label
          each_face(entity.definition.entities, transformation * entity.transformation, label, &block)
        end
      end
    end

    # Yields (instance, world_transformation, parent_label) for every
    # component instance anywhere in the model (used for door/window
    # detection, which keys off component names, not raw faces).
    def self.each_instance(entities = nil, transformation = Geom::Transformation.new, parent_label = nil, &block)
      entities ||= Sketchup.active_model.active_entities

      entities.each do |entity|
        case entity
        when Sketchup::ComponentInstance
          next if skip?(entity)
          world_transform = transformation * entity.transformation
          label = readable_name(entity) || parent_label
          block.call(entity, world_transform, label)
          each_instance(entity.definition.entities, world_transform, label, &block)
        when Sketchup::Group
          next if skip?(entity)
          label = readable_name(entity) || parent_label
          each_instance(entity.entities, transformation * entity.transformation, label, &block)
        end
      end
    end

    def self.skip?(entity)
      entity.hidden? || !entity.layer.visible?
    end

    def self.readable_name(entity)
      name = entity.respond_to?(:name) ? entity.name : nil
      return nil if name.nil? || name.strip.empty?
      name
    end
  end
end
