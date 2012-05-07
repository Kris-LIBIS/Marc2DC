# coding: utf-8

#noinspection RubyResolve
require 'nokogiri'

require 'lib/dc_element'
require 'lib/xml_utils'
require 'lib/assert'
require 'lib/fix_field'
require 'lib/var_field'

class MarcRecord
  #noinspection RubyResolve
  include XmlUtils

  public

  def initialize(xml_node)
    @node = xml_node
  end

  def to_raw
    @node
  end

  def tag(t, subfields = '')
    tag = t[0..2]
    ind1 = t[3]
    ind2 = t[4]
    get(tag, ind1, ind2, subfields)
  end

  def each_field(t, s)
    tag(t, s).collect { |e| e.fields(s) }.flatten.compact
  end

  def first_field(t, s)
    each_field(t, s).first
  end

  def all_fields(t, s)
    tag(t, s).collect { |e| e.fields_array(s) }.flatten.compact
  end

  def each
    all.each do |k, v|
      yield k, v
    end
  end

  def all
    return @all_records if @all_records
    @all_records = get_all_records
  end

  def get(tag, ind1 = '', ind2 = '', subfields = '')

    ind1 ||= ''
    ind2 ||= ''
    subfields ||= ''

    record = all[tag]
    return record if record[0].is_a? FixField

    record.select do |v|
      (ind1.empty? or v.ind1 == ind1) && (ind2.empty? or v.ind2 == ind2) && v.match_fieldspec?(subfields)
    end

  end

  #noinspection RubyStringKeysInHashInspection,RubyResolve
  def to_dc(label = nil)

    Nokogiri::XML::Builder.new do |xml|
      xml.record('xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
                 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xmlns:dcterms' => 'http://purl.org/dc/terms/') {

        # DC:IDENTIFIER

        xml['dc'].identifier label if label

        # "urn:ControlNumber: " [MARC 001]
        tag('001').each { |e|
          xml['dc'].identifier element(e.datas, prefix: 'urn:ControlNumber: ')
        }

        # [MARC 035 $a]
        each_field('035', 'a').each { |e| xml['dc'].identifier e }

        # [MARC 24 8- $a]
        each_field('0248', 'a').each { |e| xml['dc'].identifier e }

        # [MARC 28 40 $b]": "[MARC 28 40 $a]
        tag('02840').each { |e|
          xml['dc'].identifier element(e._ba, join: ': ')
        }

        # [MARC 28 50 $b]": "[MARC 28 50 $a]
        tag('02850').each { |e|
          xml['dc'].identifier element(e._ba, join: ': ')
        }

        # "urn:ISBN:"[MARC 020 $a]
        each_field('020', 'a').each { |e|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(e, prefix: 'urn:ISBN:')
        }

        # "urn:ISSN:"[MARC 022 $a]
        each_field('022', 'a').each { |e|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(e, prefix: 'urn:ISSN:')
        }

        # "urn:ISMN:"[MARC 024 2- $a]
        each_field('0242', 'a').each { |e|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(e, prefix: 'urn:ISMN:')
        }

        # [MARC 690 02$0]
        each_field('69002', '0').each { |e| xml['dc'].identifier e }

        # [MARC 856 2$u]
        each_field('8562', 'u').each { |e| xml['dc'].identifier e }

        # DC:TITLE

        # [MARC 245 0 $a] " " [MARC 245 0 $b] " [" [MARC 245 0 $h] "]" "(In: [MARC 243 1 $a]/[MARC 440 $a] " " [MARC 440 $v]  ". " [MARC 440 $b] ")"
        tag('2450', 'a b h').each do |e|
          x = tag('440', 'a v b').collect { |g| element(g._a, {parts: g._v, postfix: '.'}, g._b, join: ' ') }
          y = each_field('2431', 'a').collect { |f| element(f, x, join: '/', prefix: '(In: ', posfix: ')') }
          xml['dc'].title element({parts: [e._ab, {parts: e._h, fix: '[]'}], join: ' '}, y)
        end

        # [MARC 245 1 $a] " " [MARC 245 1 $b] " [" [MARC 245 1 $h] "]"
        tag('2451', 'a b h').each { |e|
          xml['dc'].title(element(e._ab, {parts: e._h, prefix: '[', postfix: ']'}, join: ' ')
          )
        }

        # [MARC 130 $a] "(In: " [MARC 243 1 $a]/[MARC 440 $a] " " [MARC 440 $v]  ". " [MARC 440 $b] ")"
        tag('130', 'a').each { |e|
          x = tag('440', 'a v b').collect { |g| element(g._a, {parts: g._v, postfix: '.'}, g._b, join: ' ') }
          y = each_field('2431', 'a').collect { |f| element(f, x, join: '/', prefix: '(In: ', posfix: ')') }
          xml['dc'].title(element(e._a, y))
        }

        # [MARC 440 $v]  ". " [MARC 440 $b] ")"
        tag('440', 'b v').each { |e|
          xml['dc'].title element(e._bv, join: '. ', postfix: ')')
        }

        # DCTERMS:ALTERNATIVE

        # [MARC 240 1- $a] "(In: [MARC 243 1 $a]/[MARC 440 $a] ")"
        tag('2401 ', 'a').each { |e|
          x = tag('2341', 'a').collect { |f| element(f._a, each_field('440', 'a').first, join: '/', prefix: '(In: ', postfix: ')') }
          xml['dcterms'].alternative element(e._a, x)
        }

        # [MARC 242 1- $a] ". " [MARC 242 1- $b]
        tag('2421 ', 'ab').each { |e|
          xml['dcterms'].alternative element(e._ab, join: '. ')
        }

        # [MARC 246 11 $a] ". " [MARC 246 11 $b]
        tag('24611', 'a b').each { |e|
          xml['dcterms'].alternative element(e._ab, join: '. ')
        }

        # [MARC 246 13 $a] ". " [MARC 246 13 $b]
        tag('24613', 'a b').each { |e|
          xml['dcterms'].alternative element(e._ab, join: '. ')
        }

        # [MARC 210 10 $a]
        each_field('21010', 'a').each { |e|
          xml['dcterms'].alternative e
        }

        # DC:CREATOR

        # [MARC 100 1 $a] ", " [MARC 100 1 $b] ", " [MARC 100 1 $c] ", " [MARC 100 1 $d]  ( " [MARC 700 1 $4] ")
        tag('1001', 'a b c d 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(e._abcd, join: ', ', postfix: element(full_name(e), fix: '()'))
        }

        # [MARC 100 0 $a] ", " [MARC 100 0 $b] ", " [MARC 100 0 $c] ", " [MARC 100 0 $d] ( " [MARC 100 0 $4] ")
        tag('1000', 'a b c d 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(e._abcd, join: ', ', postfix: element(full_name(e), prefix: ' (', postfix: ')'))
        }

        # [MARC 700 1 $a] ", " [MARC 700 1 $b] ", " [MARC 700 1 $c] ", " [MARC 700 1 $d] ", " [MARC 700 1 $g] " ( " [MARC 700 1 $4] ") " ", " [MARC 700 1 $e]
        tag('7001', 'a b c d e g 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(element(e._abcdg, join: ', ', postfix: element(full_name(e), prefix: ' (', postfix: ') ')),
                                    e.field_array('e'), join: ', ')
        }

        # [MARC 700 0 $a] ", " [MARC 700 0 $b] ", " [MARC 700 0 $c] ", " [MARC 700 0 $d] ", " [MARC 700 0 $g] " ( " [MARC 700 0 $4] ") " ", " [MARC 700 0 $e]
        tag('7000', 'a b c d e g 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(element(e._abcdg, join: ', ', postfix: element(full_name(e), prefix: ' (', postfix: ') ')),
                                    e.field_array('e'), join: ', ')
        }

        # [MARC 710 $a] ","  [MARC 710 $g]" (" [MARC 710 $4] ") " ", " [MARC 710 $e]
        tag('710', 'a e g 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(element(e._ag, join: ', ', postfix: element(full_name(e), prefix: ' (', postfix: ') ')),
                                    e._e, join: ', ')
        }

        # [MARC 710 2- $a] ", " [MARC 710 2- $g] " (" [MARC 710 2- $4]")"
        tag('7102 ', 'ag4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(e._ag, join: ', ', postfix: element(full_name(e), prefix: ' (', postfix: ')'))
        }

        # [MARC 711$a] ", " [MARC 711$b] ", " [MARC 711$c] ", " [MARC 711$d] ", " [MARC 711$4]
        tag('711', 'a b c d 4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(e._abcd, full_name(e), join: ', ')
        }

        # [MARC 711 2- $a] [MARC 711 2- $n] " " [MARC 711 2- $d] " " "(" [MARC 711 2- $c] ")" ", " [MARC 711 2- $g]
        tag('7112 ', 'ancdg4').each { |e|
          next unless name_type(e) == :creator
          xml['dc'].creator element(element(
                                        element(e._an),
                                        e.subfield['d'],
                                        element(e._c, fix: '()'),
                                        join: ' '
                                    ),
                                    e._g, join: ', ')
        }

        # DC:SUBJECT

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}

        # [MARC 600 10 $a] " " [MARC 600 10 $b] " " [MARC 600 10 $c] " " [MARC 600 10 $d] " " [MARC 600 10 $g]
        tag('60010', 'a b c d g').each { |e|
          xml['dc'].subject(attributes).text element(e._abcdg, join: ' ')
        }

        # [MARC 600 00 $a] " " [MARC 600 00 $b] " " [MARC 600 00 $c] " " [MARC 600 00 $d] " " [MARC 600 00 $g]
        tag('60000', 'a b c d g').each { |e|
          xml['dc'].subject(attributes).text element(e._abcdg, join: ' ')
        }

        # [MARC 610 20 $a] " " [MARC 610 20 $c] " " [MARC 610 20 $d] " " [MARC 610 20 $g]
        tag('61020', 'a c d g').each { |e|
          xml['dc'].subject(attributes).text element(e._acdg, join: ' ')
        }

        # [MARC 611 20 $a] " " [MARC 611 20 $c] " " [MARC 611 20 $d] " " [MARC 611 20 $g] " " [MARC 611 20 $n]
        tag('61120', 'a c d g n').each { |e|
          xml['dc'].subject(attributes).text element(e._acdgn, join: ' ')
        }

        # [MARC 630 0 $a] " " [MARC 630 0 $f] " " [MARC 630 0 $g] " " [MARC 630 0 $l] " " [MARC 630 0 $m] " " [MARC 630 0 $n] " " [MARC 630 0 $o] " " [MARC 630 0 $p] " " [MARC 630 0 $r] " " [MARC 630 0 $s]
        tag('6300', 'a f g l m n o p r s').each { |e|
          xml['dc'].subject(attributes).text element(e._afglmnoprs, join: ' ')
        }

        # [MARC 650 10 $a] " " [MARC 650 10 $x] " " [MARC 650 10 $y] " " [MARC 650 10 $z]
        tag('65010', 'a x y z').each { |e|
          xml['dc'].subject(attributes).text element(e._axyz, join: ' ')
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/MESH'}
        # [MARC 650 2 $a] " " [MARC 650 2 $x]
        tag('6502', 'a x').each { |e|
          xml['dc'].subject(attributes).text element(e._ax, join: ' ')
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/UDC'}
        # [MARC 691 E1 $8] " " [ MARC 691 E1 $a]
        tag('691E1', 'a8').each { |e|
          x = taalcode(e._9)
          attributes['xml:lang'] = x if x
          xml['dc'].subject(attributes).text element(e._ax, join: ' ')
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/DDC', 'xml:lang' => 'en'}
        # [MARC 082 14 $a] " " [MARC 082 14 $x]
        tag('08214', 'a x').each { |e|
          xml['dc'].subject(attributes).text element(e._ax, join: ' ')
        }

        attributes = {'xml:lang' => 'en'}
        # [MARC 692 $a] [MARC 692 $y]
        tag('692', 'y').each { |e|
          xml['dc'].subject(attributes).text element(e._ay)
        }

        attributes = {'xml:lang' => 'nl'}
        # [MARC 692 $a] [MARC 692 $x]
        tag('692', 'x').each { |e|
          xml['dc'].subject(attributes).text element(e._ax)
        }

        attributes = {'xml:lang' => 'efr'}
        # [MARC 692 $a] [MARC 692 $z]
        tag('692', 'z').each { |e|
          xml['dc'].subject(attributes).text element(e._az)
        }

        # [MARC 700 0 $a] ", " [MARC 700 0 $b] ", " [MARC 700 0 $c] ", " [MARC 700 0 $d] ", " [MARC 700 0 $g] " ( " [MARC 700 0 $4] ") " ", " [MARC 700 0 $e]
        tag('7000', 'a b c d e g 4').each { |e|
          next unless name_type(e) == :subject
          xml['dc'].subject element(element(e._abcdg, join: ', ', postfix: element(full_name(e), fix: ' (|) ')),
                                    e._e, join: ', ')
        }

        # [MARC 710 2- $a] ", " [MARC 710 2- $g] " (" [MARC 710 2- $4]")"
        tag('7102 ', 'a g 4').each { |e|
          next unless name_type(e) == :subject
          xml['dc'].subject element(e._ag, join: ', ', postfix: element(full_name(e), fix: ' (|)'))
        }

        # [MARC 690 [xx]$a]
        tag('690', 'a').each { |e|
          # ???
          xml['dc'].subject element(bibnaam(e.ind1 + e.ind2))
        }

        # DC:TEMPORAL

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}
        # [MARC 648 0 $a] " " [MARC 648 0 $x] " " [MARC 648 0 $y] " " [MARC 648 0 $z]
        tag('6480', 'a x y z').each { |e|
          xml['dc'].temporal(attributes).text element(e._axyz, join: ' ')
        }

        # DC:DESCRIPTION

        x = element(
            # [MARC 598$a]
            each_field('598', 'a'),
            # [MARC 597$a]
            each_field('597', 'a'),
            # [MARC 500 $a]
            each_field('500', 'a'),
            # [MARC 520 $a]
            each_field('520', 'a'),
            # "Siglum: " [MARC 029 $a]
            element(each_field('029', 'a'), prefix: 'Siglum: '),
            # "Projectie: " [MARC 093 $a]
            element(each_field('093', 'a'), prefix: 'Projectie: '),
            # "Equidistance " [MARC 094 $a]
            element(each_field('094', 'a'), prefix: 'Equidistance '),
            # "Illustraties: [MARC 399 $a]  " " [MARC 399 $b] " (" [MARC 399 $9] ")"
            tag('399', 'a b 9').collect { |e|
              element(
                  e._ab,
                  element(e._9, fix: '()'),
                  join: ' ',
                  prefix: 'Illustraties: '
              )
            },
            # [MARC 500 $a]
            each_field('500', 'a'), # ??
            # [MARC 502 $a]
            each_field('502', 'a'),
            # [MARC 505 0- $a] " (" [MARC 505 0- $9] ")"
            tag('5050 ', 'a9').collect { |e|
              element(
                  e._a,
                  element(e.field_array('9'), fix: '()', join: ''), # ??
                  join: ' '
              )
            },
            # [MARC 505 0- $u]
            all_fields('5050 ', 'u'),
            # [MARC 505 2- $a] " (" [MARC 505 2- $9] ")"
            tag('5052 ', 'a9').collect { |e|
              element(
                  e._a,
                  element(e.field_array('9'), fix: '()', join: ''), # ??
                  join: ' '
              )
            },
            # [MARC 505 2- $u]
            all_fields('5052 ', 'u'),
            # [MARC 529 $a] ", " [MARC 529 $b] " (" [MARC 529 $9] ")"
            tag('529', 'a b 9').collect { |e|
              element(
                  e._ab,
                  join: ', ',
                  postfix: element(e._9, fix: ' (|)')
              )
            },
            # [MARC 545 $a]
            each_field('545', 'a'),
            # [MARC 597 $a]
            each_field('597', 'a'), # ??
            # [MARC 598 $a]
            each_field('598', 'a'), # ??
            # [MARC 586 $a]
            each_field('586', 'a'),
            join: ' ' # ??
        )
        xml['dc'].description x unless x.empty?

        # DCTERMS:ISVERSIONOF

        # [MARC 250 $a] " (" [MARC 250 $b] ")"
        tag('250', 'a b').each { |e|
          xml['dcterms'].isVersionOf element(e._a, element(e._b, fix: '()'), join: ' ')
        }

        # DC:ABSTRACT

        # [MARC 520 3- $a]
        each_field('5203 ', 'a').each { |e|
          xml['dc'].abstract e
        }

        # [MARC 520 39 $t] ": " [MARC 520 39 $a]
        tag('52039', 'a t').each { |e|
          xml['dc'].abstract element(e._ta, join: ': ')
        }

        # ??
        # [MARC 520 39 $t] ": " [MARC 520 39 $a]
        tag('52039', 'a t').each { |e|
          attributes = {}
          attributes['xml:lang'] = taalcode(e._9) if e.field_array('9').size == 1
          xml['dc'].abstract(attributes).text element(e._ta, join: ': ')
        }

        attributes = {'xsi:type' => 'dcterms:URI'}
        # [MARC 520 3- $u]
        all_fields('5203 ', 'u').each { |e|
          xml['dc'].abstract(attributes).text element(e)
        }

        # [MARC 520 39 $u]
        all_fields('52039', 'u').each { |e|
          xml['dc'].abstract(attributes).text element(e)
        }

        # DCTERMS:TABLEOFCONTENTS

        # [MARC 505 09 $a] "\n" [MARC 505 09 $9] "\n" [MARC 505 09 $u]
        tag('50509', 'a f u 9').each { |e|
          attributes = {'xml:lang' => "#{taalcode(each_field('0419 ', 'f').first)}"}
          xml['dcterms'].tableOfContents(attributes).text element(e._a9u, join: '\n')
        }

        # [MARC 591 $9] ":" [MARC 591 $a] " (" [MARC 591 $b] ")"
        tag('591', 'a b 9').each { |e|
          xml['dcterms'].tableOfContents element(e._9a, join: ':', postfix: element(e._b, fix: ' (|)'))
        }

        # DCTERMS:HASPART

        # [MARC 505 0- $t] ", '[MARC 505 0- $r]
        tag('5050 ', 'rt').each { |e|
          xml['dcterms'].hasPart element(e._t, e.field_array('r'), join: ', ')
        }

        # [MARC 505 2- $t] ", '[MARC 505 2- $r]
        tag('5052 ', 'rt').each { |e|
          xml['dcterms'].hasPart element(e._t, e.field_array('r'), join: ', ')
        }

        # [MARC LKR $m]
        each_field('LKR', 'm').each { |e|
          xml['dcterms'].hasPart e
        }

        # DC:CONTRIBUTOR

        # [MARC 700 19 $a] ", " [MARC 700 19 $b] ", " [MARC 700 19 $c] ", " [MARC 700 19 $d] ", " [MARC 700 19 $g] " ( " [MARC 700 19 $4] ")"
        tag('70019', 'a b c d g 4').each { |e|
          next unless name_type(e) == :contributor
          xml['dc'].contributor element(e._abcdg, join: ', ', postfix: element(full_name(e), fix: ' (|) '))
        }

        # DCTERMS:PROVENANCE

        # [MARC 852 $b] [MARC 852 $c]
        tag('852', 'b c').each { |e|
          xml['dcterms'].provenance element(e._b == e._c ? e._b : e._bc)
        }

        # DC:PUBLISHER

        # [MARC 260$b] " " [MARC 260$a] " (" [MARC 008 (15-17)]/[MARC 260$c] ") "(uitgever)"
        tag('260', 'a b c').each { |e|
          x = tag('008').datas[15..17]
          xml['dc'].publisher element(
                                  e._ba,
                                  element(x.nil? || x.empty? ? e._c : x, fix: '()'),
                                  join: ' ', postfix: '(uitgever)')
        }

        # [MARC 700 0 $a] ", " [MARC 700 0 $b] ", " [MARC 700 0 $c] ", " [MARC 700 0 $d] ", " [MARC 700 0 $g] " ( " [MARC 700 0 $4] ")" ", " [MARC 700 0 $e] (uitgever)
        tag('7000', 'a b c d e g 4').each { |e|
          next unless name_type(e) == :publisher
          xml['dc'].publisher element(element(e._abcdg, join: ', ', postfix: element(full_name(e), fix: ' (|) ')),
                                      e._e, join: ', ', postfix: '(uitgever)')
        }

        # [MARC 260$f] " " [MARC 260$e] ", " [MARC 260$g] "(drukker)"
        tag('260', 'e f g').each { |e|
          xml['dc'].publisher element(
                                  element(e._fe, join: ' '),
                                  e._g, join: ', ', postfix: '(drukker)'
                              )
        }

        # [MARC 710 29 $a] "  (" [MARC 710 29 $c] ") " ", " [MARC 710 29 $9]  ","  [710 29 $g] "(drukker)"
        tag('71029', 'a c d g 9 4').each { |e|
          xml['dc'].publisher element(
                                  element(e._a, postfix: element(e._c, fix: ' (|) ')),
                                  element(e._9g, join: ', ', postfix: '(drukker)')
                              )
        }

        # [MARC 260 9 $f] " " [MARC 260 9 $e] ", " [MARC 260 9 $g] " ("[MARC 260 9 $9] ")"
        tag('2609', 'e f g 9').each { |e|
          xml['dc'].publisher element(
                                  element(e._fe, join: ' '),
                                  e._g,
                                  join: ', ',
                                  postfix: element(e._9, fix: ' (|)')
                              )
        }

        # DC:DATE

        # [MARC 008 (07-10)] "-" [MARC 008 (11-14)]
        tag('008').each { |e|
          a = e.datas[7..10]
          b = e.datas[11..14]
          # return if both parts contained 'uuuu'
          next if a.gsub!(/^uuuu$/, 'xxxx') && b.gsub!(/^uuuu$/, 'xxxx')
          xml['dc'].date element(a, b, join: '-')
        }

        # "Datering origineel werk: " [MARC 130 $f]
        tag('130', 'f').each { |e|
          xml['dc'].date element(e._f, prefix: 'Datering origineel werk: ')
        }

        # "Datering compositie: " [MARC 240 1- $f]
        tag('2401 ', 'f').each { |e|
          xml['dc'].date element(e._f, prefix: 'Datering compositie: ')
        }

        # [MARC 752 9- $9]
        each_field('7529 ', '9').each { |e|
          xml['dc'].date e
        }

        # [MARC 752 9 $a]
        each_field('7529', 'a').each { |e|
          xml['dc'].date e
        }

        # DC:TYPE

        # [MARC 655 9 $a] [MARC 655 4 $a] [MARC 955 $a]  [MARC FMT]
        each_field('6559', 'a').each { |e|
          xml['dc'].type element(e, each_field('6554', 'a'), each_field('955', 'a'), fmt(tag('FMT')[0].datas))
        }

        # [MARC 655 4 $z]
        each_field('6554', 'z').each { |e|
          xml['dc'].type e
        }

        # [MARC 655 94 $z]
        each_field('65594', 'z').each { |e|
          xml['dc'].type e
        }

        # [MARC 655 9- $a]
        each_field('6559 ', 'a').each { |e|
          xml['dc'].type e
        }

        # [MARC 088 9- $a]
        each_field('0889 ', 'a').each { |e|
          xml['dc'].type e
        }

        # [MARC 088 $z]
        each_field('088', 'z').each { |e|
          xml['dc'].type e
        }

        attributes = {'xml:lang' => 'en'}

        # [MARC 088 $a]
        each_field('088', 'a').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 4 $a]
        each_field('6554', 'a').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 94 $a]
        each_field('65594', 'a').each { |e|
          xml['dc'].type(attributes).text e
        }

        attributes = {'xml:lang' => 'nl'}

        # [MARC 088 $x]
        each_field('088', 'x').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 4 $x]
        each_field('6554', 'x').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 94 $x]
        each_field('65594', 'x').each { |e|
          xml['dc'].type(attributes).text e
        }

        attributes = {'xml:lang' => 'fr'}

        # [MARC 088 $y]
        each_field('088', 'y').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 4 $y]
        each_field('6554', 'y').each { |e|
          xml['dc'].type(attributes).text e
        }

        # [MARC 655 94 $y]
        each_field('65594', 'y').each { |e|
          xml['dc'].type(attributes).text e
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/MESH'}

        # [MARC 655 2 $a] " " [MARC 655 2 $x] " " [MARC 655 2 $9]
        tag('6552', 'a x 9').each { |e|
          xml['dc'].type(attributes).text element(e._a, e.field_array('x'), e._9, join: ' ')
        }

        # DCTERMS:SPATIAL

        # [MARC 752 $a]  " " [MARC 752 $c] " " [MARC 752 $d] " (" [MARC 752 $9] ") "
        tag('752', 'a c d 9').each { |e|
          xml['dcterms'].spacial element(e._acd, element(e.subfied('9'), fix: '()'), join: ' ')
        }

        # "Schaal: " [MARC 034 1- $a] " ("[MARC 507 $a]")"
        each_field('0341 ', 'a').each { |e|
          xml['dcterms'].spacial element(e, element(each_field('507', 'a')[0], fix: '()'), prefix: 'Schaal: ', join: ' ')
        }

        # "Schaal: " [MARC 034 3- $a] " ("[MARC 507 $a]")"
        each_field('0343 ', 'a').each { |e|
          xml['dcterms'].spacial element(e, element(each_field('507', 'a')[0], fix: '()'), prefix: 'Schaal: ', join: ' ')
        }

        # [MARC 034 91 $f] [MARC 034 91 $e] [MARC 034 91 $g] [MARC 034 91 $d]
        tag('03491', 'f e g d').each { |e| xml['dcterms'].spacial element(e._fegd) }

        # [MARC 651 0 $a] " " [MARC 651 0 $x] " " [MARC 651 0 $y] " " [MARC 651 0 $z]
        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}
        tag('6510', 'a x y z').each { |e|
          xml['dcterms'].spacial(attributes).text element(e.fields, join: ' ')
        }

        # [MARC 651 2 $a] " " [MARC 651 2 $x]
        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}
        tag('6512', 'a x').each { |e|
          xml['dcterms'].spacial(attributes).text element(e.fields, join: ' ')
        }

        # DCTERMS:EXTENT

        # [MARC 300 $a] " (" [MARC 300 $e] ")"
        tag('300', 'a e').each { |e|
          xml['dcterms'].extent element(e.a_a, element(e._e, fix: '()'), join: ' ')
        }

        # [MARC 300 $b] " (" [MARC 300 $e] ")"
        tag('300', 'b e').each { |e|
          xml['dcterms'].extent element(e._b, element(e._e, fix: '()'), join: ' ')
        }

        # [MARC 300 $9] " (" [MARC 300 $e] ")"
        tag('300', '9 e').each { |e|
          xml['dcterms'].extent element(e._9, element(e._e, fix: '()'), join: ' ')
        }

        # [MARC 300 9- $9]
        each_field('3009 ', '9').each { |e| xml['dcterms'].extent e }

        # [MARC 300 9- $c]
        each_field('3009 ', 'c').each { |e| xml['dcterms'].extent e }

        # [MARC 306  $a]
        each_field('306', 'a').each { |e| xml['dcterms'].extent e }

        # [MARC 309 $a]
        each_field('309', 'a').each { |e| xml['dcterms'].extent e }

        # "Frequentie tijdschrift: " [MARC 310 $a] " (" [MARC 310 $b] ")"
        tag('310', 'a b').each { |e|
          xml['dcterms'].extent element(e._a, element(e._b, fix: '()'), join: ' ')
        }

        # [MARC 088  $9]
        each_field('088', '9').each { |e| xml['dcterms'].extent e }

        # DC:FORMAT

        # [MARC 339$a] ":" [MARC 300 9- $b] ";"  [MARC 319$a]  [MARC 340$a]
        each_field('3009 ', 'b').each { |e|
          x = element(each_field('319', 'a')[0], all_fields('340', 'a'), prefix: ';')
          xml['dc'].format element(all_fields('339', 'a'), e, join: ':', postfix: x)
        }

        # [MARC 319 9- $a]
        each_field('3199 ', 'a').each { |e|
          xml['dc'].format e
        }

        # DC:RELATION

        # [MARC 534 9- $a]
        each_field('5349 ', 'a').each { |e| xml['dc'].relation e }

        # [MARC 534 9 $a] "(oorspronkelijke uitgever)"
        each_field('5349', 'a').each { |e|
          xml['dc'].relation element(e, postfix: 'oorspronkelijke uitgever')
        }

        # [MARC 580 $a]
        each_field('580', 'a').each { |e| xml['dc'].relation e }

        # [MARC 585 $a]
        each_field('585', 'a').each { |e| xml['dc'].relation e }

        # DCTERMS:HASVERSION

        # [MARC 534 $a]
        each_field('534', 'a').each { |e| xml['dcterms'].hasVersion e }

        # DC:SOURCE

        # [MARC 852$b] " " [MARC 852$c] " " [MARC 852$h] " " [MARC 852 $l]
        tag('852', 'b c h l').each { |e|
          xml['dc'].source element(e._bchl, join: ' ')
        }

        attributes = {'xsi:type' => 'dcterms:URI'}

        # [MARC 856 1$u]
        tag('8561', 'uy').each { |e|
          xml['dc'].source(attributes).text element(e._y, CGI::escape(e._u), join: '#')
        }

        # [MARC 856 2$u]
        tag('8562', 'uy').each { |e|
          xml['dc'].source(attributes).text element(e._y, CGI::escape(e._u), join: '#')
        }

        # DC:LANGUAGE

        # [MARC 041 9- $a]
        each_field('0419 ', 'a').each { |e| xml['dc'].language e }

        # [MARC 041 9- $d]
        each_field('0419 ', 'd').each { |e| xml['dc'].language e }

        # [MARC 041 9- $e]
        each_field('0419 ', 'e').each { |e| xml['dc'].language e }

        # [MARC 041 9- $h]
        each_field('0419 ', 'h').each { |e| xml['dc'].language e }

        # [MARC 041 9- $9]
        each_field('0419 ', '9').each { |e| xml['dc'].language e }

        # "Gedubde taal:" [MARC 041 9$a]
        each_field('0419', 'a').each { |e| xml['dc'].language element(e, prefix: 'Gedubde taal:') }

        # [MARC 041 9 $h]
        each_field('0419', 'h').each { |e| xml['dc'].language e }

        # "Ondertitels:" [MARC 041 9 $9]
        each_field('0419', '9').each { |e| xml['dc'].language element(e, prefix: 'Ondertitels:') }

        # [MARC 008 (35-37)]
        tag('008').each { |e|
          xml['dc'].language taalcode(e.datas[35..37])
        }

        # "Taal origineel: " [MARC 130 $l]
        each_field('130', 'l').each { |e| xml['dc'].language element(e, prefix: 'Taal origineel: ') }

        # "Taal origineel: " [MARC 240 $l]
        each_field('240', 'l').each { |e| xml['dc'].language element(e, prefix: 'Taal origineel: ') }

        # [MARC 546 $a]
        each_field('546', 'a').each { |e| xml['dc'].language e }

        # [MARC 546 9- $a]
        each_field('5469 ', 'a').each { |e| xml['dc'].language e }

        # [MARC 546 9 $a]
        each_field('5469', 'a').each { |e| xml['dc'].language e }

        # DCTERMS:RIGHTSHOLDER

        # [MARC 700$a]
        tag('700', 'a4').each { |e|
          next unless name_type(e) == :rightsholder
          xml['dcterms'].rightsholder element(e._a)
        }

        # [MARC 710$a]
        tag('710', 'a4').each { |e|
          next unless name_type(e) == :rightsholder
          xml['dcterms'].rightsholder element(e._a)
        }

        # DCTERMS:REFERENCES

        # [MARC 856 1 $u]
        each_field('8561', 'u').each { |e| xml['dcterms'].references e }

        # [MARC 856 2 $u]
        each_field('8562', 'u').each { |e| xml['dcterms'].references e }

        # [MARC 856 40 $u]
        each_field('85640', 'u').each { |e| xml['dcterms'].references e }

        # DCTERMS:ABSTRACT

        # [MARC 700 0 $a] ", " [MARC 700 0 $b] ", " [MARC 700 0 $c] ", " [MARC 700 0 $d] ", " [MARC 700 0 $g] " ( " [MARC 700 0 $4] ") " ", " [MARC 700 0 $e]
        tag('7000', 'a b c d g e 4').each { |e|
          next unless name_type(e) == :abstract
          xml['dcterms'].abstract element(element(e._abcdg, join: ', ',
                                                  postfix: element(full_name(e), fix: ' ( |) ') ),
                                          e._e, join: ', ')
        }

        # [MARC 710 2- $a] ", " [MARC 710 2- $g] " (" [MARC 710 2- $4]")"
        tag('7102 ', 'a g 4').each { |e|
          next unless name_type(e) == :abstract
          xml['dcterms'].abstract element(e._ag, join: ', ', postfix: element(full_name(e), fix: ' (|)'))
        }

        # DCTERMS:BIBLIOGRAPHICCITATION

        # [MARC 510 0- $a] ", " [MARC 510 0- $c]
        tag('5100 ', 'a').each { |e|
          xml['dcterms'].bibliographicCitation element(e._ac, join: ', ')
        }

        # [MARC 510 3- $a] ", " [MARC 510 3- $c]
        tag('5103 ', 'a').each { |e|
          xml['dcterms'].bibliographicCitation element(e._ac, join: ', ')
        }

        # [MARC 510 4- $a] ", " [MARC 510 4- $c]
        tag('5104 ', 'a').each { |e|
          xml['dcterms'].bibliographicCitation element(e._ac, join: ', ')
        }

        # [MARC 581$a]
        each_field('581', 'a').each { |e| xml['dcterms'].bibliographicCitation e }

      }
    end

  end

  def dump
    all.values.flatten.each_with_object([]) { |record, m| m << record.dump }.join
  end

  private

  def element(*parts)
    DcElement.new(*parts).to_s
  end

  def name_type(data)
    #noinspection RubyResolve
    code = data._4.to_sym
    DOLLAR4TABLE[data.tag][code][1]
  end

  def full_name(data)
    #noinspection RubyResolve
    code = data._4.to_sym
    DOLLAR4TABLE[data.tag][code][0]
  end

  def taalcode(code)
    TAALCODES[code.to_sym]
  end

  def bibnaam(code)
    BIBCODES[code] || ''
  end

  def fmt(code)
    FMT[code.to_sym] || ''
  end

  #noinspection RubyStringKeysInHashInspection
  DOLLAR4TABLE = {
      '700' => {
          apb: ['approbation, approbatie, approbation', :contributor],
          apr: ['preface', nil],
          arc: ['architect', :contributor],
          arr: ['arranger', :contributor],
          art: ['artist', :creator],
          aui: ['author of introduction', :contributor],
          aut: ['author', :creator],
          bbl: ['bibliography', :contributor],
          bdd: ['binder', :contributor],
          bsl: ['bookseller', :contributor],
          ccp: ['concept', :contributor],
          chr: ['choreographer', :contributor],
          clb: ['collaborator', :contributor],
          cmm: ['commentator (rare books only)', :contributor],
          cmp: ['composer', :contributor],
          cnd: ['conductor', :contributor],
          cns: ['censor, censeur', :contributor],
          cod: ['co-ordination', :contributor],
          cof: ['collection from', :contributor],
          coi: ['compiler index', :contributor],
          com: ['compiler', :contributor],
          con: ['consultant', :contributor],
          cov: ['cover designer', :contributor],
          cph: ['copyright holder', :rightsholder],
          cre: ['creator', :creator],
          csp: ['project manager', :contributor],
          ctb: ['contributor', :contributor],
          ctg: ['cartographer', :creator],
          cur: ['curator', :contributor],
          dfr: ['defender (rare books only)', :contributor],
          dgg: ['degree grantor', :contributor],
          dir: ['director', :creator],
          dnc: ['dancer', :contributor],
          dpc: ['depicted', :contributor],
          dsr: ['designer', :contributor],
          dte: ['dedicatee', :contributor],
          dub: ['dubious author', :creator],
          eda: ['editor assistant', :contributor],
          edc: ['editor in chief', :creator],
          ede: ['final editing', :creator],
          edt: ['editor', :creator],
          egr: ['engraver', :contributor],
          eim: ['editor of image', :contributor],
          eow: ['editor original work', :contributor],
          etc: ['etcher', :contributor],
          eul: ['eulogist, drempeldichter, panégyriste', :contributor],
          hnr: ['honoree', :contributor],
          ihd: ['expert trainee post (inhoudsdeskundige stageplaats)', :contributor],
          ill: ['illustrator', :contributor],
          ilu: ['illuminator', :contributor],
          itr: ['instrumentalist', :contributor],
          ive: ['interviewee', :contributor],
          ivr: ['interviewer', :contributor],
          lbt: ['librettist', :contributor],
          ltg: ['lithographer', :contributor],
          lyr: ['lyricist', :contributor],
          mus: ['musician', :contributor],
          nrt: ['narrator, reader', :contributor],
          ogz: ['started by', :creator],
          oqz: ['continued by', :creator],
          orc: ['orchestrator', :contributor],
          orm: ['organizer of meeting', :contributor],
          oth: ['other', :contributor],
          pat: ['patron, opdrachtgever, maître d\'oeuvre', :contributor],
          pht: ['photographer', :creator],
          prf: ['performer', :contributor],
          pro: ['producer', :contributor],
          prt: ['printer', :publisher],
          pub: ['publication about', :subject],
          rbr: ['rubricator', :contributor],
          rea: ['realization', :contributor],
          reb: ['revised by', :contributor],
          rev: ['reviewer', :contributor],
          rpt: ['reporter', :contributor],
          rpy: ['responsible party', :contributor],
          sad: ['scientific advice', :contributor],
          sce: ['scenarist', :contributor],
          sco: ['scientific co-operator', :contributor],
          scr: ['scribe', :contributor],
          sng: ['singer', :contributor],
          spn: ['sponsor', :contributor],
          sum: ['summary', :abstract],
          tec: ['technical direction', :contributor],
          thc: ['thesis co-advisor(s)', :contributor],
          thj: ['member of the jury', :contributor],
          ths: ['thesis advisor', :contributor],
          trc: ['transcriber', :contributor],
          trl: ['translator', :contributor],
          udr: ['under direction of', :contributor],
          voc: ['vocalist', :contributor],
      },
      '710' => {
          adq: ['readapted by', :contributor],
          add: ['addressee, bestemmeling', :contributor],
          aow: ['author original work, auteur oorspronkelijk werk, auteur ouvrage original', :contributor],
          apr: ['preface', :/],
          arc: ['architect', :contributor],
          art: ['artist', :creator],
          aut: ['author', :creator],
          bbl: ['bibliography', :contributor],
          bdd: ['binder', :contributor],
          bsl: ['bookseller', :contributor],
          ccp: ['concept', :contributor],
          clb: ['collaborator', :contributor],
          cod: ['co-ordination', :contributor],
          cof: ['collection from', :contributor],
          coi: ['compiler index', :contributor],
          com: ['compiler', :contributor],
          con: ['consultant', :contributor],
          cov: ['cover designer', :contributor],
          cph: ['copyright holder', :rightsholder],
          cre: ['creator', :creator],
          csp: ['project manager', :contributor],
          ctb: ['contributor', :contributor],
          ctg: ['cartographer', :contributor],
          cur: ['curator', :contributor],
          dgg: ['degree grantor', :contributor],
          dnc: ['dancer', :contributor],
          dsr: ['designer', :contributor],
          dte: ['dedicatee', :contributor],
          eda: ['editor assistant', :contributor],
          edc: ['editor in chief', :creator],
          ede: ['final editing', :creator],
          edt: ['editor', :creator],
          egr: ['engraver', :contributor],
          eim: ['editor of image', :contributor],
          eow: ['editor original work', :contributor],
          etc: ['etcher', :contributor],
          eul: ['eulogist, drempeldichter, panégyriste', :contributor],
          hnr: ['honoree', :contributor],
          itr: ['instrumentalist', :contributor],
          ltg: ['lithographer', :contributor],
          mus: ['musician', :contributor],
          ogz: ['started by', :creator],
          oqz: ['continued by', :creator],
          ori: ['org. institute (rare books/mss only)', :contributor],
          orm: ['organizer of meeting', :contributor],
          oth: ['other', :contributor],
          pat: ['patron', :contributor],
          pht: ['photographer', :creator],
          prf: ['performer', :contributor],
          pro: ['producer', :contributor],
          prt: ['printer', :publisher],
          pub: ['publication about', :subject],
          rea: ['realization', :contributor],
          rpt: ['reporter', :contributor],
          rpy: ['responsible party', :contributor],
          sad: ['scientific advice', :contributor],
          sco: ['scientific co-operator', :contributor],
          scp: ['scriptorium', :contributor],
          sng: ['singer', :contributor],
          spn: ['sponsor', :contributor],
          sum: ['summary', :abstract],
          tec: ['technical direction', :contributor],
          trc: ['transcriber', :contributor],
          trl: ['translator', :contributor],
          udr: ['under direction of', :contributor],
          voc: ['vocalist', :contributor],
      },
      '711' => {
          oth: ['other', :contributor],
      },
      '100' => {
          arr: ['arranger', :contributor],
          aut: ['author', :creator],
          cmp: ['composer', :contributor],
          com: ['compiler', :contributor],
          cre: ['creator', :creator],
          ctg: ['cartographer', :creator],
          ill: ['illustrator', :contributor],
          ivr: ['interviewer', :contributor],
          lbt: ['librettist', :contributor],
          lyr: ['lyricist', :contributor],
          pht: ['photographer', :creator],
      }
  }

  TAALCODES = {
      afr: 'af',
      ara: 'ar',
      chi: 'zh',
      cze: 'cs',
      dan: 'da',
      dum: 'dum',
      dut: 'nl',
      est: 'et',
      eng: 'en',
      fin: 'fi',
      fre: 'fr',
      frm: 'frm',
      ger: 'de',
      grc: 'grc',
      gre: 'el',
      hun: 'hu',
      fry: 'fy',
      ita: 'it',
      jpn: 'ja',
      lat: 'la',
      lav: 'lv',
      liv: 'lt',
      ltz: 'lb',
      mlt: 'mt',
      nor: 'no',
      pol: 'pl',
      por: 'pt',
      rus: 'ru',
      slo: 'sk',
      slv: 'sl',
      spa: 'es',
      swe: 'sv',
      tur: 'tr',
      ukr: 'uk',
  }

  #noinspection RubyStringKeysInHashInspection
  BIBCODES = {
      '01' => 'K.U.Leuven',
      '02' => 'KADOC',
      '03' => 'BB(Boerenbond)/KBC',
      '04' => 'HUB',
      '05' => 'ACV',
      '06' => 'LIBAR',
      '07' => 'SHARE',
      '10' => 'BPB',
      '11' => 'VLP',
      '12' => 'TIFA',
      '13' => 'LESSIUS',
      '14' => 'SERV',
      '15' => 'ACBE',
      '16' => 'SLUCB',
      '17' => 'SLUCG',
      '18' => 'HUB',
      '19' => 'KHBO',
      '20' => 'FINBI',
      '21' => 'BIOET',
      '22' => 'LUKAS',
      '23' => 'KHM',
      '24' => 'Fonds',
      '25' => 'RBINS',
      '26' => 'RMCA',
      '27' => 'NBB',
      '28' => 'Pasteurinstituut',
      '29' => 'Vesalius',
      '30' => 'Lemmensinstituut',
      '31' => 'KHLIM',
      '32' => 'KATHO',
      '33' => 'KAHO',
      '34' => 'HUB',
  }

  FMT = {
      BK: 'Books',
      SE: 'Continuing Resources',
      MU: 'Music',
      MP: 'Maps',
      VM: 'Visual Materials',
      AM: 'Audio Materials',
      CF: 'Computer Files',
      MX: 'Mixed Materials',
  }

end