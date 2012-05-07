# coding: utf-8

module XmlUtils

  private

  def get_content(nodelist)
    nodelist.first && nodelist.first.content || ''
  end

end