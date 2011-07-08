require 'ruby-debug'
require 'datatron'
require 'datatron/rake'

namespace :datatron do
  desc "convert (<table> OR <file>) <type> <strategy> = default_strategy -- Import a file using a particular strategy from the strategy file."
  task :import => :environment do |t|
    begin
      require "#{RAILS_ROOT}/data/transforms"
    rescue LoadError
      raise LoadError, "Transform file does not exist, try running the generator."
    end

    if t.arg_list
      args = t.arg_list.dup
    else
      raise ArgumentError, "Need arguments like [filename] or [table, file, strategy]"
    end

    if args == 1
      args.replace File.open(args[0]).each_line.collect { |l| l.split(/\s/) }
    end

    converter = Datatron::Converter.instance

    # what transforms do I know about?
    known_transforms = Datatron.transforms.each_with_object({}) { |t,memo| memo[t.base_name] = t }
    split_on_names = args.each_with_object [] do |b, memo|
      begin 
        if known_transforms.keys.include? b
          memo << [b.strip]
        else
          memo.last << b.strip
        end
      rescue StandardError => e
        raise ArgumentError, "Can't figure out what argument #{b} is supposed to be. Did you create a Transform Class?"
      end
    end

    converter.request_conversions << split_on_names.collect do |s|
      sh = Hash[[:table, :file, :strategy].zip(s)]
      {:file => nil, :strategy => :default_strategy}.merge(nh) { |k, nv, ov| ov ? ov : nv }
      known_transforms[sh[:table]].__send__(sh[:strategy], { :from => s[:file] })
    end

    converter.do_conversions
  end
end

