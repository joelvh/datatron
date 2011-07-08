module Datatron

  module TransformMethods
    extend ActiveSupport::Concern
    
    class TranslationAction
      include ::Singleton
    end
    
    class AwaitingTranslationAction < TranslationAction; end
    class CopyTranslationAction < TranslationAction; end
    class DiscardTranslationAction < TranslationAction; end

    class UsingTranslationAction
      attr_accessor :strategy
      def initialize strat, &block
        @strategy = strat
        @strategy.modify &block
      end
    end
    
    module ClassMethods
      def method_missing meth, *args, &block
        args.push({}) if args.empty?
        args[-1] = {} unless args.last.is_a? Hash
        if block_given?
          @strategies ||= HashWithIndifferentAccess.new {}
          @strategies[meth] = {} 
          @strategies[meth].merge!({ :block => block, :args => args })
        elsif @strategies.has_key? meth
          block = @strategies[meth][:block]
          args.insert(-2, @strategies[meth][args]).flatten
          self.new(meth,*args,&block)
        else
          super
        end
      end

      def strategies
        @strategies
      end

      def base_name
        self.to_s.split('::').last.underscore.pluralize
      end
    end


    #DSL Methods
    module InstanceMethods
      #cause I get sick of fucking typing it
      ATA = AwaitingTranslationAction.instance

      def base_name
        self.class.base_name
      end
 
      def current_status= arg
        status, field = *arg
        if self.class.transition_valid? @current, status
          @current = status 
          @current_field = field
        else
          raise InvalidTransition, "can't go from #{@current} to #{arg}"
        end
      end

      def current_status
        @current
      end

      def current_field
        @current_field
      end

      [:to, :from].map do |op|
        inverse_op = op == :to ? :from : :to

        define_method op do |field, &block|
          op_field = @current_field
          self.current_status = op, field
          if @strategy_hash[inverse_op].has_key? field
            raise InvalidTransition, "#{inverse_op} action for #{field} is already defined" unless @strategy_hash[inverse_op][field] == ATA 
          elsif @strategy_hash[inverse_op].has_key? op_field
            @strategy_hash[inverse_op][op_field] = !block.nil? ? { field => block } : field.to_s
          else 
            @strategy_hash[op][field] = block || ATA
          end
        end

        define_method "#{op}_model".intern do |model = nil|
          if model 
            raise ::ArgumentError, "Datatron::Format class expected got #{model.class}" unless #{model} < Datatron::Format
            instance_variable_set "@#{op}_model", model
            __send__ "#{op}_source".intern, self.base_name
          else
            instance_variable_get "@#{op}_model"
          end
        end

        define_method "#{op}_source".intern do |source = nil|
          if source
            model = __send__ "#{op}_model".intern
            new_model = lambda { model.new(source)}
            source_class = model.subclasses.find(new_model) do |sc|
              sc.base_name == source
            end
            instance_variable_set "@#{op}_source", source_class
          else
            instance_variable_get "@#{op}_source"
          end 
        end
      end

      def through method = nil, &block
        raise ArgumentError, "Through can take a block or a method name, but not both" if block_given? and method.nil?
        self.current_status = :through, @current_field
        
        block = @from_source.method method if method
        
        @strategy_hash[:to][@current_field] = {
          @current_field => block
        }
      end

      def otherwise method
        case method
          when :copy
            @strategy_hash.default = CopyTranslationAction.instance
          when :discard
            @strategy_hash.default = DiscardTranslationAction.instance
        end
      end
   
      def using strategy, &block
        op_field, state = current_field, current_status
        self.current_status = :using, nil
        @strategy_hash[state][op_field] = UsingTranslationAction.new(strategy, &block) 
        self.current_status = :ready, nil
      end

      def done
        self.current_status = :ready, nil
      end

      def delete field = nil
        if field
          @strategy_hash[:from][field] = DiscardTranslationAction.instance
        elsif @strategy_hash[:from].has_key? @current_field
           @strategy_hash[:from][@current_field] = DiscardTranslationAction.instance
        else
          raise InvalidTransition, "delete must come after a 'from' action on a field"
        end
      ensure
        self.current_status = :ready, nil
      end

      def find_by method, options = {}
        options.reverse_merge!({ :as => method })
        @finder = "#{find_by_}#{method}".intern, options[:as], options
      end

    end

  end

end
