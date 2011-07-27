module Datatron
  module TransformDSL
    extend ActiveSupport::Concern

    class DeferredMethodCall < BasicObject 
      attr_accessor :method, :args, :block
      
      def initialize method, args, &block
        @method = method
        @args = args
        @block = block
      end

      def send_to obj
        @obj = obj
      end

      def method_missing method, *args, &block
        t = @obj.__send__ @method, *@args, &@block
        t.__send__ method, *args, &block
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

      def transition_valid? from, to
        return true if from.nil?

        unless @transition_table
          @transition_table = {  
            :ready => [:to, :from, :ready],
            :to => [:from, :through, :using, :ready],
            :from => [:to, :through, :ready]
          }
          @transition_table.default = [:ready]
        end
          
        @transition_table[from].include?(to) ? true : false
      end

      def const_missing const
        Datatron::Formats.const_get const
      end

      def strategies
        strats = []
        klass = self.class
        while klass
          class_strats = klass.instance_eval { @strategies }
          strats.concat class_strats if class_strats
          klass = klass.superclass
        end
      end

      def base_name
        self.to_s.split('::').last.underscore.pluralize
      end
    end


    #DSL Methods
    module InstanceMethods
      include Datatron::Translation

      attr_accessor :finder
      attr_accessor :router
      attr_accessor :name

      def initialize strategy, *args, &block
        @name = strategy
        options = (args.pop if args.last.is_a? Hash) || {}
        @current = :ready
        instance_exec args.slice(0,block.arity), &block
        
        options.reverse_merge!({:to => @to_source, 
                                :keys => :keys,
                                :from => @from_source,
                                :from_keys => :keys})


        [:to, :from].each do |op|
          model, source = ["model","source"].collect { |s| "#{op}_#{s}".intern }
          unless(options[op] == __send__(source)) then
            __send__ source, options[op]
            unless __send__ source
              raise ArgumentError, "Couldn't find #{model} subclass for #{self.class}"
            end
          end
        end
      end

      def base_name
        self.class.base_name
      end

      def modify *args, &block
        self.instance_exec args.slice(0,block.arity), &block
        self.current_status = nil, nil
      end

      def like strategy, *args
        strat = self.class.strategies[strategy]
        self.modify strat[:args], &strat[:block]
      end
 
      def current_status= arg
        status, field = *arg

        if status.nil? and field.nil?
          [:@current, :@current_field].each do |i|
            remove_instance_variable(i) rescue nil
          end
          return
        end

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
          if @strategy_hash[inverse_op,field]
            unless @strategy_hash[inverse_op,field] == AwaitingTranslationAction.instance
              raise InvalidTransition, "#{inverse_op} action for #{field} is already defined"
            end
          elsif @strategy_hash[inverse_op, op_field]
            unless block.nil?
              @strategy_hash.store(inverse_op, op_field, { field => block })
            else
              @strategy_hash[inverse_op,op_field] = field.to_s
            end
          else 
            @strategy_hash[op, field] = block || AwaitingTranslationAction.instance 
          end
          
          #don't put "done" after to / from with blocks
          self.current_status = :ready, nil if !block.nil?
        end

        define_method "#{op}_model".intern do |model = nil|
          if model 
            begin
              model < Datatron::Format
            rescue ::ArgumentError
              raise ::ArgumentError, "Datatron::Format class expected got #{model.class}" 
            end
            instance_variable_set "@#{op}_model", model
            __send__ "#{op}_source".intern, self.base_name
          else
            instance_variable_get "@#{op}_model"
          end
        end

        define_method "#{op}_source".intern do |source = nil|
          if source
            model = __send__ "#{op}_model".intern
            new_model = lambda { model.from(source) }
            source_class = model.subclasses.find(new_model) do |sc|
              sc.base_name == source
            end
            #and this is why we require activesupport
            begin
              source_class < Datatron::Format
            rescue ::ArgumentError
              raise ::ArgumentError, "Datatron::Format class expected got #{source_class.class}" 
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
          when :copy, :same
            @strategy_hash.default = CopyTranslationAction.instance
          when :discard, :delete, :ignore
            @strategy_hash.default = DiscardTranslationAction.instance
        end
      end

      def using strategy, *args, &block
        op_field, state = current_field, current_status
        @strategy_hash[state][op_field] = UsingTranslationAction.substrategy(self, strategy, *args, &block)
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
      alias :ignore :delete

      def find *args, &block
        @finder = [args, block]
      end

      def route *args, &block
        @router = [args, block]
      end

      def method_missing method, *args, &block
        if [:source, :destination].include? method
          DeferredMethodCall.new(method, args, &block)
        else
          super
        end
      end
    end
  end
end
