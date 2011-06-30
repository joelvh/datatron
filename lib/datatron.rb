require 'active_support/core_ext'

require 'datatron/converter'
require 'datatron/transforms'
require 'datatron/transform_methods'
require 'datatron/transform'
require 'datatron/base'

module Datatron
  autoload :ActiveRecord, 'active_record'
  
  if defined? Rails
    class DatatronTasks < Rails::Railtie
      rake_tasks do
        load "datatron/railties/tasks.rake"
      end
    end
  end
  
  module Sources
    class << self
      def const_missing const
        autoload const, [self, const].collect(&:to_s).join('::').underscore
        const_get const
      end
    end
  end

  module Destinations
   class << self
      def const_missing const
        autoload const, [self, const].collect(&:to_s).join('::').underscore
        const_get const
      end
    end
  end
end

