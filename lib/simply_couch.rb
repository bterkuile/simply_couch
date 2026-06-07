# Please move me to a proper location
class String
  def property_name
    underscore.gsub('/','__').gsub('::','__')
  end
end

unless defined?(SimplyCouch)
  $:<<(File.expand_path(File.dirname(__FILE__) + "/lib"))
  require 'simply_couch/instance_methods'
  require 'simply_couch/storage'
  require 'simply_couch/class_methods_base'

  module SimplyCouch
    VERSION = '1.0.0'
    class Error < RuntimeError; end
    class RecordNotFound < RuntimeError; end
    class NotImplementedError < RuntimeError; end
    class ModelNotInstantiatedError < RuntimeError; end
  end

  require 'simply_couch/database_config'
  require 'simply_couch/model'
  require 'core_ext/time'
  require 'core_ext/date'
end
class SimplyCouch::Conflict < StandardError; end
