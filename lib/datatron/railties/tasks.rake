require 'ruby-debug'
require 'datatron'
require 'datatron/rake'

namespace :datatron do
  desc "convert (<table> OR <file>) <file(s)>... <strategy> = default_strategy -- Import a file using a particular strategy from the strategy file."
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
    known_transforms = Datatron.transforms.collect { |t| t.to_model.to_s.pluralize.underscore }
    split_on_names = args.each_with_object [] do |b, memo|
      begin 
        if known_transforms.include? b
          memo << [b.strip]
        else
          memo.last << b.strip
        end
      rescue StandardError => e
        raise ArgumentError, "Can't figure out what argument #{b} is supposed to be. Did you create a Transform Class?"
      end
    end

    conversions = split_on_names.collect do |s|
      nh = Hash[[:table, :file, :strategy].zip(s)]
      {:file => "data/#{s[0]}.txt", :strategy => :default_strategy}.merge(nh) { |k, nv, ov| ov ? ov : nv }
    end

    conversions.each do |c_spec|
      raise LoadError, "Missing data file #{c_spec[:file]}" unless File.exists? "#{RAILS_ROOT}/#{c_spec[:file]}"
      converter.requested_conversions[c_spec.hash] = c_spec
    end
    
    converter.do_conversions
    
  end
end

