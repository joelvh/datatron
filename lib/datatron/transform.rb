module Datatron
  class Transform
    def self.const_missing const
      Datatron::Formats.const_get const
    end

    include TransformMethods

    module FuzzyInclude
      def fuzzy_include? v
        self.detect { |p| p === v}
      end
    end

    attr_accessor :finder

    def initialize strategy, *args, options = {}, &block
      strat = self.class.strategies[strategy]
      options.merge!(strat[:args])
      
      init_blocks = [strat[:block]]
      init_blocks << block unless block.nil?
      init_blocks.each do |b|
        instance_exec args.slice(0,b.arity), &b
      end

      #to and from are likely to be nil here, unless
      #there is specific data source
      options.merge!( {:to => self.to_model.data_source, 
                       :keys => :keys,
                       :from => self.from_model.data_source,
                       :from_keys => :keys})

      @origin_fields = from_model.send options[:from_keys]
      @destination_fields = to_model.send options[:keys] #fields in the new object
     
      #create the strategy lookup table via the dsl - send in the field lists if
      # the strategy wants them
      @strategy_hash = HashWithIndifferentAccess.new(:from => {}, :to => {}) 
      @current = :ready #subvert!
      init_blocks = [strat[:block]]
      init_blocks << block unless block.nil?
      lookup
    end

    def transform key
      if (path = path_for_key(key))
        type, location = path
        return lookup[type][location]
      elsif implicit_keys.include? key
        return true
      elsif inferred_keys.include? key
        return lookup[:to][location]
      elsif all_keys.include? key
        # we are aware of the key and want to do nothing withit.
        return false
      else
        raise TranslationKeyError, "Don't know anything about #{key}" 
      end
    end
    
    def all_keys
      #all key values that I know how do something with.
      @origin_fields | @destination_fields 
    end

    private
    def lookup
      return @lookup if @lookup
      @lookup = @strategy_hash.each_pair.each_with_object({}) do |(k,v), memo|
        unless k == :to
          memo[k] = v 
        else
          memo[k] = v.each_pair.collect { |i| i.last.is_a?(String) ? i.reverse : i }
        end
      end
    end

    def path_for_key key
      if (location = to_field.fuzzy_include?(key))
        return :to, location
      elsif (location = from_field.fuzzy_include?(key)) 
        return :from, location 
      end
      false
    end
    
    #keys where you say 'to this field from this other field'
    #ie, you specifiy the from field precisiely
    def to_field
      return @to_fields if @to_fields
      @to_fields = @strategy_hash[:to].values.collect do |v|
        next v if String === v
        next v.keys.first if Hash === v
        nil
      end.compact
      @to_fields.extend FuzzyInclude
      @to_fields
    end
    
    #keys where you say 'from this field to this other field'
    #generally when you specifiy the from field less precisely
    def from_field
      return @from_keys if @from_keys
      @from_keys = @strategy_hash[:from].keys
      @from_keys.extend FuzzyInclude
      @from_keys
    end

    #keys where you know how to created it, even if there's
    #no data field in the import file
    def inferred_keys 
      return @unspecified_keys if @unspecified_keyt
      @unspecificed_keys = @destination_fields.reject do |v|
        @origin_fields.any? { |ak| ak === v } && to_fields.any? { |kp| kp == v }
      end
    end

    #keys which are implicitly converted from tab delimted column to AR attribute
    #like "name" data field to "name" data field
    def implicit_keys
      return @implicit_keys if @implicit_keys
      @implicit_keys = all_keys.reject do |v|
       from_field.any? { |kp| kp === v } || to_field.values.any? { |kp| kp === v }
      end
    end
   
    def self.transition_valid? from, to
      unless @transition_table
        @transition_table = {  
          :ready => [:to, :from],
          :to => [:from, :through, :using, :ready],
          :from => [:to, :through, :ready]
        }
        @transition_table.default = [:ready]
      end
        
      @transition_table[from].include?(to) ? true : false
    end
  end
end
