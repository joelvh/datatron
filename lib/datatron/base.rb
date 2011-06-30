module Datatron
  module DataDelegation
    extend ActiveSupport::Concern

    module ClassMethods
      [:keys, :next_row].map do |meth|
        define_method(meth) do |&block|
          instance_exec &block
        end
      end
      alias :column_names :keys

      attr_accessor :real_class
    end

    module InstanceMethods
      def __getobj__
        @obj ||= self.class.real_class.new
      end

      def __setobj__ &block
        @obj ||= yield
      end
      
      def row &block
        block.nil? ? __setobj__(&block) : __getobj__
      end
  end

  class Source < Delegator 
    include DataDelegation
    silence_warnings { undef :initialize }
  end

  class Destination < Delegator
    include DataDelgation
    silence_warnings { undef :initialize }
  end
end
