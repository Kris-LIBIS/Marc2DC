# coding: utf-8
require "test_helper"

class TestMarcRecordFactory < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_something
    records = MarcRecordFactory.load('test/data/oai_marc.xml')
    assert(!records.empty?,"Failed to load MARC record")
    records.each {|record| assert(record.is_a? OaiMarcRecord)}
    records = MarcRecordFactory.load('test/data/oai_present.xml')
    assert(!records.empty?, "Failed to load Aleph OAI-PMH MARC record")
    records.each {|record| assert(record.is_a? OaiMarcRecord)}
    records = MarcRecordFactory.load('test/data/marc21.xml')
    assert(!records.empty?, "Failed to load MARC21 record")
    records.each {|record| assert(record.is_a? Marc21Record)}
  end
end