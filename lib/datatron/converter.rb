module Datatron
  class Converter
    include Singleton
    
    def completed_conversions
      @completed_conversions ||= Set.new 
    end

    def requested_conversions
      @requested_conversions ||= Set.new 
    end

    def << conv
      raise DatatronError, "Need Strategy subclass" unless conv.kind_of? Datatron::Strategy
      requested_conversions << conv
    end

    def >>
      requested_conversions.pop
    end

    def convert 
      while requested_conversions.size > 0
        translator = Translator.with_strategy requested_conversions.pop
        
        translate_action = lambda do
          loop do
            translator.new.translate!
          end
        end
        
        if translator.dest_item.respond_to? :transaction
          translator.dest_item.transaction do
            translate_action.call
          end
        else
          translate_action.call
        end
      end
    end
  end

  def converter
    Datatron::Converter.instance
  end
  module_function :converter
end


