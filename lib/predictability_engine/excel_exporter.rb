# frozen_string_literal: true

require 'caxlsx'
require_relative 'raw_data_exporter'

module PredictabilityEngine
  module ExcelExporter
    CHART_WIDTH  = 1920
    CHART_HEIGHT = 1080

    def self.generate(items, images_path: nil)
      Axlsx::Package.new do |p|
        add_work_items_sheet(p.workbook, items)
        add_chart_sheets(p.workbook, images_path) if images_path
        return p.to_stream.read
      end
    end

    def self.add_work_items_sheet(workbook, items)
      workbook.add_worksheet(name: 'Work Items') do |sheet|
        sheet.add_row(RawDataExporter::HEADERS)
        items.each { |item| sheet.add_row(RawDataExporter.item_row(item)) }
      end
    end

    def self.add_chart_sheets(workbook, images_path)
      Dir.glob(File.join(images_path, '*.png')).each do |img_path|
        sheet_name = File.basename(img_path, '.png').tr('_', ' ').split.map(&:capitalize).join(' ')
        workbook.add_worksheet(name: sheet_name[0, 31]) do |sheet|
          sheet.page_setup.set(orientation: :landscape)
          sheet.add_image(image_src: img_path, noSelect: true, noMove: true) do |image|
            image.width  = CHART_WIDTH
            image.height = CHART_HEIGHT
            image.start_at(0, 0)
          end
        end
      end
    end

    private_class_method :add_work_items_sheet, :add_chart_sheets
  end
end
