require 'ruby-debug'
require 'datatron'

namespace :datatron do
  desc "convert (<table> OR <file>) <file(s)>... <strategy> = default_strategy -- Import a file using a particular strategy from the strategy file."
  task :import do |t|
    debugger
    1
    begin
      require "#{RAILS_ROOT}/data/transforms"
    rescue LoadError
      raise LoadError, "Transform file does not exist, try running the generator."
    end
    args = t.arg_list.dup 
    if args == 1
      conversion_list = File.open(args[0]).each_line do |l|
        bits << l.split(/\s/)
      end
    end

    converter = Datatron::Converter.instance

    # what transforms do I know about?
    known_transforms = Datatron.transforms.collect { |t| t.to_model.to_s.pluralize.underscore }
    split_on_names = bits.each_with_object [] do |b, memo|
      begin 
        if known_transforms.include? b
          memo << [b]
        else
          memo.last << b
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

