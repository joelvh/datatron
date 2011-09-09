require 'active_support/core_ext'


require 'weakref'
require 'singleton'
require 'set'
require 'forwardable'
require 'observer'

#gem dependency
require 'order_tree'

#other files i need
require 'datatron/translation'
require 'datatron/transform_dsl'
require 'datatron/strategy'
require 'datatron/translator'
require 'datatron/converter'

module Datatron
  if defined? Rails
    class DatatronTasks < Rails::Railtie
      rake_tasks do
        load "datatron/railties/tasks.rake"
      end
    end
  end
  
  autoload :Format, 'datatron/format'

  module LiveConstants 
    extend ActiveSupport::Concern
    
    module ClassMethods
      def live_constants
        self.constants.each_with_object [] do |c, memo|
          klass = self.const_get c 
          memo << klass if yield(klass)
        end
      end
    end
  end

  class DatatronError < StandardError; end
  class InvalidFormat < DatatronError; end
  class DataSourceNotFound < DatatronError; end
  class RecordInvalid < DatatronError; end 
  class StrategyError < DatatronError; end

  module Formats
    include LiveConstants 
    
    class << self
      def const_missing const
        autoload const, [self, const].collect(&:to_s).join('::').underscore
        const_get const
      end

      def subclasses
        live_constants do |klass|
          klass.is_a? Class and klass < self 
        end
      end
    end
  end

  include LiveConstants 
  def strategies 
    live_constants do |klass|
      klass.is_a? Class and klass < Datatron::Strategy
    end
  end
  module_function :strategies

  class << self
    attr_accessor :path
    attr_accessor :verbose_log
  end

  @path = 'data'
  @verbose_log = false

  class InvalidTransition < DatatronError; end
  class TranslationFormatError < DatatronError; end
  class TranslationKeyError < DatatronError; end 
end
