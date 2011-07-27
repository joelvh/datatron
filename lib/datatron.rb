require 'active_support/core_ext'

#require 'datatron/converter'
#require 'datatron/translator'
#require 'datatron/transform_methods'
#require 'datatron/transform'

require 'weakref'
require 'singleton'
require 'set'
require 'forwardable'

#gem dependency
require 'order_tree'

module Datatron
  if defined? Rails
    class DatatronTasks < Rails::Railtie
      rake_tasks do
        load "datatron/railties/tasks.rake"
      end
    end
  end
  
  autoload :Strategy,      'datatron/strategy'
  autoload :TransformDSL,  'datatron/transform_dsl'
  autoload :Translation,   'datatron/translation'
  autoload :Translator,    'datatron/translator'
  autoload :Converter,     'datatron/converter'
  autoload :Format,        'datatron/format'

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
  class DataSourceNotFound < DatatronError; end
  class RecordInvalid < DatatronError; end 

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

  class InvalidTransition < DatatronError; end
  class TranslationFormatError < DatatronError; end
  class TranslationKeyError < DatatronError; end 
end

# I concur.
# http://redmine.ruby-lang.org/issues/4553
# I kinda wish this could be a refinement
class Set
  def pick
    @hash.first.first
  end
  # Picks an arbitrary element from the set and deletes it. Use +pick+ to
  # pick without deletion.
  def pop
    key = pick
    @hash.delete(key)
    key
  end
end


