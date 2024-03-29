# frozen_string_literal: true

require "dot_properties"

module CobIndex::DotProperties
  def self.load(name)
    ::DotProperties.load(File.dirname(__FILE__) + "/../translation_maps/#{name}.properties")
  end
end
