module Datatron
  module DataDelegation
    extend ActiveSupport::Concern

    module ClassMethods
      def keys &block
        raise NotImplementedError,"#{__method__} called for the first time without a block" if block.nil?
        define_singleton_method :keys, &block
      end

      def each &block
        raise NotImplementedError,"#{__method__} called for the first time without a block" if block.nil?
        define_singleton_method :each do
          Enumerator.new do |y|
            block.call(y)
          end
        end
      end

      def next
        @data ||= self.each
        @data.next
      end

      def rewind
        @data = nil
      end

      attr_accessor :data_source

      alias :column_names :keys

      def data_class name, &block
        raise ArgumentError, "Block required" if block.nil?
        klass = Class.new(self, &block)
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

  class Format < Delegator 
    include DataDelegation
    #silence_warnings { undef :initialize }
  end
end
