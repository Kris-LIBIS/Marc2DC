# coding: utf-8

#noinspection RubyResolve
require 'nokogiri'

require './lib/marc_record'
require './lib/oai_marc_record'
require './lib/marc21_record'

class MarcRecordFactory

  def self.load(xml_file)
    #noinspection RubyResolve
    xml_document = Nokogiri::XML.parse(File.open(xml_file))
    get_marc_records(xml_document)
  end

  def self.parse(xml_string)
    #noinspection RubyResolve
    xml_document = Nokogiri::XML.parse(xml_string)
    get_marc_records(xml_document)
  end

  private

  def self.get_marc_records(xml_document)
    xml_document.remove_namespaces!
    #noinspection RubyStringKeysInHashInspection
    oai_marc_records = xml_document.root.xpath('//oai_marc')
    return oai_marc_records.collect { |x| OaiMarcRecord.new(x) } unless oai_marc_records.empty?
    #noinspection RubyStringKeysInHashInspection
    marc21_records = xml_document.root.xpath('//record')
    marc21_records.collect { |x| Marc21Record.new(x) }
  end

end