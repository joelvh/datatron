module Datatron
  def transforms
    self.constants.each_with_object [] do |c, memo|
      klass = self.const_get c 
      memo << klass if klass.is_a? Class and klass < Datatron::Transform
    end
  end
  module_function :transforms
  
  class InvalidTransition < StandardError; end
  class TranslationFormatError < StandardError; end
  class TranslationKeyError < StandardError; end 
end
