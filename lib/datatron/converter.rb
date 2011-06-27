module Datatron
  class Converter
    include Singleton
    
    def completed_conversions
      @completed_conversions ||= {} 
    end

    def requested_conversions
      @requested_conversions ||= {} 
    end

    def do_conversions options = {}
      while requested_conversions.size > 0
        conv_id = requested_conversions.keys.first
        table, file, strategy = requested_conversions[conv_id].values_at(:table, :file, :strategy)
        
        translator = load_strategy table, strategy, keys
        
        translate_action = lambda do
          loop do
            translator.new.translate!
          end
        end
        
        if to_model.class.respond_to? :transaction
          ActiveRecord::Base.transaction do
            translate_action.call
          end
        else
          translate_action.call
        end

        completed_conversions[conv_id] = requested_conversions[conv_id]
        requested_conversions.delete conv_id
      end
    end

    def load_strategy table, strategy, keys
      ar_model = table.singularize.camelize
      
      klass = "Datatron::#{ar_model}".constantize
      app = self
      
      Class.new do
        include ActiveRecordTranslator
        @strategy = klass.new strategy, keys 
        @ar_model = @strategy.class.ar_model
        #make life simpler - just pass these through to the converter instance
        define_method :requested_conversions do
          app.requested_conversions
        end

        define_method :completed_conversions do
          app.completed_conversions
        end
        
        class << self
          attr_accessor :strategy, :ar_model
        end
        
        define_method :initialize do |data_row|
          @strategy = self.class.strategy
          @data_row = data_row
          unless @strategy.finder 
            @ar_item = self.class.ar_model.new
          else
            @ar_item = self.class.ar_model.send *@strategy.finder
          end
        end
      end
    end
  end
end

