require 'thread'

module Datatron
  module Formats
    class TabDelimitedFile < Datatron::Format
      module TabFileMethods
        def save
          semaphore = Mutex.new
          semaphore.synchronize do
            File.open(self.class.fd,'a+') do |f|
              f.print values.join("\t")
              f << self.class.seperator
            end
          end
        end

        def initialize obj = nil
          __setobj__(obj || Hash[self.class.keys.zip([])])
        end
      end
    end
  end
end
        

module Datatron
  module Formats
    class TabDelimitedFile < Datatron::Format
      class << self
        def from filename, seperator = "\n"
          filename = "data/#{filename}.txt"
          raise DataSourceNotFound, "No such file or directory #{filename}" unless File.exists? filename

          class_name = filename.split(/\/|\./)[-2] #last elements without the extension
          data_class class_name do |c|
            c.send :include, TabFileMethods
            @seperator = seperator
            
            define_singleton_method :fd do
              @fd ||= File.open(filename)
            end

            c.data_source = @fd

            keys do
              return @keys if @keys
              fd.rewind if fd.lineno != 0
              @keys = fd.readline(self.seperator).chomp.split("\t",-1)
            end

            each do |y|
              fd.readlines(self.seperator).each do |l|
                vals = l.chomp.split("\t",-1)
                next if vals == keys
                obj = Hash[self.keys.zip(vals)]
                y.yield self.new obj
              end
            end

            class << c
              attr_accessor :seperator

              def rewind
                @data = nil
                fd.rewind
                true
              end
              
              def find all = :first, &block
                @data = nil
                fd.rewind
                memo = self.each.with_object [] do |row, memo|
                  if block.call(row)
                    all == :all ? memo.push(row) : (return row)
                  end
                end
                return memo.empty? ? nil : memo
              ensure
                rewind
              end
            end
          end
        end
      end
    end
  end
end

