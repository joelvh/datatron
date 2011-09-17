module Datatron
  module TransformDSL
    extend ActiveSupport::Concern

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
          args.concat(@strategies[meth][:args])
          self.new(meth,*args,&block)
        else
          super
        end
      end

      def const_missing const
        Datatron::Formats.const_get const
      end

      def strategies
        strats = HashWithIndifferentAccess.new {} 
        klass = self
        while klass
          class_strats = klass.instance_eval { @strategies }
          strats.reverse_merge! class_strats if class_strats
          klass = klass.superclass
        end
        strats
      end

      [:to, :from].product([:model, :source]).map { |i| i.join('_')}.each do |meth|
        define_method meth.intern do |source = nil|
          if source
            instance_variable_set "@#{meth}", source
          else
            instance_variable_get "@#{meth}"
          end
        end
      end
        
      def base_name
        self.to_s.split('::').last.underscore.pluralize
      end

      def transition_valid? from, to
        return true if from.nil?

        unless @transition_table
          @transition_table = {  
            :ready => [:to, :from, :ready, :error],
            :to => [:from, :through, :using, :error, :ready],
            :from => [:to, :through, :error, :ready]
          }
          @transition_table.default = [:ready]
        end
          
        @transition_table[from].include?(to) ? true : false
      end
    end


    #DSL Methods
    module InstanceMethods
      include Datatron::Translation

      attr_accessor :finder
      attr_accessor :router
      attr_writer :name
      attr_reader :parent

      def initialize strategy, *args, &block
        @name = strategy
        options = (args.pop if args.last.is_a? Hash) || {}
        @current = :ready
        
        instance_exec args.slice(0,block.arity), &block

        # if the models are not set within the instance, then set them here
        [:to,:from].product([:model]).map { |i| i.join("_") }.map(&:intern).each do |model|
          if not instance_variable_get :"@#{model}"
            send model, (send model)
          end
        end

        self
      end

      def base_name
        self.class.base_name
      end

      def name
        [self.class.base_name,@name].join("_")
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

      def check_field op, field, value, block
        if @strategy_hash.has_path?(op,field)
          action = @strategy_hash[op,field]

          # if the action name already exists, and it's set to something,
          # that's an error
          unless action == AwaitingTranslationAction.instance 
            raise InvalidTransition, "[#{op}, #{field}] action for #{field} is already defined"
          end

          # we are awaiting our tranlsation action
          if block.nil?
            @strategy_hash[op,field] = value.to_s
          else
            @strategy_hash.store(op,field, { value => block })
          end
          self.current_status = :ready, nil #all set up and ready for the next one
          return true
        end
        return false
      end
      private :check_field

      [:to, :from].map do |op|
        inverse_op = op == :to ? :from : :to

        define_method op do |field, &block|
          last_field = @current_field
          self.current_status = op, field
          unless (check_field(op,field, field, block) or check_field(inverse_op, last_field, field, block))
            @strategy_hash[op,field] = block || AwaitingTranslationAction.instance 
          end
          #don't put "done" after to / from with blocks
          self.current_status = :ready, nil if not block.nil?
        end

        #okay, because setting the model and the source is complicated.
        #Basically, the model is the superclass of the source and details the 
        #kind of file it is. (like activerecord, json, tabdelim) the source
        #is the particular class like active record tables, json or tab
        #delim files, etc, which contain instances of a Datatype.
        #you can also think of the model as a class factory for sources.
        #
        # model Model
        #    set_model
        #    set source to something
        #       get the model
        #       is that valid type of modeL?
        #       then set the source
        #
        # you may set these in any order, but the source will not be validated
        # until you set the model

        define_method "#{op}_model".intern do |model = nil|
          if model 
            begin
              model < Datatron::Format
            rescue ::ArgumentError
              raise ::ArgumentError, "Datatron::Format class expected got #{model.class} - #{model}" 
            end
            instance_variable_set "@#{op}_model", model
            
            #set up the default source when the model is set
            #when the model type is set up for our instance, set
            #up the source as well
            source_name = switch do 
              on instance_variable_get( :"@#{op}_source")
              on self.class.__send__(:"#{op}_source")
              on self.base_name 
            end
            __send__ "#{op}_source".intern, source_name

          else
            # retrieve the model type
            model_name = switch do
              on instance_variable_get :"@#{op}_model"
              on self.class.__send__ :"#{op}_model"
              on { raise Datatron::DatatronError::InvalidFormat, "couldn't find a format model for #{self.base_name}" } 
            end
          end
        end

        define_method "#{op}_source".intern do |source = nil, klass = nil|
          if source
            unless source.is_a? Class
              model = __send__ "#{op}_model".intern
              new_source = lambda { model.from(source, self.name) }
              source = model.subclasses.find(new_source) do |sc|
                sc.base_name.to_s == self.name 
              end
            end
            
            begin
              source < Datatron::Format
            rescue ::ArgumentError
              raise ::ArgumentError, "Datatron::Format class expected got #{source_class.class}" 
            end
            
            instance_variable_set "@#{op}_source", source
          else
            instance_variable_get "@#{op}_source"
          end 
        end
      end

      def error &block
        op, field = self.current_status, self.current_field
        
        if [:to, :from].include? op then
          @strategy_hash[op][field][:error] = block
        elsif op == :ready
          @strategy_hash[:error] = block
        else
          raise InvalidTransition, "error must be associated with an operation or freestanding."
        end
      end
          

      def through method = nil, &block
        raise ArgumentError, "Through can take a block or a method name, but not both" if block_given? and method.nil?
        self.current_status = :through, @current_field
        
        block = @from_source.method method if method
        
        @strategy_hash.store(:to,@current_field, { @current_field => block })
      end

      def otherwise method
        case method
          when :copy, :same
            @strategy_hash.default = CopyTranslationAction.instance
          when :discard, :delete, :ignore
            @strategy_hash.default = DiscardTranslationAction.instance
        end
      end

      def using klass, *args, &block
        op_field, state = current_field, current_status
        @strategy_hash[state][op_field] = UsingTranslationAction.substrategy(self, klass, *args, &block)
        self.current_status = :ready, nil
      end

      def copy *fields
        if not fields.empty?
          fields.each do |field|
            @strategy_hash[:from][field] = CopyTranslationAction.instance
          end
        elsif @strategy_hash.has_path?(:from, @current_field)
          @strategy_hash[:from][@current_field] = CopyTranslationAction.instance
        else
          raise InvalidTransition, "copy must come after a 'from' action on a field or with a list of field names"
        end
      ensure
        self.current_status = :ready, nil
      end
      alias :same :copy

      def delete *fields
        if not fields.empty?
          fields.each do |field|
            @strategy_hash[:from][field] = DiscardTranslationAction.instance
          end
        elsif @strategy_hash.has_path?(:from, @current_field)
           @strategy_hash[:from][@current_field] = DiscardTranslationAction.instance
        else
          raise InvalidTransition, "delete must come after a 'from' action on a field or with a list of field names"
        end
      ensure
        self.current_status = :ready, nil
      end
      alias :ignore :delete

      # find the source you want to use
      # overrides "source.new"
      def find *args, &block
        @finder = [args, block]
      end

      # how to save to a specific destination
      # overrides "destination.save"
      def route *args, &block
        @router = [args, block]
      end

      # how to get a deestination
      # overrides "destination.new"
      def append *args, &block
        @appender = [args, block]
      end
    end
  end
end
