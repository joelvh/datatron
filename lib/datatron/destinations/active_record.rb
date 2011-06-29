module Datatron
  module Destinations
    class ActiveRecord < ActiveRecord::Base
      def for_table table 
        klass = Class.new(self) do |c|
          define_singleton_method :next_row do
            @data ||= Enumerator.new do |y|
              c.each do |i|
                y.yield i
              end
            end
            @data.next
          end
        end
        Datatron::Destination.const_set table.camelize.intern, klass
      end
      undef :initialize
    end
  end
end
