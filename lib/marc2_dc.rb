# coding: utf-8

require 'marc_record_factory'

class Marc2DC

  def initialize(file_name)
    records = MarcRecordFactory.load(file_name)

    records.each_with_index do |record, index|
      dc_record = record.to_dc("Converted record ##{index}")
      fd = File.open("dc_#{index}.xml", 'w')
      dc_record.doc.write_xml_to(fd, :indent => 2, :encoding => 'utf-8')
      fd.close
    end
  end

end