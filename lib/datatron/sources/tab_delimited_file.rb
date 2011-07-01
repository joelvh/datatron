module Datatron
  module Sources
    class TabDelimitedFile < Datatron::Source
      class << self
        def for_file filename, seperator = "\n"
          class_name = filename.split(/\/|\./)[-2] #last elements without the extension
          data_class class_name do |c|
            @seperator = seperator
            
            define_singleton_method :fd do
              @fd ||= File.open(filename)
            end

            keys do
              return @keys if @keys
              fd.rewind if fd.lineno != 0
              @keys = fd.readline(self.seperator).chomp.split("\t",-1)
            end

            next_row do |y|
              fd.readlines(self.seperator).each do |l|
                vals = l.chomp.split("\t",-1)
                next if vals == keys
                obj = Hash[self.keys.zip(vals)]
                y.yield HashWithIndifferentAccess.new obj
              end
            end

            class << c
              attr_accessor :seperator
              
             def find &block
                @data = nil
                fd.rewind
                found = loop do
                  data = self.next_row
                  break data if block.call(data)
                end
                found

              ensure
                @data = nil
                fd.rewind
              end
            end

            def initialize obj = nil
              __setobj__(obj || Hash[self.class.keys.zip([])])
            end
          end
        end
      end
    end
  end
end

