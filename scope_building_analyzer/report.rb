require_relative 'geometry'
require_relative 'quantity_takeoff'

module ScopeBuildingAnalyzer
  module Report
    # --- unit helpers -------------------------------------------------
    # Everything is stored internally in metric; these convert for
    # display/export only, so switching units never compounds rounding.
    def self.convert_area(area_m2, unit)
      unit == 'ft' ? Geometry.m2_to_sqft(area_m2) : area_m2
    end

    def self.convert_length(length_m, unit)
      unit == 'ft' ? Geometry.m_to_ft(length_m) : length_m
    end

    def self.area_label(unit)
      unit == 'ft' ? 'ft2' : 'm2'
    end

    def self.length_label(unit)
      unit == 'ft' ? 'ft' : 'm'
    end

    def self.room_label(summary_row, index)
      summary_row[:room].name || "Room #{index + 1}"
    end

    def self.by_level(summary)
      Hash[summary.group_by { |s| s[:room].level_z }.sort]
    end

    # --- plain text (used by nothing directly yet, kept for scripting) -
    def self.text(data, unit = 'm')
      a = area_label(unit)
      lines = ["Scope Building Analyzer", "========================", ""]
      lines << "Detected Rooms: #{data[:room_summary].length}"
      lines << "Total Floor Area: #{convert_area(data[:room_totals][:floor_area_m2], unit).round(2)} #{a}"
      lines << "Detected Walls: #{data[:walls].length}"
      lines << "Detected Openings: #{data[:openings].length}"
      lines.join("\n")
    end

    # --- CSV (raw room-by-room export) --------------------------------
    def self.csv(summary, unit = 'm')
      a = area_label(unit)
      l = length_label(unit)
      rows = ["Level,Room,Floor Area (#{a}),Perimeter (#{l}),Wall Area Est (#{a})"]
      summary.each_with_index do |s, i|
        rows << [
          s[:room].level_z,
          room_label(s, i).gsub(',', ' '),
          convert_area(s[:floor_area_m2], unit).round(2),
          convert_length(s[:perimeter_m], unit).round(2),
          convert_area(s[:wall_area_m2], unit).round(2)
        ].join(',')
      end
      rows.join("\n")
    end

    # --- Bill of Quantities CSV ----------------------------------------
    def self.boq_csv(data, unit = 'm')
      a = area_label(unit)
      l = length_label(unit)
      f = data[:finishes]
      dims = data[:dimensions]
      door_count = data[:openings].count { |o| o.kind == 'Door' }
      window_count = data[:openings].count { |o| o.kind == 'Window' }

      rows = ["Item,Description,Quantity,Unit"]
      rows << "Building Footprint,Overall plan area,#{convert_area(dims[:footprint_m2], unit).round(2)},#{a}"
      rows << "Building Width,Overall X extent,#{convert_length(dims[:width_m], unit).round(2)},#{l}"
      rows << "Building Depth,Overall Y extent,#{convert_length(dims[:depth_m], unit).round(2)},#{l}"
      rows << "Building Height,Overall Z extent,#{convert_length(dims[:height_m], unit).round(2)},#{l}"
      rows << "Levels,Detected building levels,#{data[:levels].length},count"
      rows << "Rooms,Detected rooms/floor areas,#{data[:room_summary].length},count"
      rows << "Floor Area,Total detected floor area,#{convert_area(data[:room_totals][:floor_area_m2], unit).round(2)},#{a}"
      rows << "Floor Finish,Floor finish incl. #{f[:wastage_pct]}% wastage,#{convert_area(f[:floor_finish_m2], unit).round(2)},#{a}"
      rows << "Ceiling Finish,Ceiling finish incl. #{f[:wastage_pct]}% wastage,#{convert_area(f[:ceiling_finish_m2], unit).round(2)},#{a}"
      rows << "Wall Area (Gross),All detected wall faces,#{convert_area(f[:gross_wall_area_m2], unit).round(2)},#{a}"
      rows << "Openings Area,Total door+window area,#{convert_area(f[:opening_area_m2], unit).round(2)},#{a}"
      rows << "Wall Area (Net),Gross wall area minus openings,#{convert_area(f[:net_wall_area_m2], unit).round(2)},#{a}"
      rows << "Wall Finish,Paintable wall area incl. #{f[:wastage_pct]}% wastage,#{convert_area(f[:wall_finish_m2], unit).round(2)},#{a}"
      rows << "Doors,Detected door components,#{door_count},count"
      rows << "Windows,Detected window components,#{window_count},count"
      rows.join("\n")
    end

    # --- HTML dialog ----------------------------------------------------
    def self.html(data, unit = 'm')
      a = area_label(unit)
      l = length_label(unit)

      "<html><head>#{styles}</head><body>" \
        "#{header}" \
        "#{settings_panel(unit)}" \
        "#{dimensions_section(data[:dimensions], unit, a, l)}" \
        "#{levels_section(data[:levels], unit, l)}" \
        "#{rooms_section(data[:room_summary], data[:room_totals], unit, a, l)}" \
        "#{walls_section(data[:walls], unit, a, l)}" \
        "#{openings_section(data[:openings], unit, a, l)}" \
        "#{finishes_section(data[:finishes], unit, a)}" \
        "#{action_buttons}" \
        "#{script_tag}" \
        "</body></html>"
    end

    def self.styles
      <<-CSS
<style>
  body { font-family: -apple-system, Helvetica, Arial, sans-serif; padding: 12px; font-size: 13px; color: #222; }
  h2 { margin: 0 0 4px 0; }
  h3 { margin: 16px 0 4px 0; font-size: 13px; border-bottom: 1px solid #ddd; padding-bottom: 3px; }
  .hint { color: #777; font-size: 11px; margin-bottom: 10px; }
  .settings { display: flex; align-items: center; gap: 14px; background: #f7f7f7; border: 1px solid #e2e2e2; border-radius: 4px; padding: 8px 10px; margin-bottom: 10px; flex-wrap: wrap; }
  .settings label { font-size: 12px; display: flex; align-items: center; gap: 4px; }
  .settings input, .settings select { font-size: 12px; padding: 2px 4px; }
  .settings input[type="number"] { width: 60px; }
  table { width: 100%; border-collapse: collapse; margin-top: 4px; }
  th, td { text-align: left; padding: 4px 8px; border-bottom: 1px solid #e2e2e2; }
  th { background: #f2f2f2; }
  h3.toggle { cursor: pointer; user-select: none; }
  h3.toggle .arrow { float: right; font-size: 11px; color: #888; }
  .level-row td { background: #e8eef7; font-weight: bold; }
  .totals { margin-top: 8px; font-weight: bold; line-height: 1.6; }
  .buttons { margin-top: 16px; }
  button { padding: 6px 14px; margin-right: 8px; margin-bottom: 6px; cursor: pointer; }
  .kpis { display: flex; gap: 18px; flex-wrap: wrap; margin: 6px 0 10px 0; }
  .kpi { background: #f7f7f7; border: 1px solid #e2e2e2; border-radius: 4px; padding: 6px 12px; }
  .kpi .label { font-size: 11px; color: #777; }
  .kpi .value { font-size: 15px; font-weight: bold; }
  .empty { color: #999; font-size: 12px; font-style: italic; }
</style>
      CSS
    end

    def self.header
      '<h2>Scope Building Analyzer</h2><div class="hint">Room wall area/height come from walls matched to that room\'s boundary (proximity + floor level). Use "Check Model" below to see flagged issues.</div>'
    end

    def self.settings_panel(unit)
      metric_selected = unit == 'm' ? 'selected' : ''
      imperial_selected = unit == 'ft' ? 'selected' : ''

      "<div class=\"settings\">" \
        "<label>Units: <select id=\"unitSelect\" onchange=\"applyUnit(this.value)\">" \
        "<option value=\"m\" #{metric_selected}>Metric (m)</option>" \
        "<option value=\"ft\" #{imperial_selected}>Imperial (ft)</option>" \
        "</select></label>" \
        "</div>"
    end

    def self.dimensions_section(dims, unit, a, l)
      "<h3>Overall Building Dimensions</h3><div class=\"kpis\">" \
        "#{kpi('Width', "#{convert_length(dims[:width_m], unit).round(2)} #{l}")}" \
        "#{kpi('Depth', "#{convert_length(dims[:depth_m], unit).round(2)} #{l}")}" \
        "#{kpi('Height', "#{convert_length(dims[:height_m], unit).round(2)} #{l}")}" \
        "#{kpi('Footprint', "#{convert_area(dims[:footprint_m2], unit).round(2)} #{a}")}" \
        "</div>"
    end

    def self.kpi(label, value)
      "<div class=\"kpi\"><div class=\"label\">#{label}</div><div class=\"value\">#{value}</div></div>"
    end

    def self.levels_section(levels, unit, l)
      return "<h3>Building Levels</h3><div class=\"empty\">No distinct levels detected.</div>" if levels.empty?

      rows = levels.map do |lvl|
        "<tr><td>#{lvl.name}</td><td>#{convert_length(lvl.elevation_m, unit).round(2)} #{l}</td></tr>"
      end.join

      "<h3>Building Levels</h3><table><tr><th>Level</th><th>Elevation</th></tr>#{rows}</table>"
    end

    def self.rooms_section(summary, totals, unit, a, l)
      return collapsible_section('rooms-body', 'Rooms / Floor Areas', '<div class="empty">No rooms detected.</div>') if summary.empty?

      body_rows = by_level(summary).map do |level, rows|
        room_rows = rows.each_with_index.map do |s, i|
          wall_height_cell = s[:wall_count] > 0 ? "#{convert_length(s[:wall_height_m], unit).round(2)}" : "&ndash;"
          "<tr><td>#{room_label(s, i)}</td><td>#{convert_area(s[:floor_area_m2], unit).round(2)}</td>" \
          "<td>#{convert_length(s[:perimeter_m], unit).round(2)}</td>" \
          "<td>#{convert_area(s[:wall_area_m2], unit).round(2)}</td>" \
          "<td>#{wall_height_cell}</td><td>#{s[:wall_count]}</td></tr>"
        end.join
        "<tr class='level-row'><td colspan='6'>Level Z = #{level}&quot;</td></tr>#{room_rows}"
      end.join

      content = "<table><tr><th>Room</th><th>Floor (#{a})</th><th>Perimeter (#{l})</th>" \
        "<th>Wall area (#{a})</th><th>Wall height (#{l})</th><th>Walls</th></tr>#{body_rows}</table>" \
        "<div class=\"totals\">Rooms: #{summary.length} | " \
        "Total Floor Area: #{convert_area(totals[:floor_area_m2], unit).round(2)} #{a} | " \
        "Total Matched Wall Area: #{convert_area(totals[:wall_area_m2], unit).round(2)} #{a}</div>"

      collapsible_section('rooms-body', 'Rooms / Floor Areas', content)
    end

    def self.walls_section(walls, unit, a, l)
      return collapsible_section('walls-body', 'Detected Walls', '<div class="empty">No vertical wall faces detected.</div>') if walls.empty?

      rows = walls.each_with_index.map do |w, i|
        # thickness_m is 0.0 when only one face was found for this wall
        # (no matching opposite face was detected), so we can't measure
        # thickness -- show that honestly instead of a fake "0".
        thickness_cell = w.thickness_m > 0 ? convert_length(w.thickness_m, unit).round(3) : "&ndash;"
        "<tr><td>#{w.name || "Wall #{i + 1}"}</td><td>#{convert_length(w.length_m, unit).round(2)}</td>" \
        "<td>#{convert_length(w.height_m, unit).round(2)}</td><td>#{thickness_cell}</td>" \
        "<td>#{convert_area(w.area_m2, unit).round(2)}</td></tr>"
      end.join

      total_area = walls.inject(0.0) { |t, w| t + w.area_m2 }

      content = "<table><tr><th>Wall</th><th>Length (#{l})</th><th>Height (#{l})</th><th>Thickness (#{l})</th><th>Area (#{a})</th></tr>#{rows}</table>" \
        "<div class=\"totals\">Walls: #{walls.length} | Total Wall Area: #{convert_area(total_area, unit).round(2)} #{a}</div>"

      collapsible_section('walls-body', 'Detected Walls', content)
    end

    def self.openings_section(openings, unit, a, l)
      return collapsible_section('openings-body', 'Doors &amp; Windows', '<div class="empty">No door/window components detected (named components required).</div>') if openings.empty?

      rows = openings.map do |o|
        "<tr><td>#{o.name}</td><td>#{o.kind}</td><td>#{convert_length(o.width_m, unit).round(2)}</td>" \
        "<td>#{convert_length(o.height_m, unit).round(2)}</td><td>#{convert_area(o.area_m2, unit).round(2)}</td></tr>"
      end.join

      doors = openings.count { |o| o.kind == 'Door' }
      windows = openings.count { |o| o.kind == 'Window' }

      content = "<table><tr><th>Name</th><th>Type</th><th>Width (#{l})</th><th>Height (#{l})</th><th>Area (#{a})</th></tr>#{rows}</table>" \
        "<div class=\"totals\">Doors: #{doors} | Windows: #{windows}</div>"

      collapsible_section('openings-body', 'Doors &amp; Windows', content)
    end

    # Renders a clickable <h3> header that toggles a content <div> below
    # it via the toggleSection() JS helper (see script_tag). Sections
    # start expanded; clicking the header collapses/expands them.
    def self.collapsible_section(id, title, content_html)
      "<h3 class=\"toggle\" onclick=\"toggleSection('#{id}')\">#{title} <span class=\"arrow\" id=\"#{id}-arrow\">&#9662;</span></h3>" \
        "<div id=\"#{id}\">#{content_html}</div>"
    end

    def self.finishes_section(f, unit, a)
      "<h3>Finish Quantities (incl. #{f[:wastage_pct]}% wastage)</h3><div class=\"kpis\">" \
        "#{kpi('Floor Finish', "#{convert_area(f[:floor_finish_m2], unit).round(2)} #{a}")}" \
        "#{kpi('Ceiling Finish', "#{convert_area(f[:ceiling_finish_m2], unit).round(2)} #{a}")}" \
        "#{kpi('Wall Finish (net)', "#{convert_area(f[:wall_finish_m2], unit).round(2)} #{a}")}" \
        "</div>"
    end

    def self.action_buttons
      '<div class="buttons">' \
        '<button onclick="sketchup.check_model()">Check Model</button>' \
        '<button onclick="sketchup.export_csv()">Export Room CSV</button>' \
        '<button onclick="sketchup.export_boq()">Export BOQ CSV</button>' \
        '<button onclick="sketchup.highlight_rooms()">Highlight Rooms</button>' \
        '<button onclick="sketchup.highlight_walls()">Highlight Walls</button>' \
        '<button onclick="sketchup.clear_highlight()">Clear Highlight</button>' \
        '<button onclick="sketchup.refresh()">Refresh</button>' \
        '</div>'
    end

    # Renders the content for the separate "Check Model" dialog -- a
    # short pass/fail checklist plus the flagged issues, with an
    # Errors/Warnings count at the bottom.
    def self.model_check_html(data)
      rooms_ok = !data[:rooms].empty?
      walls_ok = !data[:walls].empty?

      checks = [
        { label: 'Rooms detected', passed: rooms_ok },
        { label: 'Floors detected', passed: rooms_ok }, # floors == rooms in this analyzer
        { label: 'Walls detected', passed: walls_ok }
      ]

      check_rows = checks.map do |c|
        icon = c[:passed] ? '&#10003;' : '&#10007;' # check mark / x mark
        css = c[:passed] ? 'ok' : 'error'
        "<div class=\"check-line #{css}\">#{icon} #{c[:label]}</div>"
      end.join

      issues = data[:issues]
      error_count = issues.count { |i| i.severity == :error }
      warning_count = issues.count { |i| i.severity == :warning }

      issue_rows = issues.map do |i|
        icon = i.severity == :error ? '&#10007;' : '&#9888;' # x mark / warning triangle
        "<div class=\"check-line #{i.severity}\">#{icon} #{i.message}</div>"
      end.join
      issue_rows = '<div class="empty">No issues found.</div>' if issues.empty?

      <<-HTML
<html>
<head>
<style>
  body { font-family: -apple-system, Helvetica, Arial, sans-serif; padding: 12px; font-size: 13px; color: #222; }
  h2 { margin: 0 0 10px 0; }
  .check-line { padding: 3px 0; }
  .check-line.ok { color: #2e7d32; }
  .check-line.warning { color: #a4302a; }
  .check-line.error { color: #b00020; font-weight: bold; }
  .summary { margin-top: 14px; font-weight: bold; border-top: 1px solid #ddd; padding-top: 8px; }
  .empty { color: #999; font-style: italic; }
</style>
</head>
<body>
  <h2>MODEL CHECK</h2>
  #{check_rows}
  <div style="margin-top:10px;">#{issue_rows}</div>
  <div class="summary">Errors: #{error_count}<br>Warnings: #{warning_count}</div>
</body>
</html>
      HTML
    end

    def self.script_tag
      '<script>' \
        'function applyUnit(unit){' \
        'sketchup.apply_settings(unit);' \
        '}' \
        'function toggleSection(id){' \
        'var el=document.getElementById(id);' \
        'var arrow=document.getElementById(id+"-arrow");' \
        'if(el.style.display==="none"){' \
        'el.style.display="";' \
        'if(arrow){arrow.innerHTML="&#9662;";}' \
        '}else{' \
        'el.style.display="none";' \
        'if(arrow){arrow.innerHTML="&#9656;";}' \
        '}' \
        '}' \
        '</script>'
    end
  end
end
