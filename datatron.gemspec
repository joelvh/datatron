# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "datatron/version"

Gem::Specification.new do |s|
  s.name        = "datatron"
  s.version     = Datatron::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stephen Prater", "A.G. Russell Knives"]
  s.email       = ["me@stephenprater.com","stephenp@agrussell.com"]
  s.homepage    = ""
  s.summary     = %q{Datatron is a data transformer and import tool.}
  s.description = %q{DAAATATRON!!!  You have data.  It's tab delimited (or CSV, or ActiveRecord, or Pipe Delimted, or JSON, or something really, really obscure. You want it in a different format.  Just write a Datatron Transformer, run the task and you're done. Comes with Rake tasks, to import your data, and a handly little DSL (because you can never have too many DSLs) for specifiying it. Autobots, roll out.}

  s.rubyforge_project = "datatron"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'activesupport', '~> 3.0.7'
  s.add_dependency 'order_tree'
  s.add_dependency 'anaphoric_case'

  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov"
end
