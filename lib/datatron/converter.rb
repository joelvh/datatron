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

    def shift conv
      raise DatatronError, "Need Strategy subclass" unless conv.kind_of? Datatron::Strategy
      requested_conversions.shift conv
    end

    def clear
      requested_conversions.clear
    end

    def >> 
      requested_conversions.pop
    end

    def build_cache
      super

      macro :clear_three do
        output do |str|
          3.times do
            str << c.clear_line
            c.down
          end
          c.up * 4 
        end
      end

      macro :progress_display do |strategy|
        output do |str|
          str << c.clear_three
          str << color(:yellow) do |str|
            str << strategy.strategy.name
            str << c.right * 2
          end
          str << strategy.progress[:successful] + ' out of ' +  strategy.progress[:seen]
          str << c.right * 2
          str << color(:red) do |str|
            str << strategy.progress[:error_count] + " Errors -- last error was " + strategy.progress[:last_error]
          end
          str << c.down
          str << color(:gray) { |str| str << "Source %" }
          str << self.progress_line(strategy.progress[:source_percent])
          str << c.down
          str << color(:gray) { |str| str << "Dest   %" }
          str << self.progress_line(strategy.progress[:dest_percent])
          str << c.up * 2 
        end
      end

      widget :progress_line do |percentage|
        total_cols = size[:cols].to_i * 0.8
        cols = percentage.nan? ? 0 : (percentage * (total_cols)).to_i

        output do |str|
          str << (percentage.nan? ? "  Unknown " : "%8d%% " % (percentage * 100))
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

      cache
    end

    def update translator
      if not @silent
        build_cache unless cache
        output STDOUT do |str|
          str << c.progress_display(translator)
        end
      elsif @logger and @logger.is_a? Logger
        if not translator.progress[:success]
          @logger.error("Translator Error #{last_error}")
        end
        if translator.progress[:source_percent] == 100
          @logger.info("Translated #{translator.progress[:successful]} of #{translator.progress[:seen]} records.")
        end
      end
    end

    def convert options = {}
      options.reverse_merge!( 
       {:silent => false,
        :logger => false })

      @silent = options[:silent]
      @logger = options[:logger]

      catch :stop_conversion do
        while requested_conversions.size > 0
          translator = Translator.with_strategy(requested_conversions.shift)
          translator.add_observer(self)
          translator.rewind
          translator.translate :validate
          output(STDOUT) { |str| str << c.down * 4 } unless @silent
        end
      end
    end
  end

  def converter
    Datatron::Converter.instance
  end
  module_function :converter
end


