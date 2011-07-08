require 'active_support/core_ext'

require 'datatron/converter'
require 'datatron/transform_methods'
require 'datatron/transform'
require 'datatron/base'

module Datatron
  if defined? Rails
    class DatatronTasks < Rails::Railtie
      rake_tasks do
        load "datatron/railties/tasks.rake"
      end
    end
  end

  class DatatronError < StandardError; end
  class DataSourceNotFound < DatatronError; end

  module Formats
    class << self
      def const_missing const
        autoload const, [self, const].collect(&:to_s).join('::').underscore
        const_get const
      end
    end
  end

  def transforms
    self.constants.each_with_object [] do |c, memo|
      klass = self.const_get c 
      memo << klass if klass.is_a? Class and klass < Datatron::Transform
    end
  end
  module_function :transforms

  class InvalidTransition < DatatronError; end
  class TranslationFormatError < DatatronError; end
  class TranslationKeyError < DatatronError; end 

end
