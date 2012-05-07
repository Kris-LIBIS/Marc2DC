# coding: utf-8
require './lib/marc_record_factory'

xml = <<XML_END
<collection>
<record>
<leader>1234567890</leader>
<controlfield tag="001">001-1234567890</controlfield>
<controlfield tag="002">002-1</controlfield>
<controlfield tag="002">002-2</controlfield>
<datafield tag="100" ind1=" " ind2=" ">
  <subfield code="a">100-1-a1</subfield>
  <subfield code="a">100-1-a2</subfield>
  <subfield code="b">100-1-b1</subfield>
  <subfield code="b">100-1-b2</subfield>
  <subfield code="c">100-1-c1</subfield>
  <subfield code="c">100-1-c2</subfield>
</datafield>
</record>
<record>
<leader>0123456789</leader>
<controlfield tag="001">001-9876543210</controlfield>
<datafield tag="100" ind1=" " ind2=" ">
  <subfield code="a">100-1-a1</subfield>
  <subfield code="a">100-1-a2</subfield>
  <subfield code="b">100-1-b1</subfield>
</datafield>
<datafield tag="100" ind1=" " ind2=" ">
  <subfield code="a">100-2-a1</subfield>
  <subfield code="a">100-2-a2</subfield>
  <subfield code="c">100-2-c1</subfield>
</datafield>
<datafield tag="100" ind1=" " ind2=" ">
  <subfield code="a">100-3-a1</subfield>
  <subfield code="a">100-3-a2</subfield>
  <subfield code="b">100-3-b1</subfield>
  <subfield code="c">100-3-c1</subfield>
</datafield>
</record>
</collection>
XML_END
record1, record2 = MarcRecordFactory.parse(xml)
record2.each_field('100','a')
record2.each_field('100','b')
record2.each_field('100','c')
record2.each_field('100','ab')
record2.each_field('100','ac')
record2.each_field('100','abc')

puts '--'
puts record2.dump
puts '--'
puts record2.each_field('100','ab', false)
puts record2.dump
puts '--'
puts record2.each_field('100','ac', false)
puts record2.dump
puts '--'
puts record2.each_field('100','abc', false)
puts record2.dump
