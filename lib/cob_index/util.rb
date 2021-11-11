# frozen_string_literal: true

module CobIndex::Util
  def self.load_list_file(name)
    list_path = Dir.glob(File.dirname(__FILE__) + "/../list/#{name}*").first
    File.open(list_path).readlines(chomp: true);
  end
end
