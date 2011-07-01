module Datatron
  module DataDelegation
    extend ActiveSupport::Concern

    module ClassMethods
      def keys &block
        raise NotImplementedError,"#{__method__} called for the first time without a block" if block.nil?
        define_singleton_method :keys, &block
      end

      def next_row &block
        raise NotImplementedError,"#{__method__} called for the first time without a block" if block.nil?
        define_singleton_method :next_row do
          @data ||= Enumerator.new do |y|
            block.call(y)
          end
          begin
            @data.next
          rescue StopIteration
            nil
          end
        end
      end
      attr_accessor :data

      alias :column_names :keys

      def data_class name, &block
        raise ArgumentError, "Block required" if block.nil?
        klass = Class.new(self)
        klass.singleton_class.__send__ :attr_accessor, :data_class
        klass.instance_exec klass, &block
        self.parent.const_set name.singularize.camelize.intern, klass
      end
    end

    module InstanceMethods
      def __getobj__
        @obj ||= self.class.data_class.new
      end

      def __setobj__ obj
        @obj = obj
      end
      
      def initialize obj = nil
        __setobj__(obj || self.class.data_class.new)
      end
    end
  end

  class Source < Delegator 
    include DataDelegation
    #silence_warnings { undef :initialize }
  end

  class Destination < Delegator
    include DataDelegation
    #silence_warnings { undef :initialize }
  end
end
