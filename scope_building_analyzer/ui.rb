require_relative 'geometry'
require_relative 'room_detector'
require_relative 'quantity_takeoff'
require_relative 'report'
require_relative 'highlighter'

module ScopeBuildingAnalyzer
  # Note: this module is named UI, same as SketchUp's built-in top-level
  # UI module (UI.messagebox, UI::HtmlDialog, etc). Inside this file we
  # always prefix SketchUp's version with `::UI` to avoid ambiguity.
  module UI
    # data - the full detection package built by Analyzer.build_data
    def self.show_report(data)
      dialog = ::UI::HtmlDialog.new(
        dialog_title: "Scope Building Analyzer",
        preferences_key: "ScopeBuildingAnalyzer",
        width: 560,
        height: 680,
        resizable: true
      )

      state = { data: data, unit: 'm' }

      render = lambda do
        dialog.set_html(Report.html(state[:data], state[:unit]))
      end
      render.call

      dialog.add_action_callback("export_csv") do |_ctx|
        path = ::UI.savepanel("Export Room CSV", "", "scope_rooms.csv")
        if path
          path += ".csv" unless path.end_with?(".csv")
          File.write(path, Report.csv(state[:data][:room_summary], state[:unit]))
          ::UI.messagebox("Exported to #{path}")
        end
      end

      dialog.add_action_callback("export_boq") do |_ctx|
        path = ::UI.savepanel("Export Bill of Quantities", "", "scope_boq.csv")
        if path
          path += ".csv" unless path.end_with?(".csv")
          File.write(path, Report.boq_csv(state[:data], state[:unit]))
          ::UI.messagebox("Exported to #{path}")
        end
      end

      dialog.add_action_callback("highlight_rooms") do |_ctx|
        Highlighter.highlight_faces(state[:data][:rooms].map(&:face))
      end

      dialog.add_action_callback("highlight_walls") do |_ctx|
        # Each logical wall may be built from several merged raw faces,
        # so flatten before highlighting.
        Highlighter.highlight_faces(state[:data][:walls].flat_map(&:faces))
      end

      dialog.add_action_callback("clear_highlight") do |_ctx|
        Highlighter.clear
      end

      # Reused across clicks so repeated "Check Model" presses update the
      # same window instead of stacking new ones.
      check_dialog = nil

      dialog.add_action_callback("check_model") do |_ctx|
        check_dialog ||= ::UI::HtmlDialog.new(
          dialog_title: "Model Check",
          preferences_key: "ScopeBuildingAnalyzerCheck",
          width: 420,
          height: 480,
          resizable: true
        )
        check_dialog.set_html(Report.model_check_html(state[:data]))
        check_dialog.show
      end

      dialog.add_action_callback("refresh") do |_ctx|
        rooms = RoomDetector.find_rooms
        if rooms.empty?
          ::UI.messagebox("No rooms detected on refresh -- keeping the previous results.")
        else
          state[:data] = Analyzer.build_data(rooms)
        end
        render.call
      end

      dialog.add_action_callback("apply_settings") do |_ctx, unit|
        state[:unit] = %w[m ft].include?(unit) ? unit : 'm'
        render.call
      end

      dialog.show
      dialog
    end
  end
end
