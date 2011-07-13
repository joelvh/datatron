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

      def from 
        raise NotImplementedError,"Subclasses of Datatron::Format should implement #new"
      end

      def next
        @data ||= self.each
        @data.next
      end

      def rewind
        @data = nil
      end

      attr_accessor :data_source
      attr_accessor :base_name

      alias :column_names :keys

      def data_class name, &block
        raise ArgumentError, "Block required" if block.nil?
        klass = Class.new(self, &block)
        klass.base_name = name
        self.const_set name.singularize.camelize.intern, klass
      end
    end

    module InstanceMethods
      def __getobj__
        @obj ||= self.class.data_source.new
      end

      def __setobj__ obj
        @obj = obj
      end
      
      def initialize obj = nil
        __setobj__(obj || self.class.data_source.new)
      end
    end
  end

  class Format < Delegator 
    include DataDelegation
  end
end
