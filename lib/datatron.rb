require 'active_support/core_ext'

require 'datatron/converter'
require 'datatron/transforms'
require 'datatron/transform_methods'
require 'datatron/transform'
require 'datatron/base'

module Datatron
  autoload :ActiveRecordTransform, 'datatron/active_record_transform.rb'
  autoload :ActiveRecord, 'active_record'
  
  if defined? Rails
    class DatatronTasks < Rails::Railtie
      rake_tasks do
        load "datatron/railties/tasks.rake"
      end
    end
  end
end

