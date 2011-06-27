require 'rails'

require 'active_support/core_ext'

require 'datatron/converter'
require 'datatron/transforms'
require 'datatron/transform_methods'
require 'datatron/transform'

module Datatron
  autoload :ActiveRecordTransform, 'datatron/active_record_transform.rb'

  class DatatronTasks < Rails::Railtie
    rake_tasks do
      load "datatron/railties/tasks.rake"
    end
  end
end

