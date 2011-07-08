require 'singleton'

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
          to_model.transaction do
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
      
      Class.new do
        include StrategyInterface 
        @strategy = klass.new strategy
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

  module StrategyInterface 
    attr_accessor :data_row, :strategy, :ar_item

    def translate
      #the basic principle here is that the Translator
      # asks the "Transform" what to do with each key?
      # where do I get the information for this attribute?
      # The transform ansers "get it from here"
      # Or "get it from the column of the samn name"
      # Or "get it from X but run it through this function
      # first
      # Or "Just tell the record item you'd like it populated."
      # or "Different step - ask for it to be done."
      debugger
      1
      ar_item.attribute_names.each do |k|
        source_key = strategy.transform k
        case source_key
          when String
            ar_item.attributes[k] = data_row[source_key]
          when Hash
            ar_item.attributes[k] = source_key.to_a 
          when TrueClass
            ar_item.attributes[k] = data_row[k]
          when FalseClass
            #do nothing
          when Proc
            ar_item.attributes[k] = source_key[data_row[k]]
          when UsingTranslationAction
            # do this one next, but wrap it in the same transaction
            # and 
            debugger
            1
        end
      end
    end

    def translate!
      translate
      if ar_item.valid?
        ar_item.save!
      else
        raise ActiveRecord::RecordInvalid, ar_item 
      end
    end

  end
end


