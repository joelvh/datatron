require 'term_helper'

module Datatron
  class Converter
    include Singleton
    include TermHelper
    
    def completed_conversions
      @completed_conversions ||= [] 
    end

    def requested_conversions
      @requested_conversions ||= []
    end

    def << conv
      raise DatatronError, "Need Strategy subclass" unless conv.kind_of? Datatron::Strategy
      requested_conversions << conv
    end

    def >> 
      requested_conversions.pop
    end

    def build_cache
      super
     

      class << self 
        def progress_line percentage
          total_cols = size[:cols].to_i * 0.8
          cols = percentage.nan? ? 0 : (percentage * (total_cols - 16)).to_i

          output do |str|
            str << (percentage.nan? ? "  Unknown" : "%8d%%" % (percentage * 100))
            str << symbols do |str|
              str << color(:white) do |str| 
                str << "x"
              end
              str << color(:cyan) do |str|
                str << "a" * cols 
              end
              str << c.mrcup(0,total_cols - cols)
              str << color(:white) do |str|
                str << "x"
              end
            end
            str << c.column(1)
          end
        end

        def current_strategy strategy
          output do |str|
            str << color(:yellow) do |str|
              str << strategy.strategy.base_name 
            end
            str << " #{strategy.progress[:successful]} out of #{strategy.progress[:seen]}   "
            str << color(:red) do |str|
              str << "#{strategy.progress[:error_count]} Errors -- last error was #{strategy.progress[:last_error]}"
            end
            str << c.down
            str << "Source %"
            str << progress_line(strategy.progress[:source_percent])
            str << c.down
            str << "Dest   %"
            str << progress_line(strategy.progress[:dest_percent])
            str << c.up * 2 
          end
        end
      end

      @cached = true
    end

    def update translator
      build_cache unless @cached
      output STDOUT do |str|
        str << current_strategy(translator)
      end
    end

    def convert 
      while requested_conversions.size > 0
        translator = Translator.with_strategy(requested_conversions.shift)
        translator.add_observer(self)
        translator.rewind
        translator.translate :validate
        output(STDOUT) { |str| str << c.down * 2 }
      end
    end
  end

  def converter
    Datatron::Converter.instance
  end
  module_function :converter
end


