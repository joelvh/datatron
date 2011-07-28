require 'active_record'

module Datatron
  module Formats 
    class ActiveRecord < Datatron::Format
      class << self
        def from table
          raise DataSourceNotFound, "Couldn't find table #{table}" unless ::ActiveRecord::Base.connection.tables.include? table
          data_class table do |c|
            c.data_source = table.singularize.camelize.constantize 
            class << c
              def keys
                self.superclass.column_names
              end

              def each
                return enum_for :each unless block_given?
                pt = c.data_class.arel_table
                id = 0
                loop do
                  obj = c.data_class.find_by_sql(pt.project('*').where(pt[:id].gteq(id)).order(pt[:id].asc).to_sql).first
                  obj ? yield(self.new(obj)) : break 
                  id = obj.id + 1 
                end
              end
            end
          end
        end
      end
    end
  end
end
