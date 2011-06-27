module Rake
  module TaskArgs
    def args
      ARGV.find { |l| l =~ /#{name}\[([^\]]+)/}
      $1
    end

    def arg_list
      args.split(/,/) if args
    end
  end

  class Task
    include TaskArgs
  end
end
